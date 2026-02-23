import XCTest
@testable import PantryPilot

final class ExpiryStatusTests: XCTestCase {

    func testFreshStatus() {
        let date = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        let status = ExpiryStatus(expiryDate: date)
        if case .fresh(let days) = status {
            XCTAssertEqual(days, 10)
        } else {
            XCTFail("Expected .fresh, got \(status)")
        }
        XCTAssertFalse(status.isExpired)
        XCTAssertFalse(status.isSoon)
        XCTAssertEqual(status.color, .secondary)
    }

    func testSoonStatus() {
        let date = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        let status = ExpiryStatus(expiryDate: date)
        if case .soon(let days) = status {
            XCTAssertEqual(days, 2)
        } else {
            XCTFail("Expected .soon, got \(status)")
        }
        XCTAssertTrue(status.isSoon)
        XCTAssertTrue(status.isUrgent)
    }

    func testExpiredStatus() {
        let date = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        let status = ExpiryStatus(expiryDate: date)
        if case .expired(let days) = status {
            XCTAssertEqual(days, 5)
        } else {
            XCTFail("Expected .expired, got \(status)")
        }
        XCTAssertTrue(status.isExpired)
        XCTAssertTrue(status.isUrgent)
        XCTAssertEqual(status.color, .red)
    }

    func testUnknownStatus() {
        let status = ExpiryStatus(expiryDate: nil)
        XCTAssertEqual(status, .unknown)
        XCTAssertFalse(status.isExpired)
        XCTAssertFalse(status.isSoon)
    }

    func testTodayExpiry() {
        let today = Calendar.current.startOfDay(for: .now)
        let status = ExpiryStatus(expiryDate: today)
        if case .soon(let days) = status {
            XCTAssertEqual(days, 0)
            XCTAssertEqual(status.label, "Heute")
        } else {
            XCTFail("Expected .soon(0), got \(status)")
        }
    }

    func testLabels() {
        XCTAssertEqual(ExpiryStatus.fresh(daysLeft: 7).label, "Noch 7 Tage")
        XCTAssertEqual(ExpiryStatus.soon(daysLeft: 1).label, "Morgen")
        XCTAssertEqual(ExpiryStatus.expired(daysPast: 3).label, "Seit 3 Tagen abgelaufen")
        XCTAssertEqual(ExpiryStatus.expired(daysPast: 1).label, "Seit 1 Tag abgelaufen")
    }

    func testShortLabels() {
        XCTAssertEqual(ExpiryStatus.fresh(daysLeft: 14).shortLabel, "Noch 14 Tage")
        XCTAssertEqual(ExpiryStatus.soon(daysLeft: 0).shortLabel, "Heute")
        XCTAssertEqual(ExpiryStatus.soon(daysLeft: 1).shortLabel, "Morgen")
        XCTAssertEqual(ExpiryStatus.soon(daysLeft: 3).shortLabel, "Noch 3 Tage")
        XCTAssertEqual(ExpiryStatus.expired(daysPast: 5).shortLabel, "Abgelaufen")
        XCTAssertEqual(ExpiryStatus.unknown.shortLabel, "")
    }
}
