import Foundation

struct Receipt: Identifiable, Codable, Hashable {
    let id: UUID
    var merchant: String
    var date: Date
    var totalAmount: Double?
    var itemCount: Int
    var lineItems: [ReceiptLineItem]

    init(
        id: UUID = UUID(),
        merchant: String = "Migros",
        date: Date = .now,
        totalAmount: Double? = nil,
        itemCount: Int = 0,
        lineItems: [ReceiptLineItem] = []
    ) {
        self.id = id
        self.merchant = merchant
        self.date = date
        self.totalAmount = totalAmount
        self.itemCount = itemCount
        self.lineItems = lineItems
    }
}

struct ReceiptLineItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var unitPrice: Double?
    var category: FoodCategory?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double = 1,
        unit: String = "Stk",
        unitPrice: Double? = nil,
        category: FoodCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.category = category
    }

    var totalPrice: Double? {
        guard let unitPrice else { return nil }
        return unitPrice * quantity
    }
}
