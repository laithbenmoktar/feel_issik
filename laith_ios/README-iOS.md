# FEEL ISSIK – version iOS (SwiftUI + Firebase)

Portage iOS de l'application Android `laith_v6` (v1.7). Le projet Android n'est **pas modifié** :
l'application iOS utilise le **même projet Firebase `feelissik`** (mêmes comptes, mêmes données Firestore,
mêmes `firestore.rules`). Un compte créé sur Android fonctionne sur iPhone et inversement.

## Pré-requis
- Un Mac avec **Xcode 15+** (la compilation iOS n'est pas possible sous Windows/Linux).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) : `brew install xcodegen`

## Mise en route
1. **Firebase** : console Firebase → projet `feelissik` → *Ajouter une application* → **iOS**,
   identifiant de bundle **`isetb.tp1.laith`** → télécharger `GoogleService-Info.plist`
   et le copier dans `Laith/` (à côté de `LaithApp.swift`).
   (Le `google-services.json` d'Android ne peut pas servir sur iOS.)
2. Dans ce dossier : `xcodegen generate` → crée `Laith.xcodeproj` (le SDK Firebase est ajouté via Swift Package Manager).
3. Ouvrir `Laith.xcodeproj`, choisir *Signing & Capabilities → Team* (compte Apple, gratuit pour tester sur son iPhone), puis ▶︎.

## Équivalences Android → iOS
| Android | iOS |
|---|---|
| `Repo.kt`, `BureauMode.kt` | `Core/AppState.swift` |
| `Movie.kt`, `TeamData.kt`, `Poles.kt`, `Participants.kt` | `Core/Models.swift` |
| `ImageUtil.kt` | `Core/ImageUtil.swift` |
| `LoginActivity` | `Views/LoginView.swift` |
| `MainActivity` + `HamburgerMenu` | `Views/HomeView.swift` + `Views/MainShell.swift` (menu ☰) |
| `EventsActivity` | `Views/EventsView.swift` |
| `TeamActivity` | `Views/TeamView.swift` |
| `JoinActivity` | `Views/JoinView.swift` |
| `ProfileActivity` | `Views/ProfileView.swift` |
| `ChatActivity` | `Views/ChatView.swift` |
| `MovieDialogFragment` | `Views/MoviesView.swift` |
| `RejoignantsActivity` | `Views/RejoignantsView.swift` |
| `BureauActivity`, `BureauEditors` | `Views/DatabaseView.swift`, `Views/BureauEditors.swift` |

Logique conservée : connexion par e-mail seul (même dérivation de mot de passe qu'Android), compte `admin`,
membre refusé = déconnecté, une seule demande par membre (`joinRequests/<uid>`, recopiée dans `users/<uid>`),
mode Bureau global (boutons ✏), participants fusionnés, Accepter/Refuser en écriture groupée, export CSV.

## Finitions « professionnelles »
- Logo et icône d'application du club (repris d'Android) dans `Assets.xcassets`, affichés à la connexion, à l'accueil et dans le menu.
- Thème clair fixe (comme Android), cartes ombrées, états vides, libellés d'accessibilité (VoiceOver).
- Tests unitaires (`LaithTests`) : dont la compatibilité du mot de passe dérivé de l'e-mail avec Android. Lancer : ⌘U.

## Non repris dans cette version (à prévoir)
- **Notifications** (FCM/APNs, `AlertsWorker`, `LiveAlerts`) : sur iOS elles demandent un compte Apple Developer payant
  et une clé APNs ; elles n'ont pas été portées.
- Prise de photo avec l'appareil (seule la galerie est proposée).

⚠ Ce code a été écrit sans Xcode : il n'a pas encore été compilé. Au premier build, de petites corrections
de syntaxe peuvent être nécessaires.

## Sécurité (à régler avant de remettre le projet)
Le compte `admin` / `2026` est écrit dans le code (Android et iOS) : après la 1re connexion, changez son mot de passe dans Firebase → Authentication, et ne le laissez pas dans les documents remis.
