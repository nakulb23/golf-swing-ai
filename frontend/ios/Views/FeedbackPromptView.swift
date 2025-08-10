import SwiftUI

// MARK: - Feedback Prompt View
struct FeedbackPromptView: View {
    let prediction: String
    let confidence: Double
    let onFeedbackSubmitted: (UserFeedback?) -> Void
    
    @State private var isCorrect: Bool? = nil
    @State private var correctedLabel = ""
    @State private var userConfidence = 3
    @State private var comments = ""
    @State private var showingDismiss = false
    
    private let swingTypes = ["Excellent", "Good", "Average", "Needs Work", "Poor"]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Help Improve AI")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your feedback helps make our swing analysis more accurate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)
            
            // Prediction Display
            VStack(spacing: 12) {
                HStack {
                    Text("AI Prediction:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(confidence * 100))% confident")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(confidenceColor.opacity(0.2))
                        )
                        .foregroundColor(confidenceColor)
                }
                
                Text(prediction)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
            }
            
            // Feedback Questions
            VStack(alignment: .leading, spacing: 16) {
                // Correctness
                VStack(alignment: .leading, spacing: 8) {
                    Text("Is this prediction correct?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        Button(action: { isCorrect = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: isCorrect == true ? "checkmark.circle.fill" : "circle")
                                Text("Yes")
                            }
                            .foregroundColor(isCorrect == true ? .green : .primary)
                        }
                        
                        Button(action: { isCorrect = false }) {
                            HStack(spacing: 8) {
                                Image(systemName: isCorrect == false ? "xmark.circle.fill" : "circle")
                                Text("No")
                            }
                            .foregroundColor(isCorrect == false ? .red : .primary)
                        }
                        
                        Spacer()
                    }
                }
                
                // Correction Input (if incorrect)
                if isCorrect == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What should it be?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Menu {
                            ForEach(swingTypes, id: \.self) { type in
                                Button(type) {
                                    correctedLabel = type
                                }
                            }
                        } label: {
                            HStack {
                                Text(correctedLabel.isEmpty ? "Select correct rating..." : correctedLabel)
                                    .foregroundColor(correctedLabel.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                
                // Confidence Rating
                VStack(alignment: .leading, spacing: 8) {
                    Text("How confident are you in your assessment?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { rating in
                            Button(action: { userConfidence = rating }) {
                                Image(systemName: rating <= userConfidence ? "star.fill" : "star")
                                    .foregroundColor(rating <= userConfidence ? .yellow : .gray)
                                    .font(.system(size: 24))
                            }
                        }
                        
                        Spacer()
                        
                        Text(confidenceDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Optional Comments
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional comments (optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Any specific observations about this swing?", text: $comments, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Skip") {
                    showingDismiss = true
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                
                Button("Submit Feedback") {
                    submitFeedback()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(canSubmit ? Color.blue : Color.gray)
                )
                .disabled(!canSubmit)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .alert("Skip Feedback?", isPresented: $showingDismiss) {
            Button("Skip", role: .destructive) {
                onFeedbackSubmitted(nil)
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("Your feedback helps improve the AI for everyone. Are you sure you want to skip?")
        }
    }
    
    // MARK: - Computed Properties
    
    private var confidenceColor: Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .orange }
        else { return .red }
    }
    
    private var confidenceDescription: String {
        switch userConfidence {
        case 1: return "Not sure"
        case 2: return "Somewhat confident"
        case 3: return "Moderately confident"  
        case 4: return "Very confident"
        case 5: return "Extremely confident"
        default: return ""
        }
    }
    
    private var canSubmit: Bool {
        guard let correct = isCorrect else { return false }
        
        if correct {
            return true
        } else {
            return !correctedLabel.isEmpty
        }
    }
    
    // MARK: - Methods
    
    private func submitFeedback() {
        guard let correct = isCorrect else { return }
        
        let feedback = UserFeedback(
            isCorrect: correct,
            correctedLabel: correct ? nil : correctedLabel,
            confidence: userConfidence,
            comments: comments.isEmpty ? nil : comments,
            submissionDate: Date()
        )
        
        onFeedbackSubmitted(feedback)
        
        // Analytics
        SimpleAnalytics.shared.trackEvent("feedback_submitted", properties: [
            "is_correct": correct,
            "user_confidence": userConfidence,
            "has_comments": !comments.isEmpty,
            "prediction_confidence": confidence
        ])
    }
}

// MARK: - Feedback Modal View
struct FeedbackModalView: View {
    let prediction: String
    let confidence: Double
    let onFeedbackSubmitted: (UserFeedback?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            FeedbackPromptView(
                prediction: prediction,
                confidence: confidence
            ) { feedback in
                onFeedbackSubmitted(feedback)
                dismiss()
            }
            .navigationTitle("AI Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onFeedbackSubmitted(nil)
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    FeedbackPromptView(
        prediction: "Good",
        confidence: 0.65
    ) { feedback in
        print("Feedback: \(String(describing: feedback))")
    }
    .padding()
}