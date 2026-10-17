import XCTest
import CryptoKit
@testable import Laith

final class LaithTests: XCTestCase {

    /// Le mot de passe dérivé de l'e-mail doit être IDENTIQUE à celui d'Android (Repo.kt),
    /// sinon un compte créé sur un système ne pourrait pas se connecter sur l'autre.
    func testEmailOnlyPasswordMatchesAndroid() {
        let src = "feel-issik|test@issik.rnu.tn|membre"
        let hex = SHA256.hash(data: Data(src.utf8)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual("FI-" + hex.prefix(28), "FI-c626a65d6f2d150c28de43c46350")
    }

    func testJoinStatusLabels() {
        XCTAssertEqual(joinStatusLabel("accepté"), "adhésion acceptée 🎉")
        XCTAssertTrue(joinStatusLabel("nouveau").contains("en attente"))
    }

    func testTeamMergeKeepsDefaultsAndAppliesOverrides() {
        let merged = TeamData.merge(["president": ["name": "Nouveau Nom", "email": ""]])
        XCTAssertEqual(merged.count, TeamData.defaults.count)
        XCTAssertEqual(merged.first { $0.id == "president" }?.name, "Nouveau Nom")
        XCTAssertEqual(merged.first { $0.id == "secretaire" }?.name, "Amine Khelifi")
    }

    func testProfileInitialsAndRole() {
        var p = UserProfile(); p.firstName = "Yasmine"; p.lastName = "Ben Amor"; p.role = "bureau"
        XCTAssertEqual(p.initials, "YB")
        XCTAssertTrue(p.isBureau)
    }

    func testAllPolesHaveUniqueIds() {
        XCTAssertEqual(Set(Poles.all.map { $0.id }).count, Poles.all.count)
    }

    /// Le matricule doit être IDENTIQUE à celui d'Android (UserProfile.memberNumber dans Repo.kt).
    /// "abc".hashCode() = 96354 en Java/Kotlin → 96354 % 9000 + 1000 = 7354.
    func testMatriculeMatchesAndroid() {
        var p = UserProfile(); p.uid = "abc"
        XCTAssertEqual(p.memberNumber, "7354")
        XCTAssertEqual(p.matricule, "FI-26-7354")
    }
}
