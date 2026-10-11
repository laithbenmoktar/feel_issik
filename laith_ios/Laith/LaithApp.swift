import SwiftUI
import FirebaseCore

@main
struct LaithApp: App {
    @StateObject private var app: AppState

    init() {
        FirebaseApp.configure()          // nécessite GoogleService-Info.plist (voir README-iOS.md)
        _app = StateObject(wrappedValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(app).tint(.primaryBlue).preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        // 1re page = connexion ; une fois connecté, l'accueil (comme Android v1.7)
        if app.isLoggedIn { MainShell() } else { LoginView() }
    }
}
