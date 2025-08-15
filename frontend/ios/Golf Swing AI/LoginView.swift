import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var credentials = LoginCredentials()
    @State private var showingRegistration = false
    @State private var showingForgotPassword = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        Spacer(minLength: 60)
                        
                        // Logo and Title
                        VStack(spacing: 16) {
                            Image(systemName: "sportscourt.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.green)
                            
                            Text("Golf Swing AI")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Analyze. Improve. Perfect.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Login Form
                        VStack(spacing: 20) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter your email", text: $credentials.email)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                SecureField("Enter your password", text: $credentials.password)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            // Error Message
                            if let errorMessage = authManager.errorMessage {
                                Text(errorMessage)
                                    .font(.body)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Sign In Button
                            Button(action: signIn) {
                                HStack {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Sign In")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .foregroundColor(.white)
                            .disabled(authManager.isLoading || !isValidInput)
                            
                            // Forgot Password
                            Button("Forgot Password?") {
                                showingForgotPassword = true
                            }
                            .foregroundColor(.blue)
                            .font(.subheadline)
                            
                            // Divider
                            HStack {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.secondary.opacity(0.3))
                                
                                Text("or")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.secondary.opacity(0.3))
                            }
                            .padding(.vertical, 20)
                            
                            // Social Login Buttons
                            VStack(spacing: 12) {
                                // Apple ID Sign In
                                Button(action: signInWithApple) {
                                    HStack {
                                        Image(systemName: "applelogo")
                                            .font(.system(size: 18, weight: .medium))
                                        Text("Continue with Apple")
                                            .font(.headline)
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.black)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                
                                // Google Sign In
                                Button(action: signInWithGoogle) {
                                    HStack {
                                        Image("google")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                        Text("Continue with Google")
                                            .font(.headline)
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer(minLength: 40)
                        
                        // Sign Up Section
                        VStack(spacing: 16) {
                            Text("Don't have an account?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Create Account") {
                                showingRegistration = true
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $showingRegistration) {
            RegistrationView()
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
    
    // MARK: - Actions
    private func signIn() {
        Task {
            await authManager.signIn(email: credentials.email, password: credentials.password)
            await MainActor.run {
                if authManager.isAuthenticated {
                    dismiss()
                }
            }
        }
    }
    
    private func signInWithApple() {
        authManager.signInWithApple()
        // Dismiss will be handled automatically when isAuthenticated changes
    }
    
    private func signInWithGoogle() {
        Task {
            await authManager.signInWithGoogle()
        }
    }
    
    // MARK: - Computed Properties
    private var isValidInput: Bool {
        !credentials.email.isEmpty && !credentials.password.isEmpty
    }
}

// MARK: - Registration View
struct RegistrationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var registrationData = RegistrationData()
    @State private var currentStep = 1
    private let totalSteps = 3
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress Indicator
                    ProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    ScrollView {
                        VStack(spacing: 30) {
                            // Step Content
                            Group {
                                switch currentStep {
                                case 1:
                                    AccountDetailsStep(registrationData: $registrationData)
                                case 2:
                                    PersonalInfoStep(registrationData: $registrationData)
                                case 3:
                                    GolfProfileStep(registrationData: $registrationData)
                                default:
                                    EmptyView()
                                }
                            }
                            .padding(.horizontal, 30)
                            .padding(.top, 40)
                            
                            // Error Message
                            if let errorMessage = authManager.errorMessage {
                                Text(errorMessage)
                                    .font(.body)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Spacer(minLength: 40)
                        }
                    }
                    
                    // Navigation Buttons
                    VStack(spacing: 16) {
                        if currentStep < totalSteps {
                            Button("Continue") {
                                withAnimation {
                                    currentStep += 1
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canProceed)
                        } else {
                            Button(action: signUp) {
                                HStack {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Create Account")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(authManager.isLoading || !canCreateAccount)
                            
                            // Social Registration Options
                            VStack(spacing: 12) {
                                HStack {
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(.secondary.opacity(0.3))
                                    
                                    Text("or sign up with")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                    
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(.secondary.opacity(0.3))
                                }
                                .padding(.vertical, 16)
                                
                                HStack(spacing: 20) {
                                    Button(action: { 
                                        authManager.signInWithApple()
                                    }) {
                                        Image(systemName: "applelogo")
                                            .font(.system(size: 20, weight: .medium))
                                            .frame(width: 50, height: 50)
                                            .background(Color.black)
                                            .foregroundColor(.white)
                                            .cornerRadius(25)
                                    }
                                    
                                    Button(action: { 
                                        Task { await authManager.signInWithGoogle() }
                                    }) {
                                        Image("google")
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                            .frame(width: 50, height: 50)
                                            .background(Color.white)
                                            .cornerRadius(25)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    
                                }
                            }
                        }
                        
                        if currentStep > 1 {
                            Button("Back") {
                                withAnimation {
                                    currentStep -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            })
        }
    }
    
    // MARK: - Actions
    private func signUp() {
        Task {
            await authManager.signUp(registrationData: registrationData)
            await MainActor.run {
                if authManager.isAuthenticated {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return !registrationData.email.isEmpty && 
                   !registrationData.password.isEmpty && 
                   !registrationData.confirmPassword.isEmpty
        case 2:
            return !registrationData.firstName.isEmpty && 
                   !registrationData.lastName.isEmpty
        case 3:
            return registrationData.agreedToTerms
        default:
            return false
        }
    }
    
    private var canCreateAccount: Bool {
        return !registrationData.email.isEmpty &&
               !registrationData.password.isEmpty &&
               !registrationData.firstName.isEmpty &&
               !registrationData.lastName.isEmpty &&
               registrationData.agreedToTerms
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var emailSent = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Reset Password")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                if !emailSent {
                    VStack(spacing: 20) {
                        TextField("Email address", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        Button(action: sendResetEmail) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Send Reset Link")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(authManager.isLoading || email.isEmpty)
                    }
                    .padding(.horizontal, 30)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.success)
                        
                        Text("Email Sent!")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Check your email for instructions on how to reset your password.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 30)
                }
                
                Spacer()
            }
            .padding(.top, 40)
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            })
        }
    }
    
    private func sendResetEmail() {
        Task {
            await authManager.resetPassword(email: email)
            await MainActor.run {
                if authManager.errorMessage == nil {
                    emailSent = true
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
        .environmentObject(ThemeManager())
}