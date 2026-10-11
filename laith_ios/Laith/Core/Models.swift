import SwiftUI
import FirebaseFirestore

// MARK: - Thème (mêmes couleurs que res/values/colors.xml)
extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
    static let primaryBlue = Color(hex: 0x0EA5E9)
    static let pageBg = Color(hex: 0xF0F9FF)
    static let cardBorder = Color(hex: 0xBAE6FD)
    static let textDark = Color(hex: 0x0F172A)
    static let textBlue = Color(hex: 0x0369A1)
    static let textGray = Color(hex: 0x475569)
    static let daySelected = Color(hex: 0xE0F2FE)
    static let okGreen = Color(hex: 0x10B981)
    static let danger = Color(hex: 0xEF4444)
    static let orange = Color(hex: 0xF59E0B)
    static let navy = Color(hex: 0x0F172A)
}

// MARK: - Profil
struct UserProfile {
    var uid = ""
    var firstName = ""
    var lastName = ""
    var email = ""
    var level = ""
    var role = "member"
    var phone = ""
    var poles: [String] = []
    var passions: [String] = []
    var motivation = ""
    var photo = ""
    var joinStatus = ""

    var isBureau: Bool { role == "bureau" }
    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var initials: String { (firstName.prefix(1) + lastName.prefix(1)).uppercased() }

    init() {}
    init(uid: String, data d: [String: Any]) {
        self.uid = uid
        firstName = d["firstName"] as? String ?? ""
        lastName = d["lastName"] as? String ?? ""
        email = d["email"] as? String ?? ""
        level = d["level"] as? String ?? ""
        role = d["role"] as? String ?? "member"
        phone = d["phone"] as? String ?? ""
        poles = d["poles"] as? [String] ?? []
        passions = d["passions"] as? [String] ?? []
        motivation = d["motivation"] as? String ?? ""
        photo = d["photo"] as? String ?? ""
        joinStatus = d["joinStatus"] as? String ?? ""
    }
}

// MARK: - Pôles
struct Pole: Identifiable {
    let id: String, title: String, shortName: String, icon: String, description: String, projects: Int
}

enum Poles {
    static let all: [Pole] = [
        Pole(id: "ecriture", title: "Écriture & Création Littéraire", shortName: "Écriture & Création Littéraire", icon: "🪶",
             description: "Donnez vie à vos récits et inspirations : ateliers d'écriture créative, poésie vivante, slam et publication collective du club.", projects: 1),
        Pole(id: "musique", title: "Musique", shortName: "Musique", icon: "🎵",
             description: "Une communauté vibrante d'instrumentistes, chanteurs et passionnés de mixage qui partagent la scène et le studio.", projects: 1),
        Pole(id: "cinema", title: "Cinéma & Théâtre", shortName: "Cinéma & Théâtre", icon: "🎬",
             description: "De l'écriture du scénario aux planches de la scène universitaire : vivez la magie du 7ème art et du spectacle vivant.", projects: 0),
        Pole(id: "peinture", title: "Peinture & Arts Visuels", shortName: "Peinture", icon: "🎨",
             description: "Exprimez votre univers plastique à travers la couleur, le geste pictural et les expositions au cœur de l'institut.", projects: 1),
        Pole(id: "crochet", title: "Crochet & DIY Créatif", shortName: "Crochet", icon: "✂️",
             description: "Détente méditative, mailles serrées et créations faites-main : mode durable, accessoires et peluches uniques.", projects: 0),
        Pole(id: "football", title: "Football & Esprit Sportif", shortName: "Football", icon: "🏆",
             description: "La passion du ballon rond, du beau jeu collectif et de la bonne humeur sur le terrain synthétique du campus.", projects: 1),
    ]
}

let studyLevels = [
    "1ère Année Licence Sciences Infirmières",
    "2ème Année Licence Sciences Infirmières",
    "3ème Année Licence Sciences Infirmières",
    "Master",
]

let passionChoices = [
    "Musique & Chant", "Guitare & Instruments", "Cinéma & Séries", "Théâtre & Improvisation",
    "Peinture & Dessin", "Crochet & Tricot", "Football & Futsal", "Photographie",
    "Écriture créative", "Gaming & E-sport", "Randonnée & Nature",
]

func joinStatusLabel(_ s: String) -> String {
    switch s {
    case "nouveau": return "demande envoyée, en attente de réponse du bureau"
    case "contacté": return "le bureau vous a contacté"
    case "accepté": return "adhésion acceptée 🎉"
    case "refusé": return "demande refusée (contactez le bureau)"
    default: return s
    }
}

// MARK: - Organigramme
struct TeamPost: Identifiable {
    let id: String
    let section: Int
    var role: String
    var name: String
    var level: String
    var description: String
    var email = ""
    var phone = ""
    var poleId: String? = nil
    var photo: String? = nil
}

enum TeamData {
    static let sections: [(icon: String, title: String, subtitle: String)] = [
        ("👑", "Bureau Exécutif & Présidence", "Gouvernance, représentation et coordination générale du club"),
        ("🧭", "Responsables de Pôles & Ateliers", "Animation pédagogique, ateliers pratiques et projets créatifs"),
        ("💼", "Pôle Médias, Logistique & Événements", "Couverture médiatique, communication visuelle et organisation logistique"),
    ]
    private static let l1 = "1ère Année Licence Sciences Infirmières"
    private static let l2 = "2ème Année Licence Sciences Infirmières"
    private static let l3 = "3ème Année Licence Sciences Infirmières"

    static let defaults: [TeamPost] = [
        TeamPost(id: "president", section: 0, role: "Président du Club FEEL ISSIK", name: "Mouwafek Suibgui", level: l3,
                 description: "Direction générale, animation de la vie associative et coordination officielle avec l'ISSIK Kef.",
                 email: "president@feelissik.tn", phone: "+216 55 120 450"),
        TeamPost(id: "vice-presidente", section: 0, role: "Vice-Présidente", name: "Sarra Trabelsi", level: l2,
                 description: "Coordination générale des pôles artistiques et sportifs, gestion des partenariats universitaires.",
                 email: "vicepres@feelissik.tn", phone: "+216 54 330 210"),
        TeamPost(id: "secretaire", section: 0, role: "Secrétaire Général", name: "Amine Khelifi", level: l2,
                 description: "Gestion des adhésions officielles, validation des dossiers et rédaction des procès-verbaux.",
                 email: "secretariat@feelissik.tn", phone: "+216 98 441 552"),
        TeamPost(id: "tresoriere", section: 0, role: "Trésorière Générale", name: "Nour Elhouda Mejri", level: l3,
                 description: "Tenue des comptes du club, budget des événements et logistique matérielle des activités."),
        TeamPost(id: "resp-ecriture", section: 1, role: "Responsable Pôle Écriture & Littérature", name: "Rayen Khemiri", level: l1,
                 description: "Animation des joutes d'écriture, ateliers slam, poésie et publication de la fanzine de l'ISSIK.",
                 email: "ecriture@feelissik.tn", poleId: "ecriture"),
        TeamPost(id: "resp-musique", section: 1, role: "Responsable Pôle Musique & Son", name: "Yassine Mansouri", level: l2,
                 description: "Organisation des répétitions live, sessions acoustiques et du groupe musical du campus.",
                 email: "musique@feelissik.tn", poleId: "musique"),
        TeamPost(id: "resp-cinema", section: 1, role: "Responsable Pôle Cinéma & Théâtre", name: "Selim Ben Ahmed", level: l2,
                 description: "Mise en scène des pièces annuelles, ciné-club hebdomadaire et improvisation scénique.",
                 email: "theatre@feelissik.tn", poleId: "cinema"),
        TeamPost(id: "resp-peinture", section: 1, role: "Responsable Pôle Peinture & Arts Visuels", name: "Amina Dridi", level: l3,
                 description: "Réalisation des fresques murales du campus, ateliers peinture et expositions des toiles.",
                 email: "arts@feelissik.tn", poleId: "peinture"),
        TeamPost(id: "resp-crochet", section: 1, role: "Responsable Pôle Crochet & DIY", name: "Mariem Gharbi", level: l1,
                 description: "Initiation aux mailles en l'air, confection d'amigurumis et projets solidaires faits main.",
                 email: "crochet@feelissik.tn", poleId: "crochet"),
        TeamPost(id: "resp-football", section: 1, role: "Responsable Pôle Football & Sports", name: "Karim Trabelsi", level: l2,
                 description: "Organisation des entraînements hebdomadaires, tournois inter-promos et esprit d'équipe.",
                 email: "sport@feelissik.tn", poleId: "football"),
        TeamPost(id: "resp-medias", section: 2, role: "Responsable Médias & Communication", name: "Eya Bouazizi", level: l2,
                 description: "Création graphique, affiches officielles, couverture photo des événements et réseaux sociaux.",
                 email: "com@feelissik.tn"),
        TeamPost(id: "resp-logistique", section: 2, role: "Responsable Logistique & Événements", name: "Hamza Riahi", level: l3,
                 description: "Réservation des amphithéâtres, sonorisation, gestion des badges et organisation des scènes.",
                 email: "logistique@feelissik.tn"),
    ]

    /// Valeurs par défaut + modifications du bureau (collection « team »).
    static func merge(_ overrides: [String: [String: Any]]) -> [TeamPost] {
        defaults.map { p in
            guard let d = overrides[p.id] else { return p }
            func s(_ k: String, _ fb: String) -> String {
                if let v = d[k] as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty { return v }
                return fb
            }
            var q = p
            q.name = s("name", p.name); q.level = s("level", p.level); q.description = s("description", p.description)
            q.email = d["email"] as? String ?? p.email
            q.phone = d["phone"] as? String ?? p.phone
            q.photo = d["photo"] as? String
            return q
        }
    }
}

// MARK: - Événements, actualités, films, messages
struct EventItem: Identifiable {
    let id: String, title: String, description: String, date: Date, time: String, place: String, group: String
    init?(id: String, _ d: [String: Any]) {
        guard let title = d["title"] as? String, let ds = d["date"] as? String,
              let date = DateFmt.iso.date(from: ds) else { return nil }
        self.id = id; self.title = title; self.date = date
        description = d["description"] as? String ?? ""
        time = d["time"] as? String ?? ""
        place = d["place"] as? String ?? ""
        group = d["group"] as? String ?? "Tous"
    }
}

struct NewsItem: Identifiable {
    let id: String, title: String, body: String, ts: Int64
    init?(id: String, _ d: [String: Any]) {
        guard let title = d["title"] as? String else { return nil }
        self.id = id; self.title = title
        body = d["body"] as? String ?? ""
        ts = (d["ts"] as? NSNumber)?.int64Value ?? 0
    }
}

struct Movie: Identifiable {
    let id: String, title: String, director: String, year: Int, genre: String, synopsis: String
    let author: String, ownerUid: String, voters: [String], link: String, poster: String?
    var votes: Int { voters.count }
    init?(id: String, _ d: [String: Any]) {
        guard let title = d["title"] as? String else { return nil }
        self.id = id; self.title = title
        director = d["director"] as? String ?? ""
        year = (d["year"] as? NSNumber)?.intValue ?? 2024
        genre = d["genre"] as? String ?? ""
        synopsis = d["synopsis"] as? String ?? ""
        author = d["author"] as? String ?? "Anonyme"
        ownerUid = d["uid"] as? String ?? ""
        voters = d["voters"] as? [String] ?? []
        link = d["link"] as? String ?? ""
        poster = d["poster"] as? String
    }
}

struct ChatMessage: Identifiable {
    let id: String, uid: String, author: String, text: String, ts: Int64, image: String?
    init?(id: String, _ d: [String: Any]) {
        guard let ts = (d["ts"] as? NSNumber)?.int64Value else { return nil }
        self.id = id; self.ts = ts
        uid = d["uid"] as? String ?? ""
        author = d["author"] as? String ?? "Membre"
        text = d["text"] as? String ?? ""
        image = d["image"] as? String
    }
}

enum DateFmt {
    /// yyyy-MM-dd, identique à LocalDate.toString() côté Android.
    static let iso: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
    static let long: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .long; f.locale = Locale(identifier: "fr_FR"); return f
    }()
    static let month: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"; f.locale = Locale(identifier: "fr_FR"); return f
    }()
}

// MARK: - Participants (fusion users + joinRequests, comme Participants.kt)
struct Participant: Identifiable {
    enum Kind: Int {
        case bureau, member, pending, refused, noRequest
        var icon: String { ["👑", "✅", "🕓", "⛔", "👤"][rawValue] }
        var label: String { ["Bureau", "Membre accepté", "En attente", "Refusé", "Compte sans demande"][rawValue] }
    }
    var id: String { ref.path }
    let ref: DocumentReference
    let isRequestDoc: Bool
    let uid: String, firstName: String, lastName: String, email: String, phone: String, level: String, role: String
    let poles: [String], passions: [String], motivation: String, status: String, hasAccount: Bool

    var fullName: String {
        let n = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? (email.isEmpty ? "(sans nom)" : email) : n
    }
    var kind: Kind {
        if role == "bureau" { return .bureau }
        if status == "accepté" { return .member }
        if status == "refusé" { return .refused }
        if !status.isEmpty { return .pending }
        return .noRequest
    }

    static func build(users: [QueryDocumentSnapshot], requests: [QueryDocumentSnapshot]) -> [Participant] {
        func str(_ d: [String: Any]?, _ k: String) -> String { d?[k] as? String ?? "" }
        func arr(_ d: [String: Any]?, _ k: String) -> [String] { d?[k] as? [String] ?? [] }
        let userIds = Set(users.map { $0.documentID })
        var reqByUid: [String: QueryDocumentSnapshot] = [:]
        var linked = Set<String>()
        for r in requests {
            let u = str(r.data(), "uid")
            if userIds.contains(u) { reqByUid[u] = r; linked.insert(r.documentID) }
        }
        func merge(_ u: QueryDocumentSnapshot?, _ r: QueryDocumentSnapshot?) -> Participant {
            let ud = u?.data(), rd = r?.data()
            func pick(_ k: String, preferRequest: Bool = false) -> String {
                let a = str(ud, k), b = str(rd, k)
                return preferRequest ? (b.isEmpty ? a : b) : (a.isEmpty ? b : a)
            }
            let reqPoles = arr(rd, "poles"), reqPass = arr(rd, "passions")
            let roleRaw = str(ud, "role")
            var status = str(ud, "joinStatus")
            if rd != nil { status = str(rd, "status").isEmpty ? "nouveau" : str(rd, "status") }
            return Participant(
                ref: (r ?? u)!.reference, isRequestDoc: r != nil,
                uid: u?.documentID ?? str(rd, "uid"),
                firstName: pick("firstName"), lastName: pick("lastName"), email: pick("email"),
                phone: pick("phone", preferRequest: true), level: pick("level"),
                role: roleRaw.isEmpty ? "member" : roleRaw,
                poles: reqPoles.isEmpty ? arr(ud, "poles") : reqPoles,
                passions: reqPass.isEmpty ? arr(ud, "passions") : reqPass,
                motivation: pick("motivation", preferRequest: true),
                status: status, hasAccount: u != nil)
        }
        var out = users.map { merge($0, reqByUid[$0.documentID]) }
        out += requests.filter { !linked.contains($0.documentID) }.map { merge(nil, $0) }
        return out.sorted {
            if $0.kind.rawValue != $1.kind.rawValue { return $0.kind.rawValue < $1.kind.rawValue }
            return $0.fullName.lowercased() < $1.fullName.lowercased()
        }
    }

    static func csv(_ list: [Participant]) -> String {
        func q(_ s: String) -> String {
            let safe = (s.first.map { "=+-@".contains($0) } ?? false) ? "'" + s : s
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: " ") + "\""
        }
        var out = "Prénom;Nom;Email;Téléphone;Niveau;Type;Statut;Pôles;Passions;Motivation;Compte\n"
        for p in list {
            out += [p.firstName, p.lastName, p.email, p.phone, p.level, p.kind.label, p.status,
                    p.poles.joined(separator: " | "), p.passions.joined(separator: " | "), p.motivation,
                    p.hasAccount ? "oui" : "non"].map(q).joined(separator: ";") + "\n"
        }
        return out
    }
}
