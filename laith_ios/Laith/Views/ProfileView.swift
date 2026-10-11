import SwiftUI
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var request = LiveDocument()
    @State private var editing = false
    @State private var first = "", last = "", level = studyLevels[1]
    @State private var newPassword = ""
    @State private var message: String?
    @State private var showPassword = false

    var body: some View {
        let p = app.profile
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    AvatarView(b64: p?.photo, initials: p?.initials ?? "?", size: 96)
                    HStack {
                        PhotoPickerButton(maxSide: 400, onPicked: { savePhoto($0) }) {
                            Text(p?.photo.isEmpty == false ? "Changer" : "Ajouter une photo").font(.callout.bold())
                        }
                        if p?.photo.isEmpty == false { Button("Retirer", role: .destructive) { removePhoto() } }
                    }
                    Text(app.displayName()).font(.title2.bold())
                    Text(app.isBureau ? "👑 Bureau" : "Membre").font(.caption.bold()).foregroundColor(.textBlue)
                }.frame(maxWidth: .infinity).padding(16).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))

                CardBox {
                    Text("Mes informations").font(.headline)
                    if editing {
                        FormField(label: "Prénom", text: $first)
                        FormField(label: "Nom", text: $last)
                        Picker("Niveau", selection: $level) { ForEach(studyLevels, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                        HStack { Button("Annuler") { editing = false }; Spacer(); Button("Enregistrer") { Task { await saveInfo() } }.bold() }
                    } else {
                        row("E-mail", p?.email ?? app.user?.email ?? "")
                        row("Niveau", p?.level ?? "")
                        if let ph = p?.phone, !ph.isEmpty { row("Téléphone", ph) }
                        Button("✏ Modifier") {
                            first = p?.firstName ?? ""; last = p?.lastName ?? ""
                            level = studyLevels.contains(p?.level ?? "") ? p!.level : studyLevels[1]; editing = true
                        }
                    }
                }

                CardBox {
                    Text("Adhésion").font(.headline)
                    if app.isBureau { Text("👑 Membre du bureau : fait déjà partie du club.").foregroundColor(.textGray) }
                    else if let st = request.data?["status"] as? String ?? (p?.joinStatus.isEmpty == false ? p?.joinStatus : nil) {
                        Text("Statut : \(joinStatusLabel(st))")
                        if let poles = p?.poles, !poles.isEmpty { Text("🎨 " + poles.joined(separator: " · ")).font(.caption).foregroundColor(.textGray) }
                    } else {
                        Text("Aucune demande envoyée.").foregroundColor(.textGray)
                        Button("Nous rejoindre →") { app.go = .join }
                    }
                }

                if let message { Text(message).font(.callout).foregroundColor(.textBlue) }
                Button("🔑 Définir / changer mon mot de passe") { showPassword = true }
                Button("Se déconnecter", role: .destructive) { app.logout() }
            }.padding(16)
        }
        .background(Color.pageBg)
        .onAppear { if let uid = app.myUid { request.start(app.db.collection("joinRequests").document(uid)) } }
        .onDisappear { request.stop() }
        .alert("Nouveau mot de passe", isPresented: $showPassword) {
            SecureField("6 caractères minimum", text: $newPassword)
            Button("Enregistrer") { Task {
                do { try await app.setMyPassword(newPassword); message = "Mot de passe enregistré ✔" }
                catch { message = app.errorText(error) }
                newPassword = "" } }
            Button("Annuler", role: .cancel) { newPassword = "" }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) { Text(k).font(.caption.bold()).foregroundColor(.textBlue).frame(width: 80, alignment: .leading); Text(v) }
    }

    private func savePhoto(_ b64: String) {
        guard let uid = app.myUid else { return }
        app.db.collection("users").document(uid).setData(["photo": b64], merge: true) { err in
            Task { @MainActor in
                if let err { message = app.errorText(err) } else { await app.loadProfile() }
            }
        }
    }
    private func removePhoto() {
        guard let uid = app.myUid else { return }
        app.db.collection("users").document(uid).updateData(["photo": FieldValue.delete()]) { _ in Task { @MainActor in await app.loadProfile() } }
    }
    private func saveInfo() async {
        guard let uid = app.myUid else { return }
        do {
            try await app.db.collection("users").document(uid).setData(
                ["firstName": first.trimmingCharacters(in: .whitespaces), "lastName": last.trimmingCharacters(in: .whitespaces), "level": level], merge: true)
            await app.loadProfile(); editing = false
        } catch { message = app.errorText(error) }
    }
}
