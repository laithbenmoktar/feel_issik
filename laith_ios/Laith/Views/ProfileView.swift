import SwiftUI
import UIKit
import FirebaseFirestore

// MARK: - Carte de membre officielle (aussi utilisée pour l'impression)
struct MemberCardView: View {
    let p: UserProfile
    let accepted: Bool

    private let sky = Color(hex: 0x7DD3FC)
    private let amber = Color(hex: 0xFBBF24)

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "d MMMM yyyy"; return f
    }()
    static func format(_ d: Date?) -> String { d.map { dateFormat.string(from: $0) } ?? "—" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ClubLogo(size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text("FEEL ISSIK").font(.system(size: 15, weight: .bold))
                    Text("CLUB ÉTUDIANT · ISSIK KEF").font(.system(size: 8)).foregroundColor(sky)
                }
                Spacer()
                Text(accepted ? "✔ MEMBRE VALIDÉ" : "⏳ EN ATTENTE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(accepted ? Color(hex: 0x6EE7B7) : amber)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((accepted ? Color.okGreen : amber).opacity(0.2))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke((accepted ? Color.okGreen : amber).opacity(0.5)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 14) {
                Group {
                    if let img = ImageUtil.decode(p.photo) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        ZStack { Color.white.opacity(0.1); Text(p.initials.isEmpty ? "?" : p.initials).font(.system(size: 22, weight: .bold)) }
                    }
                }
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.4), lineWidth: 2))

                VStack(alignment: .leading, spacing: 2) {
                    Text(p.isBureau ? "MEMBRE DU BUREAU" : "ADHÉRENT(E) OFFICIEL(LE)")
                        .font(.system(size: 8, weight: .bold)).foregroundColor(amber)
                    Text(p.fullName.isEmpty ? "Membre du club" : p.fullName).font(.system(size: 19, weight: .bold))
                    Text(p.level.isEmpty ? "Niveau non renseigné" : p.level)
                        .font(.system(size: 11)).foregroundColor(Color(hex: 0xBAE6FD))
                }
                Spacer(minLength: 0)
            }.padding(.top, 18)

            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1).padding(.top, 16)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Matricule Officiel").font(.system(size: 9, weight: .bold)).foregroundColor(sky)
                    Text(p.matricule).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(amber)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Date d'inscription").font(.system(size: 9, weight: .bold)).foregroundColor(sky)
                    Text(Self.format(p.registrationDate)).font(.system(size: 13, weight: .bold))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.top, 12)

            if !p.poles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pôles Rejoints :").font(.system(size: 9, weight: .bold)).foregroundColor(sky)
                    FlowLayout(spacing: 6) {
                        ForEach(p.poles, id: \.self) { t in
                            Text(t).font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.white.opacity(0.15))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2)))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }.padding(.top, 12)
            }

            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1).padding(.top, 12)

            HStack {
                Text("ID : member-\(p.memberNumber)").font(.system(size: 9, design: .monospaced)).foregroundColor(sky)
                Spacer()
                Text("MANDAT 2026—2027").font(.system(size: 9, weight: .bold)).foregroundColor(sky)
            }.padding(.top, 10)
        }
        .foregroundColor(.white)
        .padding(18)
        .background(LinearGradient(colors: [Color(hex: 0x0C4A6E), Color(hex: 0x0F172A)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Écran Mon Profil
@MainActor
struct ProfileView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var request = LiveDocument()
    @State private var editing = false
    @State private var first = "", last = "", level = studyLevels[1]
    @State private var editPoles: Set<String> = []
    @State private var newPassword = ""
    @State private var message: String?
    @State private var showPassword = false
    @State private var confirmLogout = false

    private let sky = Color(hex: 0x7DD3FC)
    private let greenDark = Color(hex: 0x047857)

    /// Statut en direct de la demande (la réponse du bureau s'affiche sans rouvrir l'écran).
    private var liveStatus: String {
        (request.data?["status"] as? String) ?? (app.profile?.joinStatus ?? "")
    }

    var body: some View {
        let p = app.profile ?? UserProfile()
        let accepted = p.isBureau || liveStatus == "accepté"
        ScrollView {
            VStack(spacing: 14) {
                header(p)
                statusBanner(p, accepted: accepted)

                HStack {
                    Text("CARTE DE MEMBRE OFFICIELLE").font(.system(size: 10, weight: .bold)).foregroundColor(.textGray)
                    Spacer()
                    Text("ISSIK KEF").font(.system(size: 10, weight: .bold)).foregroundColor(.textBlue)
                }.padding(.top, 4)
                MemberCardView(p: p, accepted: accepted)

                HStack(spacing: 8) {
                    ShareLink(item: shareText(p), subject: Text("Mes coordonnées — FEEL ISSIK")) {
                        Text("↗  Partager mes coordonnées").font(.system(size: 13, weight: .bold))
                            .foregroundColor(.textDark).frame(maxWidth: .infinity).frame(height: 44)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primaryBlue))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    Button { printCard(p, accepted: accepted) } label: {
                        Image(systemName: "printer").foregroundColor(.textDark)
                            .frame(width: 44, height: 44).background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primaryBlue))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }.accessibilityLabel("Imprimer la carte de membre")
                }

                photoCard(p)
                dossier(p)
                if app.isBureau { bureauCard }

                if let message { Text(message).font(.callout).foregroundColor(.textBlue) }
                Button("🔑 Définir / changer mon mot de passe") { showPassword = true }
            }.padding(16)
        }
        .background(Color.pageBg)
        .onAppear { if let uid = app.myUid { request.start(app.db.collection("joinRequests").document(uid)) } }
        .onDisappear { request.stop() }
        .onChange(of: request.data?["status"] as? String) { st in
            guard let st else { return }
            if st == "refusé" && !app.isBureau {          // refusé en direct : accès fermé immédiatement
                app.refusedNotice = true
                app.logout()
            } else {
                Task { await app.loadProfile() }          // rafraîchit carte, bannière et dossier
            }
        }
        .alert("Se déconnecter ?", isPresented: $confirmLogout) {
            Button("Se déconnecter", role: .destructive) { app.logout() }
            Button("Annuler", role: .cancel) {}
        }
        .alert("Nouveau mot de passe", isPresented: $showPassword) {
            SecureField("6 caractères minimum", text: $newPassword)
            Button("Enregistrer") { Task {
                do { try await app.setMyPassword(newPassword); message = "Mot de passe enregistré ✔" }
                catch { message = app.errorText(error) }
                newPassword = "" } }
            Button("Annuler", role: .cancel) { newPassword = "" }
        }
    }

    // MARK: Bannière dégradée
    private func header(_ p: UserProfile) -> some View {
        let hasPhoto = !p.photo.isEmpty
        return VStack(alignment: .leading, spacing: 12) {
            Text(hasPhoto ? "🔒  PROFIL & PHOTO ENREGISTRÉS DE FAÇON PERMANENTE" : "🔒  PROFIL ENREGISTRÉ DE FAÇON PERMANENTE")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Color.white.opacity(0.2)).clipShape(Capsule())

            HStack(spacing: 14) {
                Group {
                    if let img = ImageUtil.decode(p.photo) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        ZStack { Color.white; Text(p.initials.isEmpty ? "?" : p.initials)
                            .font(.system(size: 24, weight: .bold)).foregroundColor(.textBlue) }
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white, lineWidth: 3))

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName()).font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                    Text("\(p.level.isEmpty ? "Niveau non renseigné" : p.level) · ISSIK Kef")
                        .font(.system(size: 12)).foregroundColor(Color(hex: 0xE0F2FE))
                    Text(p.isBureau ? "👑 MEMBRE DU BUREAU" : "🎓 MEMBRE DU CLUB")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Color.white.opacity(0.2)).clipShape(Capsule()).padding(.top, 4)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                PhotoPickerButton(maxSide: 400, onPicked: { savePhoto($0) }) {
                    Text("📷  Modifier ma photo").font(.system(size: 12, weight: .bold)).foregroundColor(.textBlue)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.white).clipShape(Capsule())
                }
                Button { confirmLogout = true } label: {
                    Text("↪  Changer de compte").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .overlay(Capsule().stroke(Color.white.opacity(0.4)))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0x0EA5E9), Color(hex: 0x6366F1)], startPoint: .leading, endPoint: .trailing))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: Bannière « adhésion validée » / statut / « Nous rejoindre »
    @ViewBuilder private func statusBanner(_ p: UserProfile, accepted: Bool) -> some View {
        if accepted {
            VStack(alignment: .leading, spacing: 8) {
                Text("ADHÉSION VALIDÉE & ACCEPTÉE PAR LE BUREAU").font(.system(size: 9, weight: .bold)).foregroundColor(greenDark)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color(hex: 0xECFDF5)).overlay(Capsule().stroke(Color.okGreen)).clipShape(Capsule())
                Text(p.isBureau ? "Bienvenue dans l'équipe du bureau FEEL ISSIK 👑" : "Bienvenue officiel(le) dans la famille FEEL ISSIK 🎉")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.textDark)
                Text(p.isBureau
                     ? "Votre compte dispose des droits du bureau pour le mandat universitaire 2026—2027."
                     : "Votre dossier d'adhésion a été examiné et officiellement accepté par le bureau exécutif. Votre matricule \(p.matricule) et votre photo sont enregistrés de façon permanente pour l'ensemble du mandat universitaire 2026—2027.")
                    .font(.system(size: 12)).foregroundColor(.textGray)
                Button { app.go = .chat } label: {
                    Text("💬  Ouvrir le Salon de Discussion").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 18).frame(height: 40).background(Color.okGreen).clipShape(Capsule())
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xECFDF5))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.okGreen))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else if !liveStatus.isEmpty {
            Text("Adhésion : \(joinStatusLabel(liveStatus))")
                .font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: 0x78350F))
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xFFFBEB))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Aucune demande d'adhésion envoyée.").font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: 0x78350F))
                Button("Nous rejoindre →") { app.go = .join }.font(.system(size: 13, weight: .bold))
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xFFFBEB))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: Photo permanente
    private func photoCard(_ p: UserProfile) -> some View {
        let hasPhoto = !p.photo.isEmpty
        return CardBox {
            HStack {
                Text("📷  Photo de Profil Permanente").font(.system(size: 13, weight: .bold)).foregroundColor(.textDark)
                Spacer()
                Text("Sauvegardée sur le serveur").font(.system(size: 9, weight: .bold)).foregroundColor(greenDark)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color(hex: 0xECFDF5)).overlay(Capsule().stroke(Color.okGreen)).clipShape(Capsule())
            }
            Text("Cette photo est attachée de manière permanente à votre compte. Elle apparaîtra sur votre carte de membre et dans les discussions du club.")
                .font(.system(size: 11)).foregroundColor(.textGray)
            PhotoPickerButton(maxSide: 400, onPicked: { savePhoto($0) }) {
                Text(hasPhoto ? "📷  Changer ou mettre à jour ma photo" : "📷  Ajouter ma photo")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(LinearGradient(colors: [Color.primaryBlue, Color(hex: 0x0284C7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }.padding(.top, 4)
            if hasPhoto {
                Button("Retirer la photo", role: .destructive) { removePhoto() }
                    .font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Dossier d'adhésion enregistré
    private func dossier(_ p: UserProfile) -> some View {
        CardBox {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("📄  Dossier d'Adhésion Enregistré").font(.system(size: 16, weight: .bold)).foregroundColor(.textDark)
                    Text("Ces informations sont stockées de façon permanente pour votre profil et le bureau.")
                        .font(.system(size: 10)).foregroundColor(.textGray)
                }
                Spacer(minLength: 8)
                Button {
                    if editing { editing = false } else {
                        first = p.firstName; last = p.lastName
                        level = studyLevels.contains(p.level) ? p.level : studyLevels[1]
                        editPoles = Set(p.poles); editing = true
                    }
                } label: {
                    Text(editing ? "✕ Fermer" : "✎ Modifier mes infos").font(.system(size: 11, weight: .bold)).foregroundColor(.textBlue)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.daySelected).overlay(Capsule().stroke(Color.cardBorder)).clipShape(Capsule())
                }
            }
            Divider().padding(.vertical, 4)

            HStack(alignment: .top, spacing: 8) {
                tile("👤  Nom & Prénom :", p.fullName.isEmpty ? "—" : p.fullName)
                tile("🎓  Niveau d'études à l'ISSIK :", p.level.isEmpty ? "—" : p.level)
            }.fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 8) {
                tile("✉  Adresse Email :", p.email == AppState.adminEmail ? "Identifiant : \(AppState.adminUser)" : (p.email.isEmpty ? "—" : p.email))
                tile("📞  Téléphone :", p.phone.isEmpty ? "—" : p.phone, valueColor: .textBlue)
            }.fixedSize(horizontal: false, vertical: true)

            if !p.poles.isEmpty {
                box {
                    Text("🗂  Pôles et Sous-Groupes sollicités :").font(.system(size: 10, weight: .bold)).foregroundColor(.textBlue)
                    FlowLayout(spacing: 6) {
                        ForEach(p.poles, id: \.self) { t in
                            Text(t).font(.system(size: 11, weight: .bold)).foregroundColor(.textBlue)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Color.white).overlay(Capsule().stroke(Color.primaryBlue)).clipShape(Capsule())
                        }
                    }
                }
            }
            if !p.passions.isEmpty {
                box {
                    Text("♡  Passions & Centres d'Intérêt :").font(.system(size: 10, weight: .bold)).foregroundColor(.textBlue)
                    Text(p.passions.joined(separator: " · ")).font(.system(size: 13, weight: .bold)).foregroundColor(.textDark)
                }
            }
            if !p.motivation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                box(fill: Color(hex: 0xF8FCFF)) {
                    Text("Motivation transmise au bureau :").font(.system(size: 10, weight: .bold)).foregroundColor(.textBlue)
                    Text("« \(p.motivation.trimmingCharacters(in: .whitespacesAndNewlines)) »")
                        .font(.system(size: 12)).italic().foregroundColor(.textGray)
                }
            }

            if editing { editForm }

            HStack(alignment: .top, spacing: 8) {
                Button { app.go = .chat } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("💬 Salon de Discussion").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        Text("Vos messages apparaîtront avec votre nom et photo").font(.system(size: 9)).foregroundColor(Color(hex: 0xE0F2FE))
                    }
                    .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(LinearGradient(colors: [Color.primaryBlue, Color(hex: 0x0284C7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Button { app.go = .team } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("👑 Organigramme du Bureau").font(.system(size: 12, weight: .bold)).foregroundColor(.textDark)
                        Text("Consulter les postes officiels et responsables").font(.system(size: 9)).foregroundColor(.textGray)
                    }
                    .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primaryBlue))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }.fixedSize(horizontal: false, vertical: true).padding(.top, 8)
        }
    }

    // MARK: Formulaire de modification (infos + pôles)
    private var editForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MODIFIER MES INFORMATIONS").font(.system(size: 12, weight: .bold)).foregroundColor(.textBlue)
            FormField(label: "Prénom", text: $first)
            FormField(label: "Nom de famille", text: $last)
            VStack(alignment: .leading, spacing: 4) {
                Text("Niveau d'études").font(.caption.bold()).foregroundColor(.textBlue)
                Picker("Niveau", selection: $level) { ForEach(studyLevels, id: \.self) { Text($0).tag($0) } }
                    .pickerStyle(.menu).tint(.textDark)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Pôles rejoints (touchez pour ajouter / retirer)").font(.caption.bold()).foregroundColor(.textBlue)
                FlowLayout(spacing: 6) {
                    ForEach(Poles.all) { pole in
                        let on = editPoles.contains(pole.title)
                        Button {
                            if on { editPoles.remove(pole.title) } else { editPoles.insert(pole.title) }
                        } label: {
                            Text("\(pole.icon) \(pole.title)").font(.system(size: 12, weight: .bold))
                                .foregroundColor(on ? .white : .textDark)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(on ? Color.primaryBlue : Color.daySelected)
                                .overlay(Capsule().stroke(Color.cardBorder))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            PrimaryButton(title: "Enregistrer") { Task { await saveInfo() } }.padding(.top, 4)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xF8FCFF))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cardBorder))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Espace Bureau (membres du bureau uniquement)
    private var bureauCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("👑 Espace Bureau").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
            Text("Modifiez le contenu de l'application et consultez la base de données.")
                .font(.system(size: 12)).foregroundColor(Color(hex: 0xCBD5E1))
            Button { app.bureauModeEnabled = true; app.go = .database } label: {
                Text("Ouvrir l'Espace Bureau").font(.system(size: 13, weight: .bold)).foregroundColor(.textDark)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(Color.orange).clipShape(RoundedRectangle(cornerRadius: 14))
            }.padding(.top, 6)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color.navy, Color(hex: 0x1E1B4B)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Petits composants
    private func tile(_ label: String, _ value: String, valueColor: Color = .textDark) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundColor(.textBlue)
            Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(valueColor)
                .lineLimit(3).minimumScaleFactor(0.85)
        }
        .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cardBorder))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func box<C: View>(fill: Color = .white, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) { content() }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cardBorder))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Partage / impression
    private func shareText(_ p: UserProfile) -> String {
        var lines = ["FEEL ISSIK — Carte de membre", p.fullName.isEmpty ? "Membre du club" : p.fullName]
        if !p.level.isEmpty { lines.append(p.level) }
        lines.append("Matricule : \(p.matricule)")
        if !p.email.isEmpty && p.email != AppState.adminEmail { lines.append("E-mail : \(p.email)") }
        if !p.phone.isEmpty { lines.append("Téléphone : \(p.phone)") }
        if !p.poles.isEmpty { lines.append("Pôles : " + p.poles.joined(separator: ", ")) }
        return lines.joined(separator: "\n")
    }

    /// Imprime (ou enregistre en PDF) la carte de membre, rendue en image.
    private func printCard(_ p: UserProfile, accepted: Bool) {
        let renderer = ImageRenderer(content:
            MemberCardView(p: p, accepted: accepted).frame(width: 380).padding(24).background(Color.white))
        renderer.scale = 3
        guard let image = renderer.uiImage else { message = "Impression impossible"; return }
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = "Carte de membre FEEL ISSIK"
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = image
        controller.present(animated: true, completionHandler: nil)
    }

    // MARK: Écritures
    private func savePhoto(_ b64: String) {
        guard let uid = app.myUid else { return }
        app.db.collection("users").document(uid).setData(["photo": b64], merge: true) { err in
            Task { @MainActor in
                if let err { message = app.errorText(err) } else { message = "Photo enregistrée ✔"; await app.loadProfile() }
            }
        }
    }
    private func removePhoto() {
        guard let uid = app.myUid else { return }
        app.db.collection("users").document(uid).updateData(["photo": FieldValue.delete()]) { _ in Task { @MainActor in await app.loadProfile() } }
    }
    private func saveInfo() async {
        guard let uid = app.myUid else { return }
        let f = first.trimmingCharacters(in: .whitespaces), l = last.trimmingCharacters(in: .whitespaces)
        if f.isEmpty || l.isEmpty { message = "Prénom et nom obligatoires"; return }
        let poles = Poles.all.map { $0.title }.filter { editPoles.contains($0) }
        do {
            try await app.db.collection("users").document(uid).setData(
                ["firstName": f, "lastName": l, "level": level, "poles": poles], merge: true)
            await app.loadProfile(); editing = false; message = "Profil mis à jour ✔"
        } catch { message = app.errorText(error) }
    }
}
