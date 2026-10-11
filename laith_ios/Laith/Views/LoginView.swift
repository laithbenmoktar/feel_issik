import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @State private var register = false
    @State private var identifier = ""
    @State private var password = ""
    @State private var first = ""
    @State private var last = ""
    @State private var level = studyLevels[1]
    @State private var busy = false
    @State private var message: String?
    @State private var info: String?
    @State private var choosePassword = false
    @State private var newPassword = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ClubLogo(size: 104).padding(.top, 30)
                Text("Bienvenue").font(.largeTitle.bold()).foregroundColor(.textDark).accessibilityAddTraits(.isHeader)
                Text("Connectez-vous pour accéder à l'espace du club FEEL ISSIK")
                    .multilineTextAlignment(.center).foregroundColor(.textGray)

                Picker("", selection: $register) {
                    Text("Se connecter").tag(false); Text("Créer un compte").tag(true)
                }.pickerStyle(.segmented)

                if let m = message ?? (app.refusedNotice ? AppState.refusedMsg : nil) {
                    Text(m).font(.callout).foregroundColor(.danger).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.danger.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if let info { Text(info).font(.callout).foregroundColor(.okGreen) }

                if register {
                    FormField(label: "Prénom *", text: $first)
                    FormField(label: "Nom de famille *", text: $last)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Niveau d'études à l'ISSIK *").font(.caption.bold()).foregroundColor(.textBlue)
                        Picker("Niveau", selection: $level) { ForEach(studyLevels, id: \.self) { Text($0).tag($0) } }
                            .pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    FormField(label: "Adresse Email *", text: $identifier, keyboard: .emailAddress)
                } else {
                    FormField(label: "Email ou identifiant *", text: $identifier, keyboard: .emailAddress)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mot de passe (bureau seulement)").font(.caption.bold()).foregroundColor(.textBlue)
                    SecureField("Membre : laissez vide, votre e-mail suffit", text: $password)
                        .padding(10).background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cardBorder))
                }

                PrimaryButton(title: busy ? "…" : (register ? "Créer mon compte" : "Se connecter"), disabled: busy) { Task { await submit() } }

                if !register {
                    Button("Mot de passe oublié ?") { Task { await forgot() } }.font(.callout)
                }
            }
            .padding(20)
        }
        .background(Color.pageBg.ignoresSafeArea())
        .alert("Choisissez votre mot de passe", isPresented: $choosePassword) {
            SecureField("6 caractères minimum", text: $newPassword)
            Button("Enregistrer") { Task { await savePassword() } }
            Button("Plus tard", role: .cancel) { }
        } message: { Text("Un compte du bureau doit avoir un vrai mot de passe.") }
    }

    private func submit() async {
        message = nil; info = nil; app.refusedNotice = false
        busy = true; defer { busy = false }
        do {
            if register {
                if first.trimmingCharacters(in: .whitespaces).isEmpty || last.trimmingCharacters(in: .whitespaces).isEmpty || !identifier.contains("@") {
                    message = "Remplissez prénom, nom et une adresse e-mail valide"; return
                }
                try await app.register(first: first.trimmingCharacters(in: .whitespaces), last: last.trimmingCharacters(in: .whitespaces),
                                       email: identifier, pass: password, level: level)
            } else {
                if try await app.login(identifier: identifier, pass: password) == .mustChoosePassword { choosePassword = true }
            }
        } catch { message = app.errorText(error) }
    }

    private func forgot() async {
        message = nil; info = nil
        guard identifier.contains("@") else { message = "Entrez d'abord votre adresse e-mail"; return }
        do { try await app.resetPassword(email: identifier); info = "E-mail de réinitialisation envoyé ✔" }
        catch { message = app.errorText(error) }
    }

    private func savePassword() async {
        do { try await app.setMyPassword(newPassword); info = "Mot de passe enregistré ✔" }
        catch { message = app.errorText(error) }
        newPassword = ""
    }
}
