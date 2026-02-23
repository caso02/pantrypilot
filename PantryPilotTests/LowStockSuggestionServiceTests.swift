import XCTest
@testable import PantryPilot

final class LowStockSuggestionServiceTests: XCTestCase {
    private var sut: LowStockSuggestionService!

    override func setUp() {
        super.setUp()
        sut = LowStockSuggestionService()
    }

    func testEmptyInventorySuggestsStaples() {
        let suggestions = sut.suggestions(for: [])
        XCTAssertFalse(suggestions.isEmpty, "Should suggest staples when inventory is empty")
    }

    func testWellStockedItemNotSuggested() {
        let items = [
            InventoryItem(canonicalName: "Milch", quantity: 5, unit: "L", location: .fridge)
        ]
        let suggestions = sut.suggestions(for: items)
        XCTAssertFalse(suggestions.contains { $0.name.lowercased() == "milch" })
    }

    func testLowStockItemSuggested() {
        let items = [
            InventoryItem(canonicalName: "Milch", quantity: 0.5, unit: "L", location: .fridge)
        ]
        let suggestions = sut.suggestions(for: items)
        XCTAssertTrue(suggestions.contains { $0.name.lowercased() == "milch" })
    }

    func testExpiringSoonItemSuggested() {
        let items = [
            InventoryItem(
                canonicalName: "Spezialprodukt",
                quantity: 1, unit: "Stk",
                location: .fridge,
                estimatedExpiryDate: Calendar.current.date(byAdding: .hour, value: 12, to: .now)
            )
        ]
        let suggestions = sut.suggestions(for: items)
        XCTAssertTrue(suggestions.contains { $0.name == "Spezialprodukt" })
    }
}
