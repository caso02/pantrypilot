import Foundation
import SwiftUI

@Observable
@MainActor
final class InventoryViewModel {
    var searchText = ""
    var selectedLocation: StorageLocation? = nil
    var selectedItem: InventoryItem? = nil
    var showDetail = false
    var showAddSheet = false

    var isMultiSelectActive = false
    var selectedIds: Set<UUID> = []
    var showDeleteConfirmation = false

    var selectedCount: Int { selectedIds.count }

    // Add-Item fields
    var newName = ""
    var newQuantity = "1"
    var newUnit = "Stk"
    var newLocation: StorageLocation = .fridge
    var newCategory: FoodCategory = .other

    private let store: InventoryStore

    init(store: InventoryStore) {
        self.store = store
    }

    var useFirstItems: [InventoryItem] {
        store.items
            .filter { $0.expiryStatus.isUrgent }
            .sorted { ($0.estimatedExpiryDate ?? .distantFuture) < ($1.estimatedExpiryDate ?? .distantFuture) }
            .prefix(5)
            .map { $0 }
    }

    var filteredItems: [InventoryItem] {
        var result = store.items
        if let loc = selectedLocation {
            result = result.filter { $0.location == loc }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.canonicalName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var totalCount: Int { filteredItems.count }

    struct LocationGroup: Identifiable {
        let location: StorageLocation
        let categoryGroups: [CategoryGroup]
        var id: String { location.rawValue }
        var totalCount: Int { categoryGroups.reduce(0) { $0 + $1.items.count } }
    }

    struct CategoryGroup: Identifiable {
        let category: FoodCategory
        let items: [InventoryItem]
        var id: String { category.rawValue }
        var hasUrgent: Bool { items.contains { $0.expiryStatus.isUrgent } }
    }

    var groupedByLocationAndCategory: [LocationGroup] {
        let byLocation = Dictionary(grouping: filteredItems) { $0.location }
        return StorageLocation.allCases.compactMap { loc in
            guard let items = byLocation[loc], !items.isEmpty else { return nil }
            let byCategory = Dictionary(grouping: items) { $0.category ?? .other }
            let catGroups = byCategory
                .map { CategoryGroup(category: $0.key, items: $0.value.sorted { $0.canonicalName < $1.canonicalName }) }
                .sorted { $0.category.displayName < $1.category.displayName }
            return LocationGroup(location: loc, categoryGroups: catGroups)
        }
    }

    var isLoading: Bool { store.isLoading }
    var errorMessage: String? { store.errorMessage }

    func clearError() {
        store.errorMessage = nil
    }

    func loadData() async {
        await store.loadInventory()
    }

    func deleteItem(_ item: InventoryItem) async {
        await store.deleteItem(item)
    }

    func updateItem(_ item: InventoryItem) async {
        await store.updateItem(item)
    }

    func setEmpty(_ item: InventoryItem) async {
        await store.deleteItem(item)
        let suggestion = ShoppingListItem(name: item.canonicalName, targetQuantity: 1, unit: item.unit)
        store.addToShoppingList(suggestion)
    }

    func halfConsumed(_ item: InventoryItem) async {
        var updated = item
        updated.quantity = max(updated.quantity / 2, 0)
        await store.updateItem(updated)
    }

    func adjustQuantity(_ item: InventoryItem, by delta: Double) async {
        var updated = item
        updated.quantity = max(updated.quantity + delta, 0)
        if updated.quantity <= 0 {
            await setEmpty(item)
        } else {
            await store.updateItem(updated)
        }
    }

    func openDetail(_ item: InventoryItem) {
        selectedItem = item
        showDetail = true
    }

    func addManualItem() async {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let qty = Double(newQuantity) ?? 1
        let item = InventoryItem(
            canonicalName: newName.trimmingCharacters(in: .whitespaces),
            quantity: qty,
            unit: newUnit,
            location: newLocation,
            category: newCategory
        )
        await store.addItem(item)
        resetAddForm()
    }

    func resetAddForm() {
        newName = ""
        newQuantity = "1"
        newUnit = "Stk"
        newLocation = .fridge
        newCategory = .other
        showAddSheet = false
    }

    // MARK: - Multi-Select

    func toggleMultiSelect() {
        isMultiSelectActive.toggle()
        if !isMultiSelectActive {
            selectedIds.removeAll()
        }
    }

    func toggleSelection(_ item: InventoryItem) {
        if selectedIds.contains(item.id) {
            selectedIds.remove(item.id)
        } else {
            selectedIds.insert(item.id)
        }
    }

    func selectAll() {
        selectedIds = Set(filteredItems.map(\.id))
    }

    func deselectAll() {
        selectedIds.removeAll()
    }

    func deleteSelected() async {
        let toDelete = store.items.filter { selectedIds.contains($0.id) }
        for item in toDelete {
            await store.deleteItem(item)
        }
        selectedIds.removeAll()
        isMultiSelectActive = false
    }

    func moveSelected(to location: StorageLocation) async {
        let toMove = store.items.filter { selectedIds.contains($0.id) }
        for item in toMove {
            var updated = item
            updated.location = location
            await store.updateItem(updated)
        }
        selectedIds.removeAll()
        isMultiSelectActive = false
    }
}
