import Foundation

final class LowStockSuggestionService {

    struct Suggestion: Identifiable {
        let id = UUID()
        let name: String
        let currentQuantity: Double
        let suggestedQuantity: Double
        let unit: String
        let reason: String
    }

    private let stapleThresholds: [String: (minQuantity: Double, suggestedQuantity: Double, unit: String)] = [
        "milch": (1, 2, "L"),
        "butter": (1, 1, "Stk"),
        "eier": (4, 10, "Stk"),
        "brot": (1, 1, "Stk"),
        "reis": (0.5, 1, "kg"),
        "nudeln": (0.5, 1, "kg"),
        "kartoffeln": (1, 2, "kg"),
        "zwiebeln": (2, 5, "Stk"),
        "tomaten": (2, 4, "Stk"),
        "äpfel": (2, 6, "Stk"),
        "kaffee": (0.25, 0.5, "kg"),
        "mehl": (0.5, 1, "kg"),
        "zucker": (0.5, 1, "kg"),
        "öl": (0.25, 1, "L"),
    ]

    func suggestions(for inventory: [InventoryItem]) -> [Suggestion] {
        var results: [Suggestion] = []
        let inventoryNames = Set(inventory.map { $0.canonicalName.lowercased() })
        let inventoryByName = Dictionary(grouping: inventory) { $0.canonicalName.lowercased() }

        for (staple, threshold) in stapleThresholds {
            let matchingItems = inventoryByName[staple] ?? []
            let totalQty = matchingItems.reduce(0.0) { $0 + $1.quantity }

            if totalQty < threshold.minQuantity {
                let reason: String
                if matchingItems.isEmpty {
                    reason = "Nicht auf Lager"
                } else {
                    reason = "Niedriger Bestand (\(String(format: "%.0f", totalQty)) \(threshold.unit))"
                }
                results.append(Suggestion(
                    name: staple.capitalized,
                    currentQuantity: totalQty,
                    suggestedQuantity: threshold.suggestedQuantity,
                    unit: threshold.unit,
                    reason: reason
                ))
            }
        }

        let expiringSoon = inventory.filter { $0.isExpiringSoon || $0.isExpired }
        for item in expiringSoon where !results.contains(where: { $0.name.lowercased() == item.canonicalName.lowercased() }) {
            results.append(Suggestion(
                name: item.canonicalName,
                currentQuantity: item.quantity,
                suggestedQuantity: item.quantity,
                unit: item.unit,
                reason: item.isExpired ? "Abgelaufen" : "Läuft bald ab"
            ))
        }

        return results.sorted { $0.name < $1.name }
    }
}
