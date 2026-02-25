import Foundation

struct InventoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    var canonicalName: String
    var quantity: Double
    var unit: String
    var location: StorageLocation
    var purchaseDate: Date
    var estimatedExpiryDate: Date?
    var opened: Bool
    var notes: String?
    var category: FoodCategory?
    var imageUrl: String?

    init(
        id: UUID = UUID(),
        canonicalName: String,
        quantity: Double = 1,
        unit: String = "Stk",
        location: StorageLocation = .pantry,
        purchaseDate: Date = .now,
        estimatedExpiryDate: Date? = nil,
        opened: Bool = false,
        notes: String? = nil,
        category: FoodCategory? = nil,
        imageUrl: String? = nil
    ) {
        self.id = id
        self.canonicalName = canonicalName
        self.quantity = quantity
        self.unit = unit
        self.location = location
        self.purchaseDate = purchaseDate
        self.estimatedExpiryDate = estimatedExpiryDate
        self.opened = opened
        self.notes = notes
        self.category = category
        self.imageUrl = imageUrl
    }

    var expiryStatus: ExpiryStatus {
        ExpiryStatus(expiryDate: estimatedExpiryDate)
    }

    var isExpiringSoon: Bool { expiryStatus.isSoon }
    var isExpired: Bool { expiryStatus.isExpired }
}

enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case fridge
    case pantry
    case freezer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fridge: return "Kühlschrank"
        case .pantry: return "Vorratskammer"
        case .freezer: return "Gefrierschrank"
        }
    }

    var shortName: String {
        switch self {
        case .fridge: return "Kühlschr."
        case .pantry: return "Vorrat"
        case .freezer: return "Gefrier"
        }
    }

    var icon: String {
        switch self {
        case .fridge: return "refrigerator"
        case .pantry: return "archivebox"
        case .freezer: return "snowflake"
        }
    }
}
