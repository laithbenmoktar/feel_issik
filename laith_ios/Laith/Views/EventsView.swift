import SwiftUI
import FirebaseFirestore

struct EventsView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var eventsLive = LiveCollection()
    @StateObject private var newsLive = LiveCollection()
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var selected: Date? = nil
    @State private var group = "Tous les sous-groupes"
    @State private var editEvent: EventItem?
    @State private var newEvent = false
    @State private var editNews: NewsItem?
    @State private var newNews = false
    @State private var error: ErrorMessage?
    private let groups = ["Tous les sous-groupes"] + Poles.all.map { $0.shortName }
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.firstWeekday = 2; c.locale = Locale(identifier: "fr_FR"); return c }

    private var events: [EventItem] {
        eventsLive.docs.compactMap { EventItem(id: $0.documentID, $0.data()) }
            .filter { group == groups[0] || $0.group == group || $0.group == "Tous" }
            .sorted { ($0.date, $0.time) < ($1.date, $1.time) }
    }
    private var news: [NewsItem] { newsLive.docs.compactMap { NewsItem(id: $0.documentID, $0.data()) }.sorted { $0.ts > $1.ts } }

    private var shown: [EventItem] {
        if let s = selected { return events.filter { cal.isDate($0.date, inSameDayAs: s) } }
        return events.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if app.bureauActive { BureauBanner() }
                Picker("Sous-groupe", selection: $group) { ForEach(groups, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                calendar
                HStack {
                    Text(selected.map { "Activités du \(DateFmt.long.string(from: $0))" } ?? "Activités du mois").font(.headline)
                    Spacer()
                    if app.bureauActive { Button("➕ Événement") { newEvent = true } }
                }
                if shown.isEmpty {
                    EmptyState(icon: "📅", text: selected.map { "Aucun événement le \(DateFmt.long.string(from: $0))" } ?? "Aucun événement ce mois-ci")
                }
                ForEach(shown) { eventCard($0) }

                HStack {
                    Text("📰 Actualités").font(.headline)
                    Spacer()
                    if app.bureauActive { Button("➕ Actualité") { newNews = true } }
                }.padding(.top, 8)
                ForEach(news) { newsCard($0) }
            }.padding(16)
        }
        .background(Color.pageBg)
        .onAppear { eventsLive.start(app.db.collection("events")); newsLive.start(app.db.collection("news")) }
        .onDisappear { eventsLive.stop(); newsLive.stop() }
        .sheet(isPresented: $newEvent) { EventEditor(existing: nil) }
        .sheet(item: $editEvent) { EventEditor(existing: $0) }
        .sheet(isPresented: $newNews) { NewsEditor(existing: nil) }
        .sheet(item: $editNews) { NewsEditor(existing: $0) }
        .alert(item: $error) { Alert(title: Text($0.title), message: Text($0.body)) }
    }

    private var calendar: some View {
        let first = month
        let days = cal.range(of: .day, in: .month, for: first)!.count
        let offset = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return CardBox {
            HStack {
                Button { month = cal.date(byAdding: .month, value: -1, to: month)!; selected = nil } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(DateFmt.month.string(from: month).capitalized).font(.headline)
                Spacer()
                Button { month = cal.date(byAdding: .month, value: 1, to: month)!; selected = nil } label: { Image(systemName: "chevron.right") }
            }
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(["L", "M", "M", "J", "V", "S", "D"].indices, id: \.self) { i in
                    Text(["L", "M", "M", "J", "V", "S", "D"][i]).font(.caption.bold()).foregroundColor(.textBlue)
                }
                ForEach(0..<(offset + days), id: \.self) { i in
                    if i < offset { Color.clear.frame(height: 38) }
                    else {
                        let date = cal.date(byAdding: .day, value: i - offset, to: first)!
                        let has = events.contains { cal.isDate($0.date, inSameDayAs: date) }
                        let sel = selected.map { cal.isDate($0, inSameDayAs: date) } ?? false
                        Button { selected = sel ? nil : date } label: {
                            VStack(spacing: 2) {
                                Text("\(i - offset + 1)").font(.callout).foregroundColor(sel ? .white : .textDark)
                                Circle().fill(has ? (sel ? Color.white : Color.orange) : Color.clear).frame(width: 5, height: 5)
                            }
                            .frame(maxWidth: .infinity).frame(height: 38)
                            .background(sel ? Color.primaryBlue : (has ? Color.daySelected : Color.white))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    private func eventCard(_ e: EventItem) -> some View {
        CardBox {
            HStack {
                Text(e.title).font(.headline)
                Spacer()
                if app.bureauActive {
                    Button("✏") { editEvent = e }
                    Button("🗑") { delete("events", e.id) }
                }
            }
            Text("📅 \(DateFmt.long.string(from: e.date))" + (e.time.isEmpty ? "" : " · \(e.time)")).font(.caption).foregroundColor(.textBlue)
            if !e.place.isEmpty { Text("📍 \(e.place)").font(.caption).foregroundColor(.textGray) }
            Text("🏷 \(e.group)").font(.caption).foregroundColor(.textGray)
            if !e.description.isEmpty { Text(e.description).font(.callout) }
        }
    }

    private func newsCard(_ n: NewsItem) -> some View {
        CardBox {
            HStack {
                Text(n.title).font(.headline)
                Spacer()
                if app.bureauActive {
                    Button("✏") { editNews = n }
                    Button("🗑") { delete("news", n.id) }
                }
            }
            if !n.body.isEmpty { Text(n.body).font(.callout).foregroundColor(.textGray) }
        }
    }

    private func delete(_ col: String, _ id: String) {
        app.db.collection(col).document(id).delete { err in
            if let err { error = ErrorMessage(title: "Suppression impossible", body: app.errorText(err)) }
        }
    }
}
