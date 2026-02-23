import Foundation
import SwiftData

@Model
final class PersistedInventoryItem {
    @Attribute(.unique) var itemId: UUID
    var canonicalName: String
    var quantity: Double
    var unit: String
    var locationRaw: String
    var purchaseDate: Date
    var estimatedExpiryDate: Date?
    var opened: Bool
    var notes: String?
    var categoryRaw: String?

    init(
        itemId: UUID = UUID(),
        canonicalName: String,
        quantity: Double = 1,
        unit: String = "Stk",
        location: StorageLocation = .pantry,
        purchaseDate: Date = .now,
        estimatedExpiryDate: Date? = nil,
        opened: Bool = false,
        notes: String? = nil,
        category: FoodCategory? = nil
    ) {
        self.itemId = itemId
        self.canonicalName = canonicalName
        self.quantity = quantity
        self.unit = unit
        self.locationRaw = location.rawValue
        self.purchaseDate = purchaseDate
        self.estimatedExpiryDate = estimatedExpiryDate
        self.opened = opened
        self.notes = notes
        self.categoryRaw = category?.rawValue
    }

    func toDomain() -> InventoryItem {
        InventoryItem(
            id: itemId,
            canonicalName: canonicalName,
            quantity: quantity,
            unit: unit,
            location: StorageLocation(rawValue: locationRaw) ?? .pantry,
            purchaseDate: purchaseDate,
            estimatedExpiryDate: estimatedExpiryDate,
            opened: opened,
            notes: notes,
            category: categoryRaw.flatMap { FoodCategory(rawValue: $0) }
        )
    }

    static var sampleItems: [PersistedInventoryItem] {
        [
            PersistedInventoryItem(
                canonicalName: "M-Classic Milch",
                quantity: 1, unit: "L",
                location: .fridge,
                estimatedExpiryDate: Calendar.current.date(byAdding: .day, value: 2, to: .now),
                category: .dairy
            ),
            PersistedInventoryItem(
                canonicalName: "Freiland-Eier",
                quantity: 6, unit: "Stk",
                location: .fridge,
                estimatedExpiryDate: Calendar.current.date(byAdding: .day, value: 10, to: .now),
                category: .dairy
            ),
            PersistedInventoryItem(
                canonicalName: "Spaghetti",
                quantity: 2, unit: "Stk",
                location: .pantry,
                estimatedExpiryDate: Calendar.current.date(byAdding: .day, value: 180, to: .now),
                category: .grains
            ),
            PersistedInventoryItem(
                canonicalName: "Pouletbrust",
                quantity: 0.5, unit: "kg",
                location: .freezer,
                estimatedExpiryDate: Calendar.current.date(byAdding: .day, value: 60, to: .now),
                category: .meat
            ),
            PersistedInventoryItem(
                canonicalName: "Rüebli",
                quantity: 4, unit: "Stk",
                location: .fridge,
                estimatedExpiryDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
                category: .produce
            ),
        ]
    }
}

@Model
final class PersistedShoppingListItem {
    @Attribute(.unique) var itemId: UUID
    var name: String
    var targetQuantity: Double?
    var unit: String?
    var addedAt: Date
    var isCompleted: Bool

    init(
        itemId: UUID = UUID(),
        name: String,
        targetQuantity: Double? = nil,
        unit: String? = nil,
        addedAt: Date = .now,
        isCompleted: Bool = false
    ) {
        self.itemId = itemId
        self.name = name
        self.targetQuantity = targetQuantity
        self.unit = unit
        self.addedAt = addedAt
        self.isCompleted = isCompleted
    }

    func toDomain() -> ShoppingListItem {
        ShoppingListItem(
            id: itemId,
            name: name,
            targetQuantity: targetQuantity,
            unit: unit,
            addedAt: addedAt,
            isCompleted: isCompleted
        )
    }

    func update(from item: ShoppingListItem) {
        name = item.name
        targetQuantity = item.targetQuantity
        unit = item.unit
        addedAt = item.addedAt
        isCompleted = item.isCompleted
    }

    static func from(_ item: ShoppingListItem) -> PersistedShoppingListItem {
        PersistedShoppingListItem(
            itemId: item.id,
            name: item.name,
            targetQuantity: item.targetQuantity,
            unit: item.unit,
            addedAt: item.addedAt,
            isCompleted: item.isCompleted
        )
    }

    static var sampleItems: [PersistedShoppingListItem] {
        [
            PersistedShoppingListItem(name: "Milch", targetQuantity: 2, unit: "L"),
            PersistedShoppingListItem(name: "Butter", targetQuantity: 1, unit: "Stk"),
            PersistedShoppingListItem(name: "Brot", targetQuantity: 1, unit: "Stk"),
        ]
    }
}

// MARK: - Receipt

@Model
final class PersistedReceipt {
    @Attribute(.unique) var receiptId: UUID
    var merchant: String
    var date: Date
    var totalAmount: Double?
    var itemCount: Int
    @Relationship(deleteRule: .cascade) var lineItems: [PersistedReceiptLineItem]

    init(
        receiptId: UUID = UUID(),
        merchant: String,
        date: Date = .now,
        totalAmount: Double? = nil,
        itemCount: Int = 0,
        lineItems: [PersistedReceiptLineItem] = []
    ) {
        self.receiptId = receiptId
        self.merchant = merchant
        self.date = date
        self.totalAmount = totalAmount
        self.itemCount = itemCount
        self.lineItems = lineItems
    }

    func toDomain() -> Receipt {
        Receipt(
            id: receiptId,
            merchant: merchant,
            date: date,
            totalAmount: totalAmount,
            itemCount: itemCount,
            lineItems: lineItems.map { $0.toDomain() }
        )
    }

    static func from(_ receipt: Receipt) -> PersistedReceipt {
        let persisted = PersistedReceipt(
            receiptId: receipt.id,
            merchant: receipt.merchant,
            date: receipt.date,
            totalAmount: receipt.totalAmount,
            itemCount: receipt.itemCount
        )
        persisted.lineItems = receipt.lineItems.map { PersistedReceiptLineItem.from($0) }
        return persisted
    }
}

@Model
final class PersistedReceiptLineItem {
    @Attribute(.unique) var lineItemId: UUID
    var name: String
    var quantity: Double
    var unit: String
    var unitPrice: Double?
    var categoryRaw: String?

    init(
        lineItemId: UUID = UUID(),
        name: String,
        quantity: Double = 1,
        unit: String = "Stk",
        unitPrice: Double? = nil,
        category: FoodCategory? = nil
    ) {
        self.lineItemId = lineItemId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.categoryRaw = category?.rawValue
    }

    func toDomain() -> ReceiptLineItem {
        ReceiptLineItem(
            id: lineItemId,
            name: name,
            quantity: quantity,
            unit: unit,
            unitPrice: unitPrice,
            category: categoryRaw.flatMap { FoodCategory(rawValue: $0) }
        )
    }

    static func from(_ item: ReceiptLineItem) -> PersistedReceiptLineItem {
        PersistedReceiptLineItem(
            lineItemId: item.id,
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            unitPrice: item.unitPrice,
            category: item.category
        )
    }
}
