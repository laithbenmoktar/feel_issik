import SwiftUI
import CryptoKit
import FirebaseAuth
import FirebaseFirestore

enum LoginResult { case ok, mustChoosePassword }

struct AppError: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}

/// Équivalent iOS de `Repo.kt` + `BureauMode.kt` : session, profil, rôle, mode Bureau.
@MainActor
final class AppState: ObservableObject {
    static let adminUser = "admin"
    static let adminPass = "2026"
    static let emailDomain = "@feel-issik.app"
    static let adminEmail = adminUser + emailDomain
    private static let pad = "#FEELISSIK"          // Firebase exige 6 caractères minimum
    static let refusedMsg = "Votre demande d'adhésion a été refusée : l'accès à votre espace est fermé. Contactez le bureau."

    @Published var user: User?
    @Published var profile: UserProfile?
    @Published var bureauModeEnabled = true
    @Published var refusedNotice = false
    @Published var rulesBroken = false
    /// Navigation demandée depuis un écran (ex. bouton « Rejoindre ») ; consommée par MainShell.
    @Published var go: Screen?

    var db: Firestore { Firestore.firestore() }
    var isLoggedIn: Bool { user != nil }
    var isBureau: Bool { profile?.isBureau == true }
    var bureauActive: Bool { bureauModeEnabled && isBureau }
    var myUid: String? { user?.uid }

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        user = Auth.auth().currentUser
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, u in
            Task { @MainActor in
                guard let self else { return }
                self.user = u
                if u != nil { await self.loadProfile() } else { self.profile = nil }
            }
        }
    }

    func displayName() -> String {
        if let p = profile, !p.fullName.isEmpty { return p.fullName }
        guard let mail = user?.email else { return "Membre" }
        return mail == Self.adminEmail ? "Admin Bureau" : String(mail.split(separator: "@").first ?? "Membre")
    }

    // MARK: Identifiants (identiques à Android : un compte créé sur Android marche sur iOS)
    private func authEmail(_ input: String) -> String {
        let t = input.trimmingCharacters(in: .whitespaces).lowercased()
        return t.contains("@") ? t : t + Self.emailDomain
    }
    private func authPassword(_ p: String) -> String { p.count >= 6 ? p : p + Self.pad }
    private func emailOnlyPassword(_ email: String) -> String {
        let src = "feel-issik|" + email.trimmingCharacters(in: .whitespaces).lowercased() + "|membre"
        let hex = SHA256.hash(data: Data(src.utf8)).map { String(format: "%02x", $0) }.joined()
        return "FI-" + hex.prefix(28)
    }

    // MARK: Profil
    @discardableResult
    func loadProfile(retry: Bool = true) async -> UserProfile? {
        guard let u = Auth.auth().currentUser else { profile = nil; return nil }
        do {
            let snap = try await db.collection("users").document(u.uid).getDocument()
            if snap.exists, let data = snap.data() {
                var p = UserProfile(uid: u.uid, data: data)
                if u.email == Self.adminEmail && p.role != "bureau" {
                    try? await db.collection("users").document(u.uid).updateData(["role": "bureau"])
                    p.role = "bureau"
                }
                // Demande REFUSÉE : plus d'accès à l'espace membre
                if !p.isBureau && p.joinStatus == "refusé" {
                    refusedNotice = true
                    try? Auth.auth().signOut(); profile = nil
                    return nil
                }
                profile = p
                return p
            } else {
                _ = try await createProfile(uid: u.uid, first: "", last: "", email: u.email ?? "", level: "", forcedRole: nil)
                return profile
            }
        } catch {
            if retry && isDenied(error) {
                _ = try? await u.getIDTokenResult(forcingRefresh: true)
                return await loadProfile(retry: false)
            }
            return profile
        }
    }

    private func createProfile(uid: String, first: String, last: String, email: String, level: String, forcedRole: String?) async throws {
        let isAdmin = email == Self.adminEmail
        let role = forcedRole ?? (isAdmin ? "bureau" : "member")
        let f = (isAdmin && first.isEmpty) ? "Admin" : first
        let l = (isAdmin && last.isEmpty) ? "Bureau" : last
        let data: [String: Any] = ["firstName": f, "lastName": l, "email": email, "level": level,
                                   "role": role, "createdAt": FieldValue.serverTimestamp()]
        do { try await db.collection("users").document(uid).setData(data) }
        catch {
            if isDenied(error) {
                _ = try? await Auth.auth().currentUser?.getIDTokenResult(forcingRefresh: true)
                try await db.collection("users").document(uid).setData(data)
            } else { throw error }
        }
        var p = UserProfile(); p.uid = uid; p.firstName = f; p.lastName = l; p.email = email; p.level = level; p.role = role
        profile = p
    }

    // MARK: Connexion / inscription
    func login(identifier: String, pass: String) async throws -> LoginResult {
        if identifier.trimmingCharacters(in: .whitespaces).isEmpty { throw AppError("Entrez votre adresse e-mail") }
        let email = authEmail(identifier)

        if pass.trimmingCharacters(in: .whitespaces).isEmpty {          // membre : e-mail seul
            if email == Self.adminEmail || !identifier.contains("@") { throw AppError("Le compte du bureau demande un mot de passe") }
            do { _ = try await Auth.auth().signIn(withEmail: email, password: emailOnlyPassword(email)) }
            catch {
                if let c = AuthErrorCode.Code(rawValue: (error as NSError).code),
                   c == .userNotFound || c == .wrongPassword || c == .invalidCredential {
                    throw AppError("Aucun compte sans mot de passe pour cet e-mail. Créez le compte (onglet « Créer un compte »), ou saisissez votre mot de passe si vous en aviez choisi un.")
                }
                throw AppError(errorText(error))
            }
            await loadProfile()
            if !isLoggedIn { refusedNotice = false; throw AppError(Self.refusedMsg) }
            return isBureau ? .mustChoosePassword : .ok
        }

        // Avec mot de passe (bureau, ou ancien compte)
        if email == Self.adminEmail && pass != Self.adminPass && authPassword(Self.adminPass) == pass && pass.count >= 6 {
            throw AppError("Identifiant, email ou mot de passe incorrect")
        }
        do { _ = try await Auth.auth().signIn(withEmail: email, password: authPassword(pass)) }
        catch {
            let c = AuthErrorCode.Code(rawValue: (error as NSError).code)
            if email == Self.adminEmail && pass == Self.adminPass &&
                (c == .userNotFound || c == .wrongPassword || c == .invalidCredential) {
                try await createAdminAccount()
                return .ok
            }
            throw AppError(errorText(error))
        }
        await loadProfile()
        if !isLoggedIn { refusedNotice = false; throw AppError(Self.refusedMsg) }
        return .ok
    }

    private func createAdminAccount() async throws {
        do {
            let res = try await Auth.auth().createUser(withEmail: Self.adminEmail, password: authPassword(Self.adminPass))
            try await createProfile(uid: res.user.uid, first: "Admin", last: "Bureau", email: Self.adminEmail, level: "", forcedRole: "bureau")
        } catch {
            if AuthErrorCode.Code(rawValue: (error as NSError).code) == .emailAlreadyInUse {
                throw AppError("Identifiant ou mot de passe incorrect")
            }
            throw AppError(errorText(error))
        }
    }

    func register(first: String, last: String, email: String, pass: String, level: String) async throws {
        if !pass.isEmpty && pass.count < 6 { throw AppError("Le mot de passe doit contenir au moins 6 caractères (ou laissez-le vide)") }
        let mail = email.trimmingCharacters(in: .whitespaces).lowercased()
        if mail == Self.adminEmail { throw AppError("Cette adresse est réservée") }
        do {
            let res = try await Auth.auth().createUser(withEmail: mail, password: pass.isEmpty ? emailOnlyPassword(mail) : pass)
            try await createProfile(uid: res.user.uid, first: first, last: last, email: mail, level: level, forcedRole: "member")
        } catch let e as AppError { throw e }
        catch { throw AppError(errorText(error)) }
    }

    func resetPassword(email: String) async throws {
        do { try await Auth.auth().sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespaces)) }
        catch { throw AppError(errorText(error)) }
    }

    func setMyPassword(_ newPass: String) async throws {
        guard let u = Auth.auth().currentUser else { throw AppError("Connexion requise") }
        if newPass.count < 6 { throw AppError("Le mot de passe doit contenir au moins 6 caractères") }
        do { try await u.updatePassword(to: newPass) } catch { throw AppError(errorText(error)) }
    }

    func logout() { try? Auth.auth().signOut(); profile = nil }

    func probeRules() {
        Task {
            do { _ = try await db.collection("config").document("probe").getDocument(); rulesBroken = false }
            catch { rulesBroken = isDenied(error) }
        }
    }

    // MARK: Erreurs lisibles
    func isDenied(_ e: Error) -> Bool {
        let ns = e as NSError
        return ns.domain == "FIRFirestoreErrorDomain" && ns.code == 7      // PERMISSION_DENIED
    }

    func errorText(_ e: Error) -> String {
        if let a = e as? AppError { return a.message }
        let ns = e as NSError
        if ns.domain == "FIRAuthErrorDomain", let c = AuthErrorCode.Code(rawValue: ns.code) {
            switch c {
            case .userNotFound, .wrongPassword, .invalidCredential, .invalidEmail: return "Identifiant, email ou mot de passe incorrect"
            case .emailAlreadyInUse: return "Cet email est déjà utilisé"
            case .weakPassword: return "Mot de passe trop faible (6 caractères minimum)"
            case .networkError: return "Pas de connexion internet"
            case .tooManyRequests: return "Trop de tentatives. Réessayez dans quelques minutes"
            case .operationNotAllowed: return "Connexion par email désactivée : activez « E-mail/Mot de passe » dans Firebase > Authentication"
            case .requiresRecentLogin: return "Reconnectez-vous avant de changer le mot de passe"
            default: break
            }
        }
        if ns.domain == "FIRFirestoreErrorDomain" {
            if ns.code == 7 {
                if rulesBroken { return "Base inaccessible : règles Firestore non publiées. Le bureau doit ouvrir Menu ☰ → Base de données & accès" }
                if !isLoggedIn { return "Connexion requise pour effectuer cette action" }
                if isBureau { return "Accès refusé : règles Firestore à republier (Menu ☰ → Base de données & accès)" }
                return "Action non autorisée avec ce compte. Reconnectez-vous ou prévenez le bureau"
            }
            if ns.code == 14 {     // UNAVAILABLE
                return "Pas de connexion internet" }
        }
        return ns.localizedDescription
    }

    // MARK: Diagnostic d'accès (Espace Bureau)
    func diagnose() async -> String {
        let checks = ["users", "joinRequests", "team", "events", "news", "movies", "subgroups", "config"]
        var lines: [String] = []
        var denied = 0
        for c in checks {
            do { _ = try await db.collection(c).limit(to: 1).getDocuments(); lines.append("✔ Lecture « \(c) »") }
            catch { if isDenied(error) { denied += 1 }; lines.append("✖ Lecture « \(c) » : \(errorText(error))") }
        }
        if isBureau {
            do {
                try await db.collection("config").document("healthcheck")
                    .setData(["checkedAt": FieldValue.serverTimestamp()], merge: true)
                lines.append("✔ Écriture (document config/healthcheck)")
            } catch { if isDenied(error) { denied += 1 }; lines.append("✖ Écriture : \(errorText(error))") }
        } else { lines.append("– Écriture : ignorée (compte non bureau)") }
        let hint: String
        if user == nil { hint = "→ Vous n'êtes pas connecté." }
        else if denied >= 3 { hint = "→ Presque tout est refusé : les règles Firestore publiées sont absentes ou expirées. Copiez firestore.rules dans Firebase → Firestore → Règles → Publier." }
        else if denied > 0 { hint = "→ Quelques accès sont refusés : vérifiez que ce compte a bien role = bureau et que firestore.rules est la dernière version." }
        else if lines.allSatisfy({ $0.hasPrefix("✔") || $0.hasPrefix("–") }) { hint = "→ Tout fonctionne ✔" }
        else { hint = "→ Voir les erreurs ci-dessus (réseau ?)." }
        return "Compte : \(user?.email ?? "non connecté")\nRôle : \(profile?.role ?? "inconnu")\n\n" + lines.joined(separator: "\n") + "\n\n" + hint
    }
}

// MARK: - Écoute Firestore en direct
/// Écoute une collection ou un document ; à démarrer dans `.onAppear`, à arrêter dans `.onDisappear`.
@MainActor
final class LiveCollection: ObservableObject {
    @Published var docs: [QueryDocumentSnapshot] = []
    @Published var error: Error?
    private var reg: ListenerRegistration?

    func start(_ query: Query) {
        reg?.remove()
        reg = query.addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                if let err { self?.error = err; return }
                self?.error = nil
                self?.docs = snap?.documents ?? []
            }
        }
    }
    func stop() { reg?.remove(); reg = nil }
    deinit { reg?.remove() }
}

@MainActor
final class LiveDocument: ObservableObject {
    @Published var data: [String: Any]?
    private var reg: ListenerRegistration?

    func start(_ ref: DocumentReference) {
        reg?.remove()
        reg = ref.addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                if err != nil { return }
                self?.data = (snap?.exists == true) ? snap?.data() : nil
            }
        }
    }
    func stop() { reg?.remove(); reg = nil }
    deinit { reg?.remove() }
}
