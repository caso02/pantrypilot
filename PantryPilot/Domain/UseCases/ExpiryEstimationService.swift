import Foundation

final class ExpiryEstimationService {

    struct ExpiryRule {
        let category: FoodCategory
        let location: StorageLocation
        let daysUnopened: Int
        let daysOpened: Int
    }

    private let rules: [ExpiryRule] = [
        // Dairy
        ExpiryRule(category: .dairy, location: .fridge, daysUnopened: 14, daysOpened: 5),
        ExpiryRule(category: .dairy, location: .pantry, daysUnopened: 3, daysOpened: 1),
        ExpiryRule(category: .dairy, location: .freezer, daysUnopened: 90, daysOpened: 30),
        // Meat
        ExpiryRule(category: .meat, location: .fridge, daysUnopened: 5, daysOpened: 2),
        ExpiryRule(category: .meat, location: .pantry, daysUnopened: 0, daysOpened: 0),
        ExpiryRule(category: .meat, location: .freezer, daysUnopened: 180, daysOpened: 60),
        // Produce
        ExpiryRule(category: .produce, location: .fridge, daysUnopened: 7, daysOpened: 4),
        ExpiryRule(category: .produce, location: .pantry, daysUnopened: 5, daysOpened: 3),
        ExpiryRule(category: .produce, location: .freezer, daysUnopened: 120, daysOpened: 60),
        // Bakery
        ExpiryRule(category: .bakery, location: .fridge, daysUnopened: 7, daysOpened: 3),
        ExpiryRule(category: .bakery, location: .pantry, daysUnopened: 5, daysOpened: 2),
        ExpiryRule(category: .bakery, location: .freezer, daysUnopened: 90, daysOpened: 30),
        // Frozen
        ExpiryRule(category: .frozen, location: .freezer, daysUnopened: 365, daysOpened: 90),
        ExpiryRule(category: .frozen, location: .fridge, daysUnopened: 3, daysOpened: 1),
        ExpiryRule(category: .frozen, location: .pantry, daysUnopened: 0, daysOpened: 0),
        // Canned
        ExpiryRule(category: .canned, location: .pantry, daysUnopened: 730, daysOpened: 5),
        ExpiryRule(category: .canned, location: .fridge, daysUnopened: 730, daysOpened: 5),
        ExpiryRule(category: .canned, location: .freezer, daysUnopened: 730, daysOpened: 90),
        // Beverages
        ExpiryRule(category: .beverages, location: .pantry, daysUnopened: 365, daysOpened: 7),
        ExpiryRule(category: .beverages, location: .fridge, daysUnopened: 365, daysOpened: 5),
        ExpiryRule(category: .beverages, location: .freezer, daysUnopened: 365, daysOpened: 30),
        // Snacks
        ExpiryRule(category: .snacks, location: .pantry, daysUnopened: 180, daysOpened: 14),
        ExpiryRule(category: .snacks, location: .fridge, daysUnopened: 180, daysOpened: 14),
        ExpiryRule(category: .snacks, location: .freezer, daysUnopened: 365, daysOpened: 60),
        // Condiments
        ExpiryRule(category: .condiments, location: .pantry, daysUnopened: 365, daysOpened: 90),
        ExpiryRule(category: .condiments, location: .fridge, daysUnopened: 365, daysOpened: 60),
        ExpiryRule(category: .condiments, location: .freezer, daysUnopened: 365, daysOpened: 90),
        // Grains
        ExpiryRule(category: .grains, location: .pantry, daysUnopened: 365, daysOpened: 90),
        ExpiryRule(category: .grains, location: .fridge, daysUnopened: 365, daysOpened: 90),
        ExpiryRule(category: .grains, location: .freezer, daysUnopened: 730, daysOpened: 180),
        // Other (defaults)
        ExpiryRule(category: .other, location: .pantry, daysUnopened: 30, daysOpened: 7),
        ExpiryRule(category: .other, location: .fridge, daysUnopened: 14, daysOpened: 5),
        ExpiryRule(category: .other, location: .freezer, daysUnopened: 180, daysOpened: 60),
    ]

    func estimateExpiry(
        category: FoodCategory,
        location: StorageLocation,
        opened: Bool,
        from purchaseDate: Date
    ) -> Date {
        let rule = rules.first { $0.category == category && $0.location == location }
            ?? ExpiryRule(category: .other, location: location, daysUnopened: 14, daysOpened: 5)

        let days = opened ? rule.daysOpened : rule.daysUnopened
        return Calendar.current.date(byAdding: .day, value: max(days, 1), to: purchaseDate)!
    }

    func daysUntilExpiry(for item: InventoryItem) -> Int? {
        guard let expiry = item.estimatedExpiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: expiry).day
    }
}
