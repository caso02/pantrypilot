import Foundation
import SwiftUI
import SwiftData

@Observable
@MainActor
final class InventoryStore {
    private(set) var items: [InventoryItem] = []
    private(set) var shoppingList: [ShoppingListItem] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let repository: InventoryRepositoryProtocol
    private let expiryService: ExpiryEstimationService
    private let normalizationService: NormalizationService
    private let modelContext: ModelContext?
    var syncService: SyncService?

    init(
        repository: InventoryRepositoryProtocol,
        expiryService: ExpiryEstimationService = ExpiryEstimationService(),
        normalizationService: NormalizationService = NormalizationService(),
        modelContext: ModelContext? = nil
    ) {
        self.repository = repository
        self.expiryService = expiryService
        self.normalizationService = normalizationService
        self.modelContext = modelContext
    }

    private func triggerSync() {
        guard let syncService else { return }
        Task { await syncService.pushToCloud() }
    }

    var expiringSoonItems: [InventoryItem] {
        items.filter { $0.isExpiringSoon }
    }

    var expiredItems: [InventoryItem] {
        items.filter { $0.isExpired }
    }

    func itemsByLocation(_ location: StorageLocation) -> [InventoryItem] {
        items.filter { $0.location == location }
    }

    func loadInventory() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.persistence.error("Failed to load inventory: \(error.localizedDescription)")
        }
        loadShoppingList()
        isLoading = false
    }

    private func loadShoppingList() {
        guard let ctx = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<PersistedShoppingListItem>(
                sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
            )
            let persisted = try ctx.fetch(descriptor)
            shoppingList = persisted.map { $0.toDomain() }
        } catch {
            AppLogger.persistence.error("Failed to load shopping list: \(error.localizedDescription)")
        }
    }

    private func persistShoppingList() {
        guard let ctx = modelContext else { return }
        do {
            let existing = try ctx.fetch(FetchDescriptor<PersistedShoppingListItem>())
            let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.itemId, $0) })

            let currentIds = Set(shoppingList.map(\.id))
            for persisted in existing where !currentIds.contains(persisted.itemId) {
                ctx.delete(persisted)
            }

            for item in shoppingList {
                if let persisted = existingById[item.id] {
                    persisted.update(from: item)
                } else {
                    ctx.insert(PersistedShoppingListItem.from(item))
                }
            }

            try ctx.save()
        } catch {
            AppLogger.persistence.error("Failed to persist shopping list: \(error.localizedDescription)")
        }
    }

    func addItem(_ item: InventoryItem) async {
        var enriched = item
        if enriched.estimatedExpiryDate == nil, let cat = enriched.category {
            enriched.estimatedExpiryDate = expiryService.estimateExpiry(
                category: cat,
                location: enriched.location,
                opened: enriched.opened,
                from: enriched.purchaseDate
            )
        }
        do {
            try await repository.save(enriched)
            items.append(enriched)
            triggerSync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addItems(_ newItems: [InventoryItem]) async {
        var enriched: [InventoryItem] = []
        for var item in newItems {
            if item.estimatedExpiryDate == nil, let cat = item.category {
                item.estimatedExpiryDate = expiryService.estimateExpiry(
                    category: cat,
                    location: item.location,
                    opened: item.opened,
                    from: item.purchaseDate
                )
            }
            enriched.append(item)
        }
        do {
            try await repository.saveAll(enriched)
            items.append(contentsOf: enriched)
            triggerSync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ item: InventoryItem) async {
        do {
            try await repository.delete(item)
            items.removeAll { $0.id == item.id }
            triggerSync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateItem(_ item: InventoryItem) async {
        do {
            try await repository.update(item)
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx] = item
            }
            triggerSync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addToShoppingList(_ item: ShoppingListItem) {
        let key = item.name.lowercased()
        let unitKey = (item.unit ?? "").lowercased()
        if let idx = shoppingList.firstIndex(where: {
            $0.name.lowercased() == key && ($0.unit ?? "").lowercased() == unitKey && !$0.isCompleted
        }) {
            let existing = shoppingList[idx]
            let newQty = (existing.targetQuantity ?? 1) + (item.targetQuantity ?? 1)
            shoppingList[idx] = ShoppingListItem(
                id: existing.id,
                name: existing.name,
                targetQuantity: newQty,
                unit: existing.unit,
                addedAt: existing.addedAt,
                isCompleted: false
            )
        } else {
            shoppingList.append(item)
        }
        persistShoppingList()
        triggerSync()
    }

    func removeFromShoppingList(_ item: ShoppingListItem) {
        shoppingList.removeAll { $0.id == item.id }
        persistShoppingList()
        triggerSync()
    }

    func toggleShoppingItem(_ item: ShoppingListItem) {
        if let idx = shoppingList.firstIndex(where: { $0.id == item.id }) {
            shoppingList[idx].isCompleted.toggle()
        }
        persistShoppingList()
        triggerSync()
    }
}
