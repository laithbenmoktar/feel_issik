import SwiftUI

struct TeamView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var live = LiveCollection()
    @State private var editing: TeamPost?
    let openPole: (String) -> Void

    private var posts: [TeamPost] {
        TeamData.merge(Dictionary(uniqueKeysWithValues: live.docs.map { ($0.documentID, $0.data()) }))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if app.bureauActive { BureauBanner() }
                Text("Organigramme · mandat 2026—2027").font(.subheadline).foregroundColor(.textGray)
                ForEach(TeamData.sections.indices, id: \.self) { i in
                    let sec = TeamData.sections[i]
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(sec.icon) \(sec.title)").font(.title3.bold())
                        Text(sec.subtitle).font(.caption).foregroundColor(.textGray)
                    }.padding(.top, 8)
                    ForEach(posts.filter { $0.section == i }) { post in
                        CardBox {
                            HStack(spacing: 12) {
                                AvatarView(b64: post.photo, initials: String(post.name.split(separator: " ").compactMap { $0.first }.prefix(2)), size: 52)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(post.name).font(.headline)
                                    Text(post.role).font(.caption.bold()).foregroundColor(.textBlue)
                                    Text(post.level).font(.caption2).foregroundColor(.textGray)
                                }
                                Spacer()
                                if app.bureauActive { Button("✏") { editing = post } }
                            }
                            Text(post.description).font(.callout)
                            if !post.email.isEmpty, let u = URL(string: "mailto:\(post.email)") { Link("✉ \(post.email)", destination: u).font(.caption) }
                            if !post.phone.isEmpty, let u = URL(string: "tel:\(post.phone.filter { $0.isNumber || $0 == "+" })") { Link("📞 \(post.phone)", destination: u).font(.caption) }
                            if let pid = post.poleId { Button("Voir le pôle correspondant →") { openPole(pid) }.font(.caption.bold()) }
                        }
                    }
                }
            }.padding(16)
        }
        .background(Color.pageBg)
        .onAppear { live.start(app.db.collection("team")) }
        .onDisappear { live.stop() }
        .sheet(item: $editing) { TeamPostEditor(post: $0) }
    }
}
