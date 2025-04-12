import Foundation
import FirebaseAuth

class AuthService: ObservableObject {
    
    @Published var currentUser: User?
    
    private var authStateHandlerHandle: AuthStateDidChangeListenerHandle?

    init() {
        
        print("AuthService initialized. Current user: \(Auth.auth().currentUser?.uid ?? "None")")
        
        self.currentUser = Auth.auth().currentUser
    }

    
    func listenToAuthState() {
        if authStateHandlerHandle != nil { return }
        print("Starting Auth State Listener...")
        authStateHandlerHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.currentUser = user
                if let user = user {
                    print("Auth State Changed: User logged in - \(user.uid)")
                } else {
                    print("Auth State Changed: User logged out.")
                }
            }
        }
    }

    func stopListening() {
        if let handle = authStateHandlerHandle {
            print("Stopping Auth State Listener...")
            Auth.auth().removeStateDidChangeListener(handle)
            authStateHandlerHandle = nil
        }
    }

    // Sign Up
    func signUp(email: String, password: String) async throws {
        do {
            // Use Firebase Auth to create a new user
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            // Update published user on main thread (though listener should also catch this)
            await MainActor.run {
                 self.currentUser = authResult.user
                 print("✅ Sign Up Successful: \(authResult.user.uid)")
             }
            // Optional: Send verification email, update profile, etc.
        } catch {
            print("🔴 Sign Up Error: \(error.localizedDescription)")
            throw error // Re-throw the error for the view to handle
        }
    }

    // Sign In
    func signIn(email: String, password: String) async throws {
        do {
            // Use Firebase Auth to sign in
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            // Update published user on main thread (though listener should also catch this)
             await MainActor.run {
                 self.currentUser = authResult.user
                 print("✅ Sign In Successful: \(authResult.user.uid)")
             }
        } catch {
            print("🔴 Sign In Error: \(error.localizedDescription)")
            throw error // Re-throw the error for the view to handle
        }
    }

    // Sign Out
    func signOut() async throws {
        do {
            // Use Firebase Auth to sign out
            try Auth.auth().signOut()
            // Update published user on main thread (though listener should also catch this)
             await MainActor.run { // Ensure UI update happens on main thread
                 self.currentUser = nil
                 print("✅ Sign Out Successful")
             }
        } catch {
            print("🔴 Sign Out Error: \(error.localizedDescription)")
            throw error // Re-throw the error for the view to handle
        }
    }
    
    // Deinitializer to ensure listener is removed if AuthService is deallocated
    deinit {
        stopListening()
    }
}
