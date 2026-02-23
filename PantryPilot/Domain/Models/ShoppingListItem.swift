import Foundation

struct ShoppingListItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var targetQuantity: Double?
    var unit: String?
    var addedAt: Date
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        name: String,
        targetQuantity: Double? = nil,
        unit: String? = nil,
        addedAt: Date = .now,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.targetQuantity = targetQuantity
        self.unit = unit
        self.addedAt = addedAt
        self.isCompleted = isCompleted
    }
}
