import Foundation

struct ReceiptParseResult: Codable {
    let merchant: String
    let purchaseDate: String
    let lineItems: [ParsedLineItem]
}

struct ParsedLineItem: Identifiable, Codable, Hashable {
    let id: UUID
    let rawText: String
    let quantity: Double?
    let unit: String?
    let price: Double?

    enum CodingKeys: String, CodingKey {
        case rawText, quantity, unit, price
    }

    init(id: UUID = UUID(), rawText: String, quantity: Double?, unit: String?, price: Double?) {
        self.id = id
        self.rawText = rawText
        self.quantity = quantity
        self.unit = unit
        self.price = price
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.rawText = try container.decode(String.self, forKey: .rawText)
        self.quantity = try container.decodeIfPresent(Double.self, forKey: .quantity)
        self.unit = try container.decodeIfPresent(String.self, forKey: .unit)
        self.price = try container.decodeIfPresent(Double.self, forKey: .price)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawText, forKey: .rawText)
        try container.encodeIfPresent(quantity, forKey: .quantity)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(price, forKey: .price)
    }
}
