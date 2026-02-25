import Foundation

struct SyncPushPayload: Codable {
    let inventory: [SyncInventoryItem]
    let shoppingList: [SyncShoppingItem]
    let receipts: [SyncReceipt]
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
    let imageUrl: String?
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
    let receipts: [SyncReceipt]

    init(
        inventory: [SyncInventoryItem],
        shoppingList: [SyncShoppingItem],
        receipts: [SyncReceipt]
    ) {
        self.inventory = inventory
        self.shoppingList = shoppingList
        self.receipts = receipts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inventory = try container.decode([SyncInventoryItem].self, forKey: .inventory)
        shoppingList = try container.decode([SyncShoppingItem].self, forKey: .shoppingList)
        receipts = try container.decodeIfPresent([SyncReceipt].self, forKey: .receipts) ?? []
    }
}

struct SyncReceipt: Codable {
    let clientId: String
    let merchant: String
    let date: String
    let totalAmount: Double?
    let itemCount: Int
    let lineItems: [SyncReceiptLineItem]
}

struct SyncReceiptLineItem: Codable {
    let clientId: String
    let name: String
    let quantity: Double
    let unit: String
    let unitPrice: Double?
    let category: String?
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
        let snapshot = store.localSyncSnapshot()
        let payload = SyncPushPayload(
            inventory: snapshot.inventory,
            shoppingList: snapshot.shoppingList,
            receipts: snapshot.receipts
        )

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
            await store.applyCloudSnapshot(response)
            AppLogger.general.info(
                "Sync pull restored: \(response.inventory.count) inventory, \(response.shoppingList.count) shopping, \(response.receipts.count) receipts"
            )
        } catch {
            AppLogger.general.error("Sync pull failed: \(error.localizedDescription)")
        }
    }
}
