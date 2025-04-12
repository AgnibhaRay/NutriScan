import SwiftUI
import FirebaseCore
import FirebaseAuth // Import FirebaseAuth

@main
struct NutriScanApp: App {
    @StateObject var authService = AuthService()

    init() {
        FirebaseApp.configure()
        print("Firebase configured!")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.currentUser != nil {
                    ContentView()
                        .environmentObject(authService)
                } else {
                    AuthenticationRootView()
                        .environmentObject(authService)
                }
            }
             .onAppear {
                 authService.listenToAuthState()
             }
        }
    }
}
