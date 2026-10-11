import SwiftUI
import FirebaseFirestore

struct MoviesView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var live = LiveCollection()
    @State private var adding = false
    @State private var error: ErrorMessage?
    private var movies: [Movie] {
        live.docs.compactMap { Movie(id: $0.documentID, $0.data()) }.sorted { $0.votes > $1.votes }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if app.bureauActive { BureauBanner() }
                PrimaryButton(title: "➕ Proposer un film") { adding = true }
                if movies.isEmpty { EmptyState(icon: "🎬", text: "Aucune suggestion pour l'instant.\nSoyez le premier à proposer un film !") }
                ForEach(movies) { m in card(m) }
            }.padding(16)
        }
        .background(Color.pageBg)
        .onAppear { live.start(app.db.collection("movies")) }
        .onDisappear { live.stop() }
        .sheet(isPresented: $adding) { MovieEditor() }
        .alert(item: $error) { Alert(title: Text($0.title), message: Text($0.body)) }
    }

    private func card(_ m: Movie) -> some View {
        let voted = app.myUid.map { m.voters.contains($0) } ?? false
        return CardBox {
            HStack(alignment: .top, spacing: 12) {
                if m.poster != nil { Base64Image(b64: m.poster, fallback: "film").frame(width: 70, height: 100).clipShape(RoundedRectangle(cornerRadius: 8)) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.title).font(.headline)
                    Text("\(m.director) · \(m.year) · \(m.genre)").font(.caption).foregroundColor(.textBlue)
                    Text(m.synopsis).font(.callout).foregroundColor(.textGray)
                    Text("Proposé par \(m.author)").font(.caption2).foregroundColor(.textGray)
                    if !m.link.isEmpty, let u = URL(string: m.link) { Link("🔗 Lien", destination: u).font(.caption) }
                }
            }
            HStack {
                Button { vote(m, voted) } label: { Text("\(voted ? "❤️" : "🤍") \(m.votes)").font(.callout.bold()) }
                    .buttonStyle(.bordered).disabled(!app.isLoggedIn)
                Spacer()
                if app.bureauActive {
                    PhotoPickerButton(maxSide: 500, onPicked: { b64 in
                        app.db.collection("movies").document(m.id).updateData(["poster": b64])
                    }) { Text("🖼 Affiche").font(.caption.bold()) }
                    if m.poster != nil { Button("Retirer l'affiche") { app.db.collection("movies").document(m.id).updateData(["poster": FieldValue.delete()]) }.font(.caption) }
                }
                if app.bureauActive || m.ownerUid == app.myUid { Button("🗑", role: .destructive) { delete(m) } }
            }
        }
    }

    private func vote(_ m: Movie, _ voted: Bool) {
        guard let uid = app.myUid else { return }
        let op: Any = voted ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid])
        app.db.collection("movies").document(m.id).updateData(["voters": op]) { err in
            if let err { error = ErrorMessage(title: "Vote impossible", body: app.errorText(err)) }
        }
    }
    private func delete(_ m: Movie) {
        app.db.collection("movies").document(m.id).delete { err in
            if let err { error = ErrorMessage(title: "Suppression impossible", body: app.errorText(err)) }
        }
    }
}

struct MovieEditor: View {
    @EnvironmentObject var app: AppState
    @State private var title = "", director = "", synopsis = "", author = "", link = ""
    @State private var year = 2024
    @State private var genre = "Drame / Inspirant"
    private let genres = ["Drame / Inspirant", "Drame / Musique", "Drame / Éducation", "Comédie",
                          "Science-Fiction / Aventure", "Thriller", "Animation", "Documentaire", "Romance"]
    var body: some View {
        EditorSheet(title: "Proposer un film", save: {
            guard let uid = app.myUid else { throw AppError("Connexion requise") }
            if title.trimmingCharacters(in: .whitespaces).isEmpty { throw AppError("Le titre est obligatoire") }
            let a = author.trimmingCharacters(in: .whitespaces)
            try await app.db.collection("movies").addDocument(data: [
                "title": title.trimmingCharacters(in: .whitespaces), "director": director, "year": year, "genre": genre,
                "synopsis": synopsis, "author": a.isEmpty ? app.displayName() : a, "uid": uid, "voters": [String](),
                "link": link, "createdAt": FieldValue.serverTimestamp()])
        }) {
            FormField(label: "Titre *", text: $title)
            FormField(label: "Réalisateur", text: $director)
            Picker("Année", selection: $year) { ForEach((1950...2026).reversed(), id: \.self) { Text(String($0)).tag($0) } }.pickerStyle(.menu)
            Picker("Genre", selection: $genre) { ForEach(genres, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
            FormField(label: "Synopsis", text: $synopsis, multiline: true)
            FormField(label: "Votre nom (facultatif)", text: $author)
            FormField(label: "Lien", text: $link, keyboard: .URL)
        }
    }
}
