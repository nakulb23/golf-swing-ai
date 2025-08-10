import SwiftUI

// MARK: - Progress Indicator
struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.accentDynamic : Color.secondaryTextDynamic.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .scaleEffect(step == currentStep ? 1.2 : 1.0)
                    .animation(Animation.easeInOut, value: currentStep)
            }
        }
    }
}

// MARK: - Account Details Step (Step 1)
struct AccountDetailsStep: View {
    @Binding var registrationData: RegistrationData
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Account Details")
                    .golfTitle()
                    .foregroundColor(.primaryTextDynamic)
                
                Text("Create your Golf Swing AI account")
                    .font(.subheadline)
                    .foregroundColor(.secondaryTextDynamic)
            }
            
            VStack(spacing: 20) {
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .golfCaption()
                        .foregroundColor(.secondaryTextDynamic)
                    
                    TextField("Enter your email", text: $registrationData.email)
                        .textFieldStyle(GolfTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // Username Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .golfCaption()
                        .foregroundColor(.secondaryTextDynamic)
                    
                    TextField("Choose a username", text: $registrationData.username)
                        .textFieldStyle(GolfTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .golfCaption()
                        .foregroundColor(.secondaryTextDynamic)
                    
                    SecureField("Create a password", text: $registrationData.password)
                        .textFieldStyle(GolfTextFieldStyle())
                    
                    Text("Must be at least 8 characters")
                        .font(.caption)
                        .foregroundColor(.secondaryTextDynamic)
                }
                
                // Confirm Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .golfCaption()
                        .foregroundColor(.secondaryTextDynamic)
                    
                    SecureField("Confirm your password", text: $registrationData.confirmPassword)
                        .textFieldStyle(GolfTextFieldStyle())
                    
                    if !registrationData.confirmPassword.isEmpty && registrationData.password != registrationData.confirmPassword {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.error)
                    }
                }
            }
        }
    }
}

// MARK: - Personal Info Step (Step 2)
struct PersonalInfoStep: View {
    @Binding var registrationData: RegistrationData
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Personal Information")
                    .golfTitle()
                    .foregroundColor(.primaryTextDynamic)
                
                Text("Tell us a bit about yourself")
                    .font(.subheadline)
                    .foregroundColor(.secondaryTextDynamic)
            }
            
            VStack(spacing: 20) {
                // First Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("First Name")
                        .golfCaption()
                        .foregroundColor(.secondaryTextDynamic)
                    
                    TextField("Enter your first name", text: $registrationData.firstName)
                        .textFieldStyle(GolfTextFieldStyle())
                        .autocapitalization(.words)
                }
                
                // Last Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Name")
                        .golfCaption()
                        .foregroundColor(.secondaryTextDynamic)
                    
                    TextField("Enter your last name", text: $registrationData.lastName)
                        .textFieldStyle(GolfTextFieldStyle())
                        .autocapitalization(.words)
                }
                
                // Handicap Field (Optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Handicap (Optional)")
                        .golfCaption()
                        .foregroundColor(.secondaryTextDynamic)
                    
                    TextField("Enter your handicap", text: $registrationData.handicap)
                        .textFieldStyle(GolfTextFieldStyle())
                        .keyboardType(.decimalPad)
                    
                    Text("Leave blank if you're not sure")
                        .font(.caption)
                        .foregroundColor(.secondaryTextDynamic)
                }
            }
        }
    }
}

// MARK: - Golf Profile Step (Step 3)
struct GolfProfileStep: View {
    @Binding var registrationData: RegistrationData
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Golf Profile")
                    .golfTitle()
                    .foregroundColor(.primaryTextDynamic)
                
                Text("Help us personalize your experience")
                    .font(.subheadline)
                    .foregroundColor(.secondaryTextDynamic)
            }
            
            VStack(spacing: 24) {
                // Preferred Hand
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferred Hand")
                        .golfCaption()
                        .foregroundColor(.secondaryTextDynamic)
                    
                    HStack(spacing: 12) {
                        ForEach(GolfHand.allCases, id: \.self) { hand in
                            Button(action: {
                                registrationData.preferredHand = hand
                            }) {
                                HStack {
                                    Image(systemName: registrationData.preferredHand == hand ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(registrationData.preferredHand == hand ? .accentDynamic : .secondaryTextDynamic)
                                    
                                    Text(hand.displayName)
                                        .golfBody()
                                        .foregroundColor(.primaryTextDynamic)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(registrationData.preferredHand == hand ? 
                                              Color.accentDynamic.opacity(0.1) : 
                                              Color.cardBackgroundDynamic)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(registrationData.preferredHand == hand ? 
                                                       Color.accentDynamic : 
                                                       Color.secondaryTextDynamic.opacity(0.3), 
                                                       lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Experience Level
                VStack(alignment: .leading, spacing: 12) {
                    Text("Experience Level")
                        .golfCaption()
                        .foregroundColor(.secondaryTextDynamic)
                    
                    VStack(spacing: 8) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            Button(action: {
                                registrationData.experienceLevel = level
                            }) {
                                HStack {
                                    Image(systemName: registrationData.experienceLevel == level ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(registrationData.experienceLevel == level ? .accentDynamic : .secondaryTextDynamic)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(level.displayName)
                                            .golfBody()
                                            .foregroundColor(.primaryTextDynamic)
                                        
                                        Text(level.description)
                                            .font(.caption)
                                            .foregroundColor(.secondaryTextDynamic)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(registrationData.experienceLevel == level ? 
                                              Color.accentDynamic.opacity(0.1) : 
                                              Color.cardBackgroundDynamic)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(registrationData.experienceLevel == level ? 
                                                       Color.accentDynamic : 
                                                       Color.secondaryTextDynamic.opacity(0.3), 
                                                       lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Terms and Conditions
                VStack(spacing: 12) {
                    Button(action: {
                        registrationData.agreedToTerms.toggle()
                    }) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: registrationData.agreedToTerms ? "checkmark.square.fill" : "square")
                                .foregroundColor(registrationData.agreedToTerms ? .accentDynamic : .secondaryTextDynamic)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("I agree to the Terms of Service and Privacy Policy")
                                    .golfBody()
                                    .foregroundColor(.primaryTextDynamic)
                                    .multilineTextAlignment(.leading)
                                
                                HStack {
                                    Button("Terms of Service") {
                                        // Open terms
                                    }
                                    .foregroundColor(.accentDynamic)
                                    .font(.caption)
                                    
                                    Text("•")
                                        .foregroundColor(.secondaryTextDynamic)
                                        .font(.caption)
                                    
                                    Button("Privacy Policy") {
                                        // Open privacy policy
                                    }
                                    .foregroundColor(.accentDynamic)
                                    .font(.caption)
                                    
                                    Spacer()
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// MARK: - Custom Text Field Style
struct GolfTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackgroundDynamic)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondaryTextDynamic.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.primaryTextDynamic)
            .font(.body)
    }
}

struct RegistrationStepsPreview: PreviewProvider {
    static var previews: some View {
        VStack {
            AccountDetailsStep(registrationData: .constant(RegistrationData()))
        }
        .padding()
        .background(Color.primaryBackgroundDynamic)
    }
}