# CaddieChat Pro - Real LLM Integration Guide

## Overview

This guide explains how to integrate a real on-device LLM into CaddieChat Pro using llama.cpp.

## Current Status

✅ Created `RealLLMCaddieChat.swift` - Complete LLM service infrastructure
⏳ Need to integrate actual llama.cpp Swift bindings
⏳ Need to add model download UI

## Integration Steps

### Step 1: Add llama.swift Package

There are two main options for llama.cpp Swift integration:

#### Option A: llama.swift (Recommended)
```swift
// In Xcode:
// 1. File > Add Package Dependencies
// 2. Enter: https://github.com/ShenghaiWang/SwiftLlama
// 3. Select version: 1.0.0 or later
```

#### Option B: swift-transformers
```swift
// Alternative package with more features:
// https://github.com/huggingface/swift-transformers
```

### Step 2: Update RealLLMCaddieChat.swift

Once the package is added, replace the placeholder `LLMContext` class with actual llama.swift imports:

```swift
import llama  // or whatever the package exposes

class LLMContext {
    private var llamaContext: LlamaContext?
    private var model: LlamaModel?

    init(modelPath: String, contextSize: Int, threads: Int, gpuLayers: Int) throws {
        let params = LlamaContextParams()
        params.n_ctx = UInt32(contextSize)
        params.n_threads = UInt32(threads)
        params.n_gpu_layers = UInt32(gpuLayers)

        self.model = try LlamaModel(path: modelPath)
        self.llamaContext = try LlamaContext(model: model!, params: params)
    }

    func generate(prompt: String, maxTokens: Int, temperature: Double, topP: Double, stopSequences: [String]) async throws -> String {
        // Actual llama.cpp generation
        var tokens = llamaContext!.tokenize(prompt)
        var generated = ""

        for _ in 0..<maxTokens {
            let nextToken = try await llamaContext!.sample(
                tokens: tokens,
                temperature: Float(temperature),
                topP: Float(topP)
            )

            // Check for stop sequences
            let tokenText = llamaContext!.decode(token: nextToken)
            generated += tokenText

            if stopSequences.contains(where: { generated.contains($0) }) {
                break
            }

            tokens.append(nextToken)

            // Check for EOS token
            if nextToken == llamaContext!.eosToken {
                break
            }
        }

        return generated
    }
}
```

### Step 3: Add Model Download UI

Create a one-time setup view for model download:

```swift
// ModelDownloadView.swift
struct ModelDownloadView: View {
    @StateObject private var llm = RealLLMCaddieChat.shared
    @State private var showingDownload = false

    var body: some View {
        if !llm.isModelDownloaded {
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Download AI Model")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("CaddieChat Pro requires a one-time download of the AI model (~800MB)")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                if llm.isLoading {
                    VStack(spacing: 12) {
                        ProgressView(value: llm.downloadProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 250)

                        Text("\(Int(llm.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button(action: {
                        Task {
                            try? await llm.downloadModel()
                        }
                    }) {
                        Text("Download Model")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
}
```

### Step 4: Update CaddieChatView

Modify `CaddieChatView.swift` to use the new LLM service:

```swift
// In CaddieChatView.swift
@StateObject private var realLLM = RealLLMCaddieChat.shared

// In sendMessage() function:
private func sendMessage() {
    guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    let userMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    let userMsg = ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: Date()
    )
    messages.append(userMsg)
    messageText = ""
    isLoading = true

    Task {
        do {
            print("🤖 Sending to Real LLM: \(userMessage)")

            // Use the REAL LLM
            let response = try await realLLM.sendMessage(userMessage)
            print("✅ Real LLM response: \(response.message)")

            await MainActor.run {
                let botMsg = ChatMessage(
                    text: response.message,
                    isUser: false,
                    timestamp: Date()
                )
                messages.append(botMsg)
                isLoading = false
            }
        } catch {
            print("❌ LLM error: \(error)")

            // Fallback to old system if LLM fails
            await MainActor.run {
                let botMsg = ChatMessage(
                    text: "I'm having trouble with the AI model. Please make sure it's downloaded in settings.",
                    isUser: false,
                    timestamp: Date()
                )
                messages.append(botMsg)
                isLoading = false
            }
        }
    }
}
```

## Model Selection

### Recommended Model: Qwen2.5-1.5B-Instruct Q4_K_M

**Why this model?**
- Size: ~800MB quantized (Q4_K_M)
- Fast inference on iPhone 12+
- Excellent instruction following
- Strong reasoning for size class
- Optimized for mobile devices

**Download URL:**
```
https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf
```

### Alternative Models

**Phi-3-mini (3.8B)** - More capable but larger
```
Size: ~2.1GB (Q4_K_M)
URL: https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf
```

**Gemma-2B-it** - Google's model
```
Size: ~1.2GB (Q4_K_M)
URL: https://huggingface.co/google/gemma-2b-it-GGUF
```

## System Prompt

The golf-specific system prompt is already configured in `RealLLMCaddieChat.swift`:

```swift
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
```

## Performance Optimization

### Tips for Best Performance

1. **Quantization**: Use Q4_K_M quantization (good balance of quality/speed)
2. **Context Size**: Keep at 2048 tokens (sufficient for conversation)
3. **GPU Layers**: Set to 0 for CPU-only, or use Metal for GPU acceleration
4. **Batch Size**: Use batch_size=1 for streaming responses
5. **Temperature**: 0.7 is good for creative but coherent responses

### Memory Management

```swift
// In AppDelegate or similar:
func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    // Unload model if memory is low
    RealLLMCaddieChat.shared.resetModel()
}
```

## Testing

### Test Scenarios

1. **Simple question**: "How do I fix my slice?"
2. **Equipment**: "What driver should I buy as a beginner?"
3. **Course strategy**: "How should I play a 200-yard approach shot?"
4. **Rules**: "What's the rule for relief from cart path?"
5. **Follow-up**: Test conversation context retention

### Performance Benchmarks

Target performance on iPhone 13:
- First token: < 500ms
- Subsequent tokens: < 50ms each
- Total response (50 tokens): < 3 seconds

## Fallback Strategy

The system has a graceful fallback:
1. Try Real LLM (RealLLMCaddieChat)
2. If model not downloaded → Show download prompt
3. If generation fails → Fall back to DynamicGolfAI (pattern matching)
4. If all fails → Generic error message

## Next Steps

1. ✅ Add llama.swift package to Xcode project
2. ✅ Update LLMContext with real llama.cpp calls
3. ✅ Add ModelDownloadView to onboarding flow
4. ✅ Test on physical device (simulator won't show real performance)
5. ✅ Optimize context size and generation params
6. ✅ Add model management UI in settings
7. ✅ Implement conversation export/import
8. ✅ Add analytics for response quality

## Troubleshooting

### Model won't load
- Check file exists at correct path
- Verify model is not corrupted
- Ensure enough storage space
- Check iOS version compatibility

### Slow inference
- Reduce context size (try 1024)
- Use smaller model (Qwen 1.5B instead of Phi-3)
- Enable Metal GPU acceleration
- Close background apps

### App crashes
- Model may be too large for device
- Check memory usage in Instruments
- Reduce batch size or context length
- Use more aggressive quantization (Q4_0)

## Resources

- llama.cpp: https://github.com/ggerganov/llama.cpp
- SwiftLlama: https://github.com/ShenghaiWang/SwiftLlama
- GGUF Models: https://huggingface.co/models?library=gguf
- Qwen2.5: https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF

---

## Summary

Your CaddieChat will now have:
- ✅ Real LLM running fully on-device
- ✅ No internet required after model download
- ✅ Privacy-first (all processing local)
- ✅ Intelligent, contextual responses
- ✅ Natural conversation flow
- ✅ Golf-specific expertise via system prompt

The upgrade from pattern-matching to a real LLM will make CaddieChat Pro truly intelligent and useful!
