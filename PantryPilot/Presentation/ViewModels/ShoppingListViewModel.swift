import Foundation
import SwiftUI

@Observable
@MainActor
final class ShoppingListViewModel {
    var newItemName = ""
    var newItemQuantity = ""
    var newItemUnit = "Stk"
    var showAddSheet = false
    var showAllSuggestions = false

    private let store: InventoryStore
    private let lowStockService: LowStockSuggestionService

    static let maxTopSuggestions = 5

    init(store: InventoryStore, lowStockService: LowStockSuggestionService) {
        self.store = store
        self.lowStockService = lowStockService
    }

    var shoppingList: [ShoppingListItem] { store.shoppingList }

    var pendingItems: [ShoppingListItem] {
        store.shoppingList.filter { !$0.isCompleted }
    }

    var completedItems: [ShoppingListItem] {
        store.shoppingList.filter { $0.isCompleted }
    }

    private var allSuggestions: [LowStockSuggestionService.Suggestion] {
        let all = lowStockService.suggestions(for: store.items)
        let onList = Set(store.shoppingList.map { $0.name.lowercased() })
        return all.filter { !onList.contains($0.name.lowercased()) }
    }

    var topSuggestions: [LowStockSuggestionService.Suggestion] {
        Array(allSuggestions.prefix(Self.maxTopSuggestions))
    }

    var hasMoreSuggestions: Bool {
        allSuggestions.count > Self.maxTopSuggestions
    }

    var fullSuggestions: [LowStockSuggestionService.Suggestion] {
        allSuggestions
    }

    func addItem() {
        guard !newItemName.isEmpty else { return }
        let qty = Double(newItemQuantity)
        let item = ShoppingListItem(
            name: newItemName,
            targetQuantity: qty,
            unit: newItemUnit.isEmpty ? nil : newItemUnit
        )
        store.addToShoppingList(item)
        newItemName = ""
        newItemQuantity = ""
        newItemUnit = "Stk"
        showAddSheet = false
    }

    func addSuggestion(_ suggestion: LowStockSuggestionService.Suggestion) {
        let item = ShoppingListItem(
            name: suggestion.name,
            targetQuantity: suggestion.suggestedQuantity,
            unit: suggestion.unit
        )
        store.addToShoppingList(item)
    }

    func toggleItem(_ item: ShoppingListItem) {
        store.toggleShoppingItem(item)
    }

    func removeItem(_ item: ShoppingListItem) {
        store.removeFromShoppingList(item)
    }
}
