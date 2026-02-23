import XCTest
@testable import PantryPilot

final class ExpiryEstimationServiceTests: XCTestCase {
    private var sut: ExpiryEstimationService!
    private let baseDate = Date(timeIntervalSince1970: 1_800_000_000) // fixed date

    override func setUp() {
        super.setUp()
        sut = ExpiryEstimationService()
    }

    func testDairyInFridgeUnopened() {
        let expiry = sut.estimateExpiry(category: .dairy, location: .fridge, opened: false, from: baseDate)
        let days = Calendar.current.dateComponents([.day], from: baseDate, to: expiry).day!
        XCTAssertEqual(days, 14)
    }

    func testDairyInFridgeOpened() {
        let expiry = sut.estimateExpiry(category: .dairy, location: .fridge, opened: true, from: baseDate)
        let days = Calendar.current.dateComponents([.day], from: baseDate, to: expiry).day!
        XCTAssertEqual(days, 5)
    }

    func testMeatInFreezerUnopened() {
        let expiry = sut.estimateExpiry(category: .meat, location: .freezer, opened: false, from: baseDate)
        let days = Calendar.current.dateComponents([.day], from: baseDate, to: expiry).day!
        XCTAssertEqual(days, 180)
    }

    func testCannedInPantryUnopened() {
        let expiry = sut.estimateExpiry(category: .canned, location: .pantry, opened: false, from: baseDate)
        let days = Calendar.current.dateComponents([.day], from: baseDate, to: expiry).day!
        XCTAssertEqual(days, 730)
    }

    func testOpenedReducesExpiry() {
        let unopened = sut.estimateExpiry(category: .dairy, location: .fridge, opened: false, from: baseDate)
        let opened = sut.estimateExpiry(category: .dairy, location: .fridge, opened: true, from: baseDate)
        XCTAssertTrue(opened < unopened)
    }

    func testDaysUntilExpiry() {
        let item = InventoryItem(
            canonicalName: "Test",
            estimatedExpiryDate: Calendar.current.date(byAdding: .day, value: 5, to: .now)
        )
        let days = sut.daysUntilExpiry(for: item)
        XCTAssertNotNil(days)
        XCTAssertTrue(days! >= 4 && days! <= 5)
    }

    func testNilExpiryReturnsNilDays() {
        let item = InventoryItem(canonicalName: "Test")
        XCTAssertNil(sut.daysUntilExpiry(for: item))
    }
}
