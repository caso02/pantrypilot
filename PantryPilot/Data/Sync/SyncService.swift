import Foundation

struct SyncPushPayload: Codable {
    let inventory: [SyncInventoryItem]
    let shoppingList: [SyncShoppingItem]
}

struct SyncInventoryItem: Codable {
    let clientId: String
    let canonicalName: String
    let quantity: Double
    let unit: String
    let location: String
    let purchaseDate: String
    let estimatedExpiryDate: String?
    let opened: Bool
    let notes: String?
    let category: String?
}

struct SyncShoppingItem: Codable {
    let clientId: String
    let name: String
    let targetQuantity: Double?
    let unit: String?
    let addedAt: String
    let isCompleted: Bool
}

struct SyncPushResponse: Codable {
    let ok: Bool
}

struct SyncPullResponse: Codable {
    let inventory: [SyncInventoryItem]
    let shoppingList: [SyncShoppingItem]
}

@MainActor
final class SyncService {
    private let networkClient: NetworkClientProtocol
    private let store: InventoryStore

    init(networkClient: NetworkClientProtocol, store: InventoryStore) {
        self.networkClient = networkClient
        self.store = store
    }

    func pushToCloud() async {
        let formatter = ISO8601DateFormatter()

        let inventoryItems = store.items.map { item in
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
                category: item.category?.rawValue
            )
        }

        let shoppingItems = store.shoppingList.map { item in
            SyncShoppingItem(
                clientId: item.id.uuidString,
                name: item.name,
                targetQuantity: item.targetQuantity,
                unit: item.unit,
                addedAt: formatter.string(from: item.addedAt),
                isCompleted: item.isCompleted
            )
        }

        let payload = SyncPushPayload(inventory: inventoryItems, shoppingList: shoppingItems)

        guard let body = try? JSONEncoder().encode(payload) else { return }

        do {
            let _: SyncPushResponse = try await networkClient.request(Endpoints.syncPush(body: body))
            AppLogger.general.info("Sync push completed")
        } catch {
            AppLogger.general.error("Sync push failed: \(error.localizedDescription)")
        }
    }

    func pullFromCloud() async {
        do {
            let response: SyncPullResponse = try await networkClient.request(Endpoints.syncPull())
            AppLogger.general.info("Sync pull: \(response.inventory.count) inventory, \(response.shoppingList.count) shopping items")
        } catch {
            AppLogger.general.error("Sync pull failed: \(error.localizedDescription)")
        }
    }
}
