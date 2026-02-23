import XCTest
@testable import PantryPilot

final class ShoppingListDedupeTests: XCTestCase {

    @MainActor
    func testDeduplicatesSameNameAndUnit() async {
        let repo = MockInventoryRepository()
        let store = InventoryStore(repository: repo)

        let item1 = ShoppingListItem(name: "Milch", targetQuantity: 1, unit: "L")
        let item2 = ShoppingListItem(name: "Milch", targetQuantity: 2, unit: "L")

        store.addToShoppingList(item1)
        store.addToShoppingList(item2)

        XCTAssertEqual(store.shoppingList.count, 1, "Should merge into single item")
        XCTAssertEqual(store.shoppingList.first?.targetQuantity, 3, "Quantities should be summed")
    }

    @MainActor
    func testDifferentUnitsNotDeduped() async {
        let repo = MockInventoryRepository()
        let store = InventoryStore(repository: repo)

        store.addToShoppingList(ShoppingListItem(name: "Milch", targetQuantity: 1, unit: "L"))
        store.addToShoppingList(ShoppingListItem(name: "Milch", targetQuantity: 500, unit: "ml"))

        XCTAssertEqual(store.shoppingList.count, 2, "Different units should be separate")
    }

    @MainActor
    func testCaseInsensitiveDedupe() async {
        let repo = MockInventoryRepository()
        let store = InventoryStore(repository: repo)

        store.addToShoppingList(ShoppingListItem(name: "Milch", targetQuantity: 1, unit: "L"))
        store.addToShoppingList(ShoppingListItem(name: "milch", targetQuantity: 1, unit: "l"))

        XCTAssertEqual(store.shoppingList.count, 1, "Case-insensitive match should merge")
    }

    @MainActor
    func testCompletedItemsNotMerged() async {
        let repo = MockInventoryRepository()
        let store = InventoryStore(repository: repo)

        store.addToShoppingList(ShoppingListItem(name: "Milch", targetQuantity: 1, unit: "L"))
        store.toggleShoppingItem(store.shoppingList.first!)
        store.addToShoppingList(ShoppingListItem(name: "Milch", targetQuantity: 1, unit: "L"))

        XCTAssertEqual(store.shoppingList.count, 2, "Completed items should not be merged with new ones")
    }
}
