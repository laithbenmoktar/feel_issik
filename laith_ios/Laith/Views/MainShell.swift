import SwiftUI

enum Screen: String, CaseIterable {
    case home, events, team, join, profile, chat, movies, rejoignants, database
}

/// Menu hamburger ☰ (tiroir latéral) à la place de la barre du bas ; le mode Bureau est global.
struct MainShell: View {
    @EnvironmentObject var app: AppState
    @State private var screen: Screen = .home
    @State private var menuOpen = false
    @State private var pendingPole: String?

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                content
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button { withAnimation { menuOpen = true } } label: { Image(systemName: "line.3.horizontal") }
                        }
                    }
                    .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            }
            if menuOpen {
                Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { withAnimation { menuOpen = false } }
                SideMenu(screen: $screen, close: { withAnimation { menuOpen = false } })
                    .transition(.move(edge: .leading))
            }
        }
        .onAppear { app.probeRules(); Task { await app.loadProfile() } }
        .onChange(of: app.go) { g in if let g { screen = g; app.go = nil } }
    }

    private var title: String {
        switch screen {
        case .home: return "FEEL ISSIK"
        case .events: return "Événements & Agenda"
        case .team: return "Espace Bureau & Responsables"
        case .join: return "Nous Rejoindre"
        case .profile: return "Mon Profil"
        case .chat: return "Salon & Memories"
        case .movies: return "Movie Suggestion"
        case .rejoignants: return "Tableau des Rejoignants"
        case .database: return "Base de données & accès"
        }
    }

    @ViewBuilder private var content: some View {
        switch screen {
        case .home: HomeView(pendingPole: $pendingPole)
        case .events: EventsView()
        case .team: TeamView(openPole: { id in pendingPole = id; screen = .home })
        case .join: JoinView(done: { screen = .home })
        case .profile: ProfileView()
        case .chat: ChatView()
        case .movies: MoviesView()
        case .rejoignants: RejoignantsView()
        case .database: DatabaseView()
        }
    }
}

struct SideMenu: View {
    @EnvironmentObject var app: AppState
    @Binding var screen: Screen
    let close: () -> Void

    private func item(_ label: String, _ s: Screen) -> some View {
        Button { screen = s; close() } label: {
            Text(label).font(.body.weight(screen == s ? .bold : .regular)).foregroundColor(.textDark)
                .padding(.vertical, 12).padding(.horizontal, 16).frame(maxWidth: .infinity, alignment: .leading)
                .background(screen == s ? Color.daySelected : Color.clear)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if let ph = app.profile?.photo, !ph.isEmpty { AvatarView(b64: ph, initials: app.profile?.initials ?? "FI", size: 52) } else { ClubLogo(size: 52) }
                VStack(alignment: .leading) {
                    Text("FEEL ISSIK").font(.headline).foregroundColor(.white)
                    Text(app.isBureau ? "👑 \(app.displayName()) · Bureau"
                         : app.displayName() + ((app.profile?.level.isEmpty == false) ? " · \(app.profile!.level)" : ""))
                        .font(.caption).foregroundColor(Color(hex: 0xCBD5E1)).lineLimit(2)
                }
            }
            .padding(16).padding(.top, 40).frame(maxWidth: .infinity, alignment: .leading).background(Color.navy)

            ScrollView {
                VStack(spacing: 0) {
                    item("🏠   Sous-Groupes", .home)
                    item("📅   Événements & Agenda", .events)
                    item("👥   Espace Bureau & Responsables", .team)
                    item("✍️   Nous Rejoindre", .join)
                    item("👤   Mon Profil", .profile)
                    item("💬   Salon & Memories", .chat)
                    item("🎬   Movie Suggestion", .movies)
                    if app.isBureau {
                        Divider().padding(.vertical, 6)
                        Text("MODE BUREAU").font(.caption.bold()).foregroundColor(.textBlue)
                            .padding(.horizontal, 16).frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("👑 Mode Bureau (✏ partout)", isOn: $app.bureauModeEnabled).padding(.horizontal, 16).padding(.vertical, 6)
                        if app.bureauActive {
                            item("📊   Tableau des Rejoignants", .rejoignants)
                            item("🗄️   Base de données & accès", .database)
                        }
                    }
                }
            }
            Divider()
            Button { close(); app.logout() } label: {
                Text("↩︎   Se déconnecter").foregroundColor(.danger).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.7")")
                .font(.caption2).foregroundColor(.textGray).padding(.horizontal, 16).padding(.bottom, 12)
        }
        .frame(width: min(300, UIScreen.main.bounds.width * 0.86)).background(Color.white).ignoresSafeArea()
    }
}
