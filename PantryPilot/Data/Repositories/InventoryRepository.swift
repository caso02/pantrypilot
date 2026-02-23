import Foundation
import SwiftData

@MainActor
final class InventoryRepository: InventoryRepositoryProtocol {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func fetchAll() async throws -> [InventoryItem] {
        let context = persistence.container.mainContext
        let descriptor = FetchDescriptor<PersistedInventoryItem>(
            sortBy: [SortDescriptor(\.canonicalName)]
        )
        let persisted = try context.fetch(descriptor)
        return persisted.map { $0.toDomain() }
    }

    func save(_ item: InventoryItem) async throws {
        let context = persistence.container.mainContext
        let persisted = PersistedInventoryItem(
            itemId: item.id,
            canonicalName: item.canonicalName,
            quantity: item.quantity,
            unit: item.unit,
            location: item.location,
            purchaseDate: item.purchaseDate,
            estimatedExpiryDate: item.estimatedExpiryDate,
            opened: item.opened,
            notes: item.notes,
            category: item.category
        )
        context.insert(persisted)
        try context.save()
    }

    func saveAll(_ items: [InventoryItem]) async throws {
        let context = persistence.container.mainContext
        for item in items {
            let persisted = PersistedInventoryItem(
                itemId: item.id,
                canonicalName: item.canonicalName,
                quantity: item.quantity,
                unit: item.unit,
                location: item.location,
                purchaseDate: item.purchaseDate,
                estimatedExpiryDate: item.estimatedExpiryDate,
                opened: item.opened,
                notes: item.notes,
                category: item.category
            )
            context.insert(persisted)
        }
        try context.save()
    }

    func delete(_ item: InventoryItem) async throws {
        let context = persistence.container.mainContext
        let id = item.id
        let descriptor = FetchDescriptor<PersistedInventoryItem>(
            predicate: #Predicate { $0.itemId == id }
        )
        if let persisted = try context.fetch(descriptor).first {
            context.delete(persisted)
            try context.save()
        }
    }

    func update(_ item: InventoryItem) async throws {
        let context = persistence.container.mainContext
        let id = item.id
        let descriptor = FetchDescriptor<PersistedInventoryItem>(
            predicate: #Predicate { $0.itemId == id }
        )
        if let persisted = try context.fetch(descriptor).first {
            persisted.canonicalName = item.canonicalName
            persisted.quantity = item.quantity
            persisted.unit = item.unit
            persisted.locationRaw = item.location.rawValue
            persisted.purchaseDate = item.purchaseDate
            persisted.estimatedExpiryDate = item.estimatedExpiryDate
            persisted.opened = item.opened
            persisted.notes = item.notes
            persisted.categoryRaw = item.category?.rawValue
            try context.save()
        }
    }

    func syncWithRemote() async throws {
        // TODO: Implement remote sync when backend is available
        AppLogger.persistence.info("Remote sync placeholder called")
    }
}
