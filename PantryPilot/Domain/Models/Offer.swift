import Foundation

struct Offer: Identifiable, Codable, Hashable {
    let id: UUID
    var merchantId: UUID
    var name: String
    var startsAt: Date
    var endsAt: Date
    var discountText: String

    init(
        id: UUID = UUID(),
        merchantId: UUID,
        name: String,
        startsAt: Date,
        endsAt: Date,
        discountText: String
    ) {
        self.id = id
        self.merchantId = merchantId
        self.name = name
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.discountText = discountText
    }
}
