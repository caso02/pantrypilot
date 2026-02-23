import Foundation
import SwiftUI

@Observable
@MainActor
final class InsightsViewModel {
    private let store: InventoryStore

    init(store: InventoryStore) {
        self.store = store
    }

    var totalItems: Int { store.items.count }

    var expiringSoon: Int { store.expiringSoonItems.count }

    var expired: Int { store.expiredItems.count }

    var expiringSoonLabel: String {
        "\(expiringSoon) Artikel bald ablaufend (≤3 Tage)"
    }

    var expiredLabel: String {
        expired == 0 ? "Keine abgelaufenen Artikel" : "\(expired) Artikel abgelaufen"
    }

    var itemsByCategory: [(FoodCategory, Int)] {
        let grouped = Dictionary(grouping: store.items) { $0.category ?? .other }
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    var itemsByLocation: [(StorageLocation, Int)] {
        let grouped = Dictionary(grouping: store.items) { $0.location }
        return StorageLocation.allCases.map { loc in
            (loc, grouped[loc]?.count ?? 0)
        }
    }

    var useFirstItems: [InventoryItem] {
        store.items
            .filter { $0.expiryStatus.isUrgent }
            .sorted { ($0.estimatedExpiryDate ?? .distantFuture) < ($1.estimatedExpiryDate ?? .distantFuture) }
            .prefix(3)
            .map { $0 }
    }
}
