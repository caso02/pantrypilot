import Foundation

struct LineItem: Identifiable, Codable, Hashable {
    let id: UUID
    var receiptId: UUID
    var rawText: String
    var canonicalName: String?
    var quantity: Double?
    var unit: String?
    var price: Decimal?
    var category: FoodCategory?

    init(
        id: UUID = UUID(),
        receiptId: UUID,
        rawText: String,
        canonicalName: String? = nil,
        quantity: Double? = nil,
        unit: String? = nil,
        price: Decimal? = nil,
        category: FoodCategory? = nil
    ) {
        self.id = id
        self.receiptId = receiptId
        self.rawText = rawText
        self.canonicalName = canonicalName
        self.quantity = quantity
        self.unit = unit
        self.price = price
        self.category = category
    }
}

enum FoodCategory: String, Codable, CaseIterable {
    case dairy
    case meat
    case produce
    case bakery
    case frozen
    case canned
    case beverages
    case snacks
    case condiments
    case grains
    case other

    var displayName: String {
        switch self {
        case .dairy: return "Milchprodukte"
        case .meat: return "Fleisch & Fisch"
        case .produce: return "Obst & Gemüse"
        case .bakery: return "Backwaren"
        case .frozen: return "Tiefkühl"
        case .canned: return "Konserven"
        case .beverages: return "Getränke"
        case .snacks: return "Snacks"
        case .condiments: return "Gewürze & Saucen"
        case .grains: return "Getreide & Nudeln"
        case .other: return "Sonstiges"
        }
    }
}
