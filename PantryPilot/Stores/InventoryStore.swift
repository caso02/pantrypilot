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

        // Merge duplicate scan lines before touching persistence.
        var mergedIncoming: [InventoryItem] = []
        for item in enriched {
            if let idx = mergedIncoming.firstIndex(where: { identityKey(for: $0) == identityKey(for: item) }) {
                mergedIncoming[idx].quantity += item.quantity
                if mergedIncoming[idx].estimatedExpiryDate == nil {
                    mergedIncoming[idx].estimatedExpiryDate = item.estimatedExpiryDate
                }
                if mergedIncoming[idx].imageUrl == nil, let incomingImage = item.imageUrl, !incomingImage.isEmpty {
                    mergedIncoming[idx].imageUrl = incomingImage
                }
            } else {
                mergedIncoming.append(item)
            }
        }

        do {
            var toCreate: [InventoryItem] = []

            for incoming in mergedIncoming {
                if let existingIdx = items.firstIndex(where: { identityKey(for: $0) == identityKey(for: incoming) }) {
                    var updated = items[existingIdx]
                    updated.quantity += incoming.quantity
                    if updated.estimatedExpiryDate == nil {
                        updated.estimatedExpiryDate = incoming.estimatedExpiryDate
                    }
                    if updated.imageUrl == nil, let incomingImage = incoming.imageUrl, !incomingImage.isEmpty {
                        updated.imageUrl = incomingImage
                    }
                    try await repository.update(updated)
                    items[existingIdx] = updated
                } else {
                    toCreate.append(incoming)
                }
            }

            if !toCreate.isEmpty {
                try await repository.saveAll(toCreate)
                items.append(contentsOf: toCreate)
            }

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

    func localSyncSnapshot() -> (inventory: [SyncInventoryItem], shoppingList: [SyncShoppingItem], receipts: [SyncReceipt]) {
        let formatter = ISO8601DateFormatter()

        let inventoryPayload = items.map { item in
            SyncInventoryItem(
                clientId: item.id.uuidString,
                canonicalName: item.canonicalName,
                quantity: item.quantity,
                unit: item.unit,
                location: item.location.rawValue,
                purchaseDate: formatter.string(from: item.purchaseDate),
                estimatedExpiryDate: item.estimatedExpiryDate.map { formatter.string(from: $0) },
                opened: item.opened,
                notes: item.notes,
                category: item.category?.rawValue,
                imageUrl: item.imageUrl
            )
        }

        let shoppingPayload = shoppingList.map { item in
            SyncShoppingItem(
                clientId: item.id.uuidString,
                name: item.name,
                targetQuantity: item.targetQuantity,
                unit: item.unit,
                addedAt: formatter.string(from: item.addedAt),
                isCompleted: item.isCompleted
            )
        }

        var receiptPayload: [SyncReceipt] = []
        if let ctx = modelContext {
            do {
                let descriptor = FetchDescriptor<PersistedReceipt>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let receipts = try ctx.fetch(descriptor)
                receiptPayload = receipts.map { receipt in
                    SyncReceipt(
                        clientId: receipt.receiptId.uuidString,
                        merchant: receipt.merchant,
                        date: formatter.string(from: receipt.date),
                        totalAmount: receipt.totalAmount,
                        itemCount: receipt.itemCount,
                        lineItems: receipt.lineItems.map { line in
                            SyncReceiptLineItem(
                                clientId: line.lineItemId.uuidString,
                                name: line.name,
                                quantity: line.quantity,
                                unit: line.unit,
                                unitPrice: line.unitPrice,
                                category: line.categoryRaw
                            )
                        }
                    )
                }
            } catch {
                AppLogger.persistence.error("Failed to fetch receipts for sync snapshot: \(error.localizedDescription)")
            }
        }

        return (inventoryPayload, shoppingPayload, receiptPayload)
    }

    func applyCloudSnapshot(_ response: SyncPullResponse) async {
        let formatter = ISO8601DateFormatter()
        let localByClientId = Dictionary(uniqueKeysWithValues: items.map { ($0.id.uuidString, $0) })

        let restoredInventory = response.inventory.map { remote in
            let localFallback = localByClientId[remote.clientId]
            let resolvedEstimatedExpiryDate = remote.estimatedExpiryDate.flatMap { formatter.date(from: $0) }
                ?? localFallback?.estimatedExpiryDate
            let resolvedImageUrl: String? = {
                if let remoteImageUrl = remote.imageUrl, !remoteImageUrl.isEmpty {
                    return remoteImageUrl
                }
                return localFallback?.imageUrl
            }()

            InventoryItem(
                id: UUID(uuidString: remote.clientId) ?? UUID(),
                canonicalName: remote.canonicalName,
                quantity: remote.quantity,
                unit: remote.unit,
                location: StorageLocation(rawValue: remote.location) ?? .pantry,
                purchaseDate: formatter.date(from: remote.purchaseDate) ?? .now,
                estimatedExpiryDate: resolvedEstimatedExpiryDate,
                opened: remote.opened,
                notes: remote.notes,
                category: remote.category.flatMap(FoodCategory.init(rawValue:)),
                imageUrl: resolvedImageUrl
            )
        }

        do {
            try await repository.replaceAll(with: restoredInventory)
            items = restoredInventory
        } catch {
            AppLogger.persistence.error("Failed to restore inventory from cloud: \(error.localizedDescription)")
        }

        shoppingList = response.shoppingList.map { remote in
            ShoppingListItem(
                id: UUID(uuidString: remote.clientId) ?? UUID(),
                name: remote.name,
                targetQuantity: remote.targetQuantity,
                unit: remote.unit,
                addedAt: formatter.date(from: remote.addedAt) ?? .now,
                isCompleted: remote.isCompleted
            )
        }
        persistShoppingList()

        if let ctx = modelContext {
            do {
                let existingReceipts = try ctx.fetch(FetchDescriptor<PersistedReceipt>())
                for receipt in existingReceipts {
                    ctx.delete(receipt)
                }

                for remote in response.receipts {
                    let receipt = PersistedReceipt(
                        receiptId: UUID(uuidString: remote.clientId) ?? UUID(),
                        merchant: remote.merchant,
                        date: formatter.date(from: remote.date) ?? .now,
                        totalAmount: remote.totalAmount,
                        itemCount: remote.itemCount,
                        lineItems: remote.lineItems.map { line in
                            PersistedReceiptLineItem(
                                lineItemId: UUID(uuidString: line.clientId) ?? UUID(),
                                name: line.name,
                                quantity: line.quantity,
                                unit: line.unit,
                                unitPrice: line.unitPrice,
                                category: line.category.flatMap(FoodCategory.init(rawValue:))
                            )
                        }
                    )
                    ctx.insert(receipt)
                }
                try ctx.save()
            } catch {
                AppLogger.persistence.error("Failed to restore receipts from cloud: \(error.localizedDescription)")
            }
        }
    }

    private func identityKey(for item: InventoryItem) -> String {
        [
            item.canonicalName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            item.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            item.location.rawValue
        ].joined(separator: "|")
    }
}
