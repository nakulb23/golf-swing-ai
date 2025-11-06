import Foundation
import Combine
import llama  // Note: Add "llama" product from llama.cpp package to target dependencies

// MARK: - Real On-Device LLM for CaddieChat
// Uses llama.cpp via swift-llm library for truly intelligent golf conversations

@MainActor
class RealLLMCaddieChat: ObservableObject {
    static let shared = RealLLMCaddieChat()

    @Published var isLoading = false
    @Published var isModelDownloaded = false
    @Published var downloadProgress: Double = 0.0
    @Published var modelLoadError: String?

    private var llmContext: LLMContext?
    private var conversationHistory: [Message] = []
    private let maxHistoryLength = 10

    // Model configuration
    private let modelName = "qwen2.5-1.5b-instruct-q4_k_m.gguf"
    private let modelURL = "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"

    private var modelPath: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("models").appendingPathComponent(modelName)
    }

    // Golf-specific system prompt
    private let systemPrompt = """
    You are CaddieChat Pro, an expert golf caddie and instructor with deep knowledge of:
    - Golf swing mechanics and technique
    - Course management and strategy
    - Equipment selection and fitting
    - Golf rules (USGA/R&A)
    - Practice drills and training methods
    - Mental game and course psychology
    - Troubleshooting common issues (slice, hook, topped shots, etc.)

    Your communication style:
    - Friendly, encouraging, and professional
    - Provide specific, actionable advice
    - Use golf terminology appropriately
    - Ask clarifying questions when needed
    - Adapt explanations to the golfer's skill level
    - Keep responses concise but comprehensive (2-4 sentences preferred)
    - Use bullet points for multi-step advice

    Always prioritize safety, etiquette, and proper fundamentals.
    """

    private init() {
        print("🤖 Real LLM CaddieChat initialized")
        checkModelAvailability()
    }

    // MARK: - Model Management

    func checkModelAvailability() {
        let modelsDirectory = modelPath.deletingLastPathComponent()

        // Create models directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: modelsDirectory.path) {
            try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        }

        isModelDownloaded = FileManager.default.fileExists(atPath: modelPath.path)
        print(isModelDownloaded ? "✅ Model found at \(modelPath.path)" : "⚠️ Model not downloaded")
    }

    func downloadModel() async throws {
        print("📥 Starting model download...")
        guard let url = URL(string: modelURL) else {
            throw LLMError.invalidURL
        }

        isLoading = true
        downloadProgress = 0.0

        let (tempURL, response) = try await URLSession.shared.download(from: url) { progress, totalSize in
            DispatchQueue.main.async {
                self.downloadProgress = Double(progress) / Double(totalSize)
            }
        }

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw LLMError.downloadFailed
        }

        // Move to final location
        let modelsDirectory = modelPath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: modelPath.path) {
            try? FileManager.default.removeItem(at: modelPath)
        }

        try FileManager.default.moveItem(at: tempURL, to: modelPath)

        isModelDownloaded = true
        isLoading = false
        downloadProgress = 1.0

        print("✅ Model downloaded successfully")

        // Load the model
        try await loadModel()
    }

    func loadModel() async throws {
        guard isModelDownloaded else {
            throw LLMError.modelNotDownloaded
        }

        print("🔄 Loading LLM model...")
        isLoading = true

        do {
            // Initialize llama.cpp context with the model
            llmContext = try LLMContext(
                modelPath: modelPath.path,
                contextSize: 2048,
                threads: 4,
                gpuLayers: 0 // Use Metal GPU acceleration if available
            )

            print("✅ Model loaded successfully")
        } catch {
            print("❌ Failed to load model: \(error)")
            modelLoadError = "Failed to load model: \(error.localizedDescription)"
            throw LLMError.modelLoadFailed(error)
        }

        isLoading = false
    }

    // MARK: - Chat Interface

    func sendMessage(_ userMessage: String) async throws -> ChatResponse {
        guard let context = llmContext else {
            print("⚠️ Model not loaded, attempting to load...")
            try await loadModel()
            // Recursively call sendMessage after loading model
            return try await sendMessage(userMessage)
        }

        // Add user message to history
        conversationHistory.append(Message(role: .user, content: userMessage))

        // Trim history if too long
        if conversationHistory.count > maxHistoryLength {
            conversationHistory = Array(conversationHistory.suffix(maxHistoryLength))
        }

        // Build prompt with system message and conversation history
        let fullPrompt = buildPrompt()

        print("🤖 Generating response for: \(userMessage)")
        isLoading = true

        do {
            // Generate response using llama.cpp
            let response = try await context.generate(
                prompt: fullPrompt,
                maxTokens: 256,
                temperature: 0.7,
                topP: 0.9,
                stopSequences: ["User:", "\n\nUser:", "Human:"]
            )

            let cleanedResponse = cleanResponse(response)

            // Add assistant response to history
            conversationHistory.append(Message(role: .assistant, content: cleanedResponse))

            print("✅ Generated response: \(cleanedResponse.prefix(100))...")

            isLoading = false

            return ChatResponse(
                id: UUID().uuidString,
                message: cleanedResponse,
                isUser: false,
                timestamp: Date(),
                intent: "llm_response",
                confidence: 0.95
            )

        } catch {
            print("❌ Generation error: \(error)")
            isLoading = false
            throw LLMError.generationFailed(error)
        }
    }

    func streamMessage(_ userMessage: String, onToken: @escaping @Sendable (String) -> Void) async throws -> String {
        guard let context = llmContext else {
            throw LLMError.modelNotLoaded
        }

        conversationHistory.append(Message(role: .user, content: userMessage))

        if conversationHistory.count > maxHistoryLength {
            conversationHistory = Array(conversationHistory.suffix(maxHistoryLength))
        }

        let fullPrompt = buildPrompt()

        // Get the full response from streaming generation
        let fullResponse = try await context.generateStreaming(
            prompt: fullPrompt,
            maxTokens: 256,
            temperature: 0.7,
            topP: 0.9,
            stopSequences: ["User:", "\n\nUser:", "Human:"],
            onToken: onToken
        )

        conversationHistory.append(Message(role: .assistant, content: fullResponse))

        return fullResponse
    }

    // MARK: - Prompt Building

    private func buildPrompt() -> String {
        var prompt = systemPrompt + "\n\n"

        // Add conversation history
        for message in conversationHistory {
            switch message.role {
            case .system:
                prompt += "System: \(message.content)\n\n"
            case .user:
                prompt += "User: \(message.content)\n\n"
            case .assistant:
                prompt += "Assistant: \(message.content)\n\n"
            }
        }

        prompt += "Assistant:"

        return prompt
    }

    private func cleanResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove any leftover "Assistant:" prefix
        if cleaned.hasPrefix("Assistant:") {
            cleaned = String(cleaned.dropFirst("Assistant:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Remove stop sequences
        let stopSequences = ["User:", "\n\nUser:", "Human:", "\n\nHuman:"]
        for stop in stopSequences {
            if let range = cleaned.range(of: stop) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func clearConversation() {
        conversationHistory.removeAll()
        print("🗑️ Conversation history cleared")
    }

    func resetModel() {
        llmContext = nil
        conversationHistory.removeAll()
        print("🔄 Model reset")
    }
}

// MARK: - Supporting Types

struct Message: Sendable {
    enum Role: Sendable {
        case system, user, assistant
    }

    let role: Role
    let content: String
}

enum LLMError: LocalizedError {
    case modelNotDownloaded
    case modelNotLoaded
    case modelLoadFailed(Error)
    case generationFailed(Error)
    case invalidURL
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Model not downloaded. Please download the model first."
        case .modelNotLoaded:
            return "Model not loaded. Please load the model first."
        case .modelLoadFailed(let error):
            return "Failed to load model: \(error.localizedDescription)"
        case .generationFailed(let error):
            return "Failed to generate response: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid model download URL"
        case .downloadFailed:
            return "Failed to download model"
        }
    }
}

// MARK: - Real LLM Context using llama.cpp

class LLMContext {
    let modelPath: String
    let contextSize: Int
    let threads: Int
    let gpuLayers: Int

    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private let maxTokens = 2048

    init(modelPath: String, contextSize: Int, threads: Int, gpuLayers: Int) throws {
        self.modelPath = modelPath
        self.contextSize = contextSize
        self.threads = threads
        self.gpuLayers = gpuLayers

        print("🔧 Initializing llama.cpp context...")

        // Initialize llama backend
        llama_backend_init()

        // Set up model parameters
        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = UInt32(clamping: gpuLayers)

        // Load the model
        guard let loadedModel = llama_load_model_from_file(modelPath, modelParams) else {
            throw LLMError.modelLoadFailed(NSError(domain: "LLMContext", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load model from \(modelPath)"]))
        }
        self.model = loadedModel

        // Set up context parameters
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(clamping: contextSize)
        ctxParams.n_threads = Int32(threads)
        ctxParams.n_threads_batch = Int32(threads)

        // Create context
        guard let ctx = llama_new_context_with_model(loadedModel, ctxParams) else {
            llama_free_model(loadedModel)
            throw LLMError.modelLoadFailed(NSError(domain: "LLMContext", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create context"]))
        }
        self.context = ctx

        print("✅ llama.cpp context initialized successfully")
    }

    deinit {
        if let ctx = context {
            llama_free(ctx)
        }
        if let mdl = model {
            llama_free_model(mdl)
        }
        llama_backend_free()
    }

    func generate(prompt: String, maxTokens: Int, temperature: Double, topP: Double, stopSequences: [String]) async throws -> String {
        guard let model = model, let context = context else {
            throw LLMError.modelNotLoaded
        }

        print("🤖 Generating response with llama.cpp...")

        // Tokenize the prompt
        let tokens = tokenize(text: prompt, addBos: true)
        guard !tokens.isEmpty else {
            throw LLMError.generationFailed(NSError(domain: "LLMContext", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to tokenize prompt"]))
        }

        print("📝 Tokenized prompt: \(tokens.count) tokens")

        // Create batch for processing
        var batch = llama_batch_init(Int32(tokens.count), Int32(0), Int32(1))
        defer { llama_batch_free(batch) }

        // Add tokens to batch
        for (i, token) in tokens.enumerated() {
            let lastToken = (i == tokens.count - 1)
            llama_batch_add(&batch, token, Int32(i), [Int32(0)], lastToken)
        }

        // Process the prompt
        if llama_decode(context, batch) != 0 {
            throw LLMError.generationFailed(NSError(domain: "LLMContext", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to decode prompt"]))
        }

        // Generate tokens
        var generatedTokens: [llama_token] = []
        var generatedText = ""

        for _ in 0..<maxTokens {
            // Sample next token
            let nextToken = sampleToken(temperature: Float(temperature), topP: Float(topP))

            // Check for EOS
            if llama_token_is_eog(model, nextToken) {
                break
            }

            generatedTokens.append(nextToken)

            // Convert token to text
            let piece = detokenize(tokens: [nextToken])
            generatedText += piece

            // Check stop sequences
            var shouldStop = false
            for stopSeq in stopSequences {
                if generatedText.contains(stopSeq) {
                    shouldStop = true
                    break
                }
            }
            if shouldStop { break }

            // Prepare next batch with single token
            llama_batch_clear(&batch)
            llama_batch_add(&batch, nextToken, Int32(tokens.count + generatedTokens.count - 1), [Int32(0)], true)

            // Decode next token
            if llama_decode(context, batch) != 0 {
                print("⚠️ Failed to decode token \(generatedTokens.count)")
                break
            }

            // Allow cooperative cancellation
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        print("✅ Generated \(generatedTokens.count) tokens")
        return generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenize(text: String, addBos: Bool) -> [llama_token] {
        guard let model = model else { return [] }

        let utf8Count = text.utf8.count
        var tokens = [llama_token](repeating: 0, count: utf8Count + (addBos ? 1 : 0) + 1)

        let tokenCount = text.withCString { cString in
            llama_tokenize(model, cString, UInt32(clamping: utf8Count), &tokens, UInt32(clamping: tokens.count), addBos, false)
        }

        guard tokenCount >= 0 else { return [] }
        return Array(tokens.prefix(Int(tokenCount)))
    }

    private func detokenize(tokens: [llama_token]) -> String {
        guard let model = model else { return "" }

        var result = ""
        for token in tokens {
            let bufferSize = 32
            var buffer = [CChar](repeating: 0, count: bufferSize)
            let length = llama_token_to_piece(model, token, &buffer, Int32(bufferSize), false)

            if length > 0 {
                result += String(cString: buffer)
            }
        }
        return result
    }

    private func sampleToken(temperature: Float, topP: Float) -> llama_token {
        guard let context = context, let model = model else {
            return 0
        }

        let logits = llama_get_logits_ith(context, -1)
        let nVocab = llama_n_vocab(model)

        // Create candidates array
        var candidates = Array(repeating: llama_token_data(id: 0, logit: 0.0, p: 0.0), count: Int(nVocab))
        for tokenId in 0..<nVocab {
            candidates[Int(tokenId)] = llama_token_data(
                id: tokenId,
                logit: logits![Int(tokenId)],
                p: 0.0
            )
        }

        var candidatesP = llama_token_data_array(
            data: &candidates,
            size: candidates.count,
            sorted: false
        )

        // Apply top-p sampling
        llama_sample_top_p(context, &candidatesP, topP, 1)

        // Apply temperature
        llama_sample_temp(context, &candidatesP, temperature)

        // Sample token
        return llama_sample_token(context, &candidatesP)
    }

    // Fallback to hardcoded responses if LLM fails
    private func fallbackResponse(for userQuestion: String) -> String {
        let question = userQuestion.lowercased()

        // Golf Rules
        if userQuestion.contains("cart path") {
            return """
            When your ball lands on a cart path, you get free relief under Rule 16.1 (Abnormal Course Conditions):

            • Identify your nearest point of complete relief (where the cart path doesn't interfere with your stance or swing)
            • Drop within one club-length of that point, no closer to the hole
            • Must be in the same area of the course (fairway, rough, etc.)
            • No penalty strokes

            If the cart path doesn't interfere with your swing or stance, you can play it as it lies. Remember to protect your clubs when hitting off hard surfaces!
            """
        }

        // Slice fixes
        if userQuestion.contains("slice") || userQuestion.contains("slicing") {
            return """
            A slice is usually caused by an open clubface at impact combined with an outside-in swing path. Here's how to fix it:

            • Strengthen your grip (see 2-3 knuckles on your left hand)
            • Check your setup: align shoulders parallel to target line
            • Feel like you're swinging toward right field (for right-handers)
            • Focus on rotating your forearms through impact
            • Practice with alignment sticks to groove an inside-out path

            Try the "gate drill": Place two alignment sticks creating a gate just past the ball. This encourages the proper inside-out path.
            """
        }

        // Hook fixes
        if userQuestion.contains("hook") || userQuestion.contains("hooking") {
            return """
            A hook typically comes from a closed clubface with an inside-out path. To fix it:

            • Weaken your grip slightly (show fewer knuckles)
            • Check your ball position isn't too far back
            • Feel like you're holding the clubface open through impact
            • Ensure your shoulders aren't closed at address
            • Work on delaying the release of your hands

            Practice hitting intentional fades on the range to develop the feel for keeping the face slightly open.
            """
        }

        // Distance/swing speed
        if userQuestion.contains("distance") || userQuestion.contains("swing speed") || userQuestion.contains("hit it farther") {
            return """
            To increase distance, focus on these key factors:

            • Improve your rotation: Full shoulder turn (90°) with stable lower body
            • Optimize launch angle: 12-15° for driver with positive attack angle
            • Increase flexibility through regular stretching
            • Work on sequencing: hips → torso → arms → club
            • Use ground force: push through legs on downswing

            Remember: Accuracy is more valuable than raw distance. Gaining 10-15 yards with control beats 30 yards into the trees!
            """
        }

        // Wedge lofts and specifications
        if userQuestion.contains("wedge") && (userQuestion.contains("loft") || userQuestion.contains("standard") || userQuestion.contains("degree")) {
            return """
            Standard wedge lofts:

            • Pitching Wedge (PW): 44-48°
            • Gap Wedge (GW/AW): 50-52°
            • Sand Wedge (SW): 54-56°
            • Lob Wedge (LW): 58-60°

            Most golfers carry 3-4 wedges with 4-6° gaps between them. For example: PW (46°), GW (50°), SW (54°), LW (58°). The right setup depends on your iron lofts and distance gaps.

            Pro tip: Focus on bounce angle too! Higher bounce (10-14°) for soft conditions, lower bounce (4-8°) for firm turf.
            """
        }

        // Iron distances and specifications
        if (userQuestion.contains("iron") || userQuestion.contains("club")) && (userQuestion.contains("distance") || userQuestion.contains("far") || userQuestion.contains("yardage")) {
            return """
            Average iron distances (for recreational golfers):

            • 9-iron: 120-140 yards
            • 8-iron: 130-150 yards
            • 7-iron: 140-160 yards
            • 6-iron: 150-170 yards
            • 5-iron: 160-180 yards

            Remember: Your distances may vary based on swing speed, conditions, and equipment. What matters most is knowing YOUR consistent distances for each club. Spend time on the range finding your reliable yardages!
            """
        }

        // Driver specifications
        if userQuestion.contains("driver") && (userQuestion.contains("loft") || userQuestion.contains("shaft") || userQuestion.contains("spec")) {
            return """
            Driver specifications guide:

            Loft selection:
            • Slower swing (<85 mph): 12-14° loft
            • Average swing (85-95 mph): 10.5-12° loft
            • Fast swing (>95 mph): 8.5-10.5° loft

            Shaft flex:
            • Senior (S): <75 mph swing speed
            • Regular (R): 75-90 mph
            • Stiff (S): 90-105 mph
            • Extra Stiff (X): >105 mph

            Higher loft = easier launch, more forgiveness. Get fitted to optimize your launch conditions!
            """
        }

        // Equipment recommendations (general)
        if userQuestion.contains("equipment") || userQuestion.contains("clubs") || userQuestion.contains("buying") || userQuestion.contains("beginner clubs") {
            return """
            Equipment can significantly impact your game:

            Beginners should focus on:
            • Game improvement irons (cavity back, wide sole)
            • Higher-lofted driver (10.5° or more) for forgiveness
            • Hybrids instead of long irons (easier to hit)
            • Properly fitted clubs (grip size, lie angle, shaft flex)

            Before buying new clubs, get fitted! Even basic fitting ensures clubs match your swing. Start with a good set of game improvement irons and a forgiving driver.
            """
        }

        // Putting
        if userQuestion.contains("putt") || userQuestion.contains("putting") {
            return """
            Great putting comes from solid fundamentals:

            • Grip pressure: Light enough to feel the putter head (3-4 out of 10)
            • Eyes over the ball or just inside the line
            • Shoulders drive the stroke, not hands/wrists
            • Accelerate through impact (no deceleration)
            • Read grain and slope carefully

            Practice distance control with the "ladder drill": putt to targets at 10, 20, 30 feet. Speed control is more important than line for reducing 3-putts!
            """
        }

        // Course management/strategy
        if userQuestion.contains("strategy") || userQuestion.contains("course management") {
            return """
            Smart course management saves strokes:

            • Play to your strengths: know your reliable distances
            • Aim for the fat part of the green, not the pin
            • Take one more club than you think on approaches
            • Avoid compounding mistakes (don't try hero shots after a bad tee shot)
            • Know when to play safe vs. when to attack

            The best strategy: minimize big numbers. A safe bogey beats a potential double or triple!
            """
        }

        // Chipping
        if userQuestion.contains("chip") || userQuestion.contains("chipping") || userQuestion.contains("short game") {
            return """
            Solid chipping technique:

            • Narrow stance, weight forward (60-70% on lead foot)
            • Hands ahead of ball at address and impact
            • Use putting grip for more control
            • Let the club's loft do the work
            • Practice the bump-and-run: use less lofted clubs for more roll

            Rule of thumb: Get the ball on the green and rolling as soon as possible. Less air time = more predictability!
            """
        }

        // Mental game
        if userQuestion.contains("mental") || userQuestion.contains("nerves") || userQuestion.contains("pressure") {
            return """
            The mental game is crucial:

            • Develop a consistent pre-shot routine
            • Focus on process, not outcome
            • Use visualization: see the shot before hitting
            • Take deep breaths to manage pressure
            • Accept that bad shots happen to everyone

            Play one shot at a time. After a bad hole, reset mentally. Remember: even pros miss fairways and greens!
            """
        }

        // Practice tips
        if userQuestion.contains("practice") || userQuestion.contains("drill") || userQuestion.contains("improve") {
            return """
            Effective practice strategies:

            • Quality over quantity: focused 30 minutes beats mindless hours
            • Work on weaknesses, not just what feels good
            • Practice with purpose: each shot has a target
            • Track stats to identify real problem areas
            • Spend 60% of practice time on short game

            Try the "9-ball drill" around the green: chip 3 balls from 3 different lies. Goal is to get 6+ within 3 feet. This builds real scoring skills!
            """
        }

        // Generic golf question
        if userQuestion.contains("golf") || userQuestion.contains("swing") || userQuestion.contains("shot") {
            return """
            I'm here to help with your golf game! I can provide advice on:

            • Swing mechanics and technique
            • Equipment selection and fitting
            • Course strategy and management
            • Short game and putting
            • Practice drills
            • Rules and etiquette
            • Fixing common issues (slice, hook, topped shots, etc.)

            What specific aspect of your game would you like to work on?
            """
        }

        // Fallback for non-golf questions
        return """
        I'm CaddieChat Pro, specialized in golf advice! I can help you with:

        • Swing technique and mechanics
        • Golf rules and scenarios
        • Equipment recommendations
        • Course strategy
        • Practice drills
        • Fixing common issues (slice, hook, distance, etc.)

        What golf-related question can I help you with today?
        """
    }

    func generateStreaming(prompt: String, maxTokens: Int, temperature: Double, topP: Double, stopSequences: [String], onToken: @escaping @Sendable (String) -> Void) async throws -> String {
        guard let model = model, let context = context else {
            throw LLMError.modelNotLoaded
        }

        print("🤖 Streaming generation with llama.cpp...")

        // Tokenize the prompt
        let tokens = tokenize(text: prompt, addBos: true)
        guard !tokens.isEmpty else {
            throw LLMError.generationFailed(NSError(domain: "LLMContext", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to tokenize prompt"]))
        }

        // Create and process batch
        var batch = llama_batch_init(Int32(tokens.count), Int32(0), Int32(1))
        defer { llama_batch_free(batch) }

        for (i, token) in tokens.enumerated() {
            let lastToken = (i == tokens.count - 1)
            llama_batch_add(&batch, token, Int32(i), [Int32(0)], lastToken)
        }

        if llama_decode(context, batch) != 0 {
            throw LLMError.generationFailed(NSError(domain: "LLMContext", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to decode prompt"]))
        }

        // Generate and stream tokens
        var generatedTokens: [llama_token] = []
        var generatedText = ""

        for _ in 0..<maxTokens {
            let nextToken = sampleToken(temperature: Float(temperature), topP: Float(topP))

            if llama_token_is_eog(model, nextToken) {
                break
            }

            generatedTokens.append(nextToken)

            // Stream the token piece immediately
            let piece = detokenize(tokens: [nextToken])
            generatedText += piece
            onToken(piece)

            // Check stop sequences
            var shouldStop = false
            for stopSeq in stopSequences {
                if generatedText.contains(stopSeq) {
                    shouldStop = true
                    break
                }
            }
            if shouldStop { break }

            // Prepare next batch
            llama_batch_clear(&batch)
            llama_batch_add(&batch, nextToken, Int32(tokens.count + generatedTokens.count - 1), [Int32(0)], true)

            if llama_decode(context, batch) != 0 {
                break
            }

            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        return generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - URLSession Download Extension

extension URLSession {
    func download(from url: URL, progressHandler: @escaping @Sendable (Int64, Int64) -> Void) async throws -> (URL, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = self.downloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let tempURL = tempURL, let response = response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }

                continuation.resume(returning: (tempURL, response))
            }

            // Observe download progress
            _ = task.progress.observe(\.fractionCompleted) { progress, _ in
                let bytesReceived = Int64(progress.fractionCompleted * Double(progress.totalUnitCount))
                progressHandler(bytesReceived, progress.totalUnitCount)
            }

            task.resume()
        }
    }
}
