import SwiftUI
import FirebaseAuth // Make sure this is imported if User type is needed directly

// MARK: - Root Authentication View
struct AuthenticationRootView: View {
    @State private var showSignIn = true // Start with Sign In view

    var body: some View {
        // Use a ZStack to allow for transitions between Sign In and Sign Up
        ZStack {
            // Use system background for adaptability
            Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)

            if showSignIn {
                SignInView(showSignIn: $showSignIn)
                    // Apply a transition for smoother switching
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
            } else {
                SignUpView(showSignIn: $showSignIn)
                    // Apply a transition for smoother switching
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            }
        }
        // Animate the switch between views
        .animation(.easeInOut(duration: 0.4), value: showSignIn)
    }
}

// MARK: - Shared Styling Components
struct AuthTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(15) // More padding
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12) // More rounded corners
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1) // Subtle border
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool // Check if button is enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(isEnabled ? Color.blue : Color.gray.opacity(0.5)) // Use accent color, gray when disabled
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0) // Subtle scale on press
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
     func makeBody(configuration: Configuration) -> some View {
         configuration.label
             .font(.footnote)
             .foregroundColor(configuration.isPressed ? .gray : .blue) // Change color on press
     }
 }


// MARK: - Sign In View
struct SignInView: View {
    @Binding var showSignIn: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    @State private var animate = false // For entry animation
    
    @EnvironmentObject var authService: AuthService

    var body: some View {
        ScrollView { // Use ScrollView to prevent overflow on smaller screens
            VStack(spacing: 25) { // Increased spacing
                
                Spacer().frame(height: 30) // Top spacer

                Text("Welcome to")
                    .multilineTextAlignment(.center)
                    .font(.title2.weight(.semibold)) // Slightly smaller and less bold
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : -20)
                
                // App Icon / Logo (Optional)
                Text("NutriScan") // Replace with your app logo if you have one
                    .font(.system(size: 40, weight: .bold)) // Increased font size and bold
                    .foregroundColor(.green)
                    .padding(.bottom, 10) // Adjust padding
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : -20)


                // Email Field
                VStack(alignment: .leading, spacing: 5) {
                     Text("Email").font(.caption).foregroundColor(.secondary)
                     TextField("Enter your email", text: $email)
                         .keyboardType(.emailAddress)
                         .textContentType(.emailAddress)
                         .autocapitalization(.none)
                         .modifier(AuthTextFieldStyle()) // Apply consistent style
                 }
                 .opacity(animate ? 1 : 0)
                 .offset(y: animate ? 0 : -20)

                // Password Field
                VStack(alignment: .leading, spacing: 5) {
                     Text("Password").font(.caption).foregroundColor(.secondary)
                     SecureField("Enter your password", text: $password)
                         .textContentType(.password)
                         .modifier(AuthTextFieldStyle()) // Apply consistent style
                 }
                 .opacity(animate ? 1 : 0)
                 .offset(y: animate ? 0 : -20)

                // Display Error Message
                if let errorMessage = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                        Text(errorMessage)
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 5)
                    .opacity(animate ? 1 : 0) // Also animate error appearance
                }

                // Sign In Button
                Button {
                    signInUser()
                } label: {
                    if isLoading {
                        ProgressView().tint(.white).padding(.vertical, 1) // Match padding roughly
                    } else {
                        Text("Sign In").fontWeight(.semibold)
                    }
                }
                .buttonStyle(PrimaryButtonStyle()) // Apply primary style
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .padding(.top, 10)
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 20) // Slide up

                // Switch to Sign Up Button
                Button {
                    withAnimation { showSignIn = false } // Animate the switch
                } label: {
                    Text("Don't have an account? Sign Up")
                }
                .buttonStyle(SecondaryButtonStyle()) // Apply secondary style
                .padding(.top, 15)
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 20)

                Spacer() // Pushes content up
            }
            .padding(.horizontal, 30) // Add horizontal padding
        }
        .onAppear {
            // Trigger entry animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animate = true
            }
        }
    }
    
    // Function to handle sign in logic
    private func signInUser() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authService.signIn(email: email, password: password)
                // Listener handles navigation
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    @Binding var showSignIn: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    @State private var animate = false // For entry animation

    @EnvironmentObject var authService: AuthService

    var body: some View {
         ScrollView {
             VStack(spacing: 25) {
                 
                 Spacer().frame(height: 30)

                 // App Icon / Logo (Optional)
                 Image(systemName: "person.crop.circle.fill.badge.plus") // Different icon for sign up
                     .font(.system(size: 60))
                     .foregroundColor(.green) // Use different color for sign up maybe
                     .padding(.bottom, 20)
                     .opacity(animate ? 1 : 0)
                     .offset(y: animate ? 0 : -20)

                 Text("Create Account")
                     .font(.largeTitle.weight(.bold))
                     .opacity(animate ? 1 : 0)
                     .offset(y: animate ? 0 : -20)

                 // Email Field
                 VStack(alignment: .leading, spacing: 5) {
                      Text("Email").font(.caption).foregroundColor(.secondary)
                      TextField("Enter your email", text: $email)
                          .keyboardType(.emailAddress)
                          .textContentType(.emailAddress)
                          .autocapitalization(.none)
                          .modifier(AuthTextFieldStyle())
                  }
                  .opacity(animate ? 1 : 0)
                  .offset(y: animate ? 0 : -20)

                 // Password Field
                 VStack(alignment: .leading, spacing: 5) {
                      Text("Password").font(.caption).foregroundColor(.secondary)
                      SecureField("Create a password", text: $password)
                          .textContentType(.newPassword)
                          .modifier(AuthTextFieldStyle())
                  }
                  .opacity(animate ? 1 : 0)
                  .offset(y: animate ? 0 : -20)
                     
                 // Confirm Password Field
                 VStack(alignment: .leading, spacing: 5) {
                      Text("Confirm Password").font(.caption).foregroundColor(.secondary)
                      SecureField("Confirm your password", text: $confirmPassword)
                          .textContentType(.newPassword)
                          .modifier(AuthTextFieldStyle())
                  }
                  .opacity(animate ? 1 : 0)
                  .offset(y: animate ? 0 : -20)

                 // Display Error Message
                 if let errorMessage = errorMessage {
                     HStack {
                         Image(systemName: "exclamationmark.circle")
                         Text(errorMessage)
                     }
                     .foregroundColor(.red)
                     .font(.caption)
                     .padding(.top, 5)
                     .opacity(animate ? 1 : 0)
                 }
                 
                 // Validation Check
                 let passwordsMatch = !password.isEmpty && password == confirmPassword
                 let formIsValid = !email.isEmpty && passwordsMatch

                 // Sign Up Button
                 Button {
                      signUpUser()
                 } label: {
                      if isLoading {
                          ProgressView().tint(.white).padding(.vertical, 1)
                      } else {
                          Text("Sign Up").fontWeight(.semibold)
                      }
                 }
                 .buttonStyle(PrimaryButtonStyle()) // Apply primary style
                 .disabled(isLoading || !formIsValid) // Disable if loading or form invalid
                 .padding(.top, 10)
                 .opacity(animate ? 1 : 0)
                 .offset(y: animate ? 0 : 20)

                 // Switch to Sign In Button
                 Button {
                     withAnimation { showSignIn = true } // Animate the switch
                 } label: {
                     Text("Already have an account? Sign In")
                 }
                 .buttonStyle(SecondaryButtonStyle()) // Apply secondary style
                 .padding(.top, 15)
                 .opacity(animate ? 1 : 0)
                 .offset(y: animate ? 0 : 20)

                 Spacer()
             }
             .padding(.horizontal, 30)
         }
         .onAppear {
             // Trigger entry animation
             withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                 animate = true
             }
         }
     }
    
    // Function to handle sign up logic
    private func signUpUser() {
         guard password == confirmPassword else {
             errorMessage = "Passwords do not match."
             return
         }
         isLoading = true
         errorMessage = nil
         Task {
             do {
                 try await authService.signUp(email: email, password: password)
                 // Listener should handle navigation change
             } catch {
                 await MainActor.run {
                     errorMessage = error.localizedDescription
                     isLoading = false
                 }
             }
         }
     }
}
