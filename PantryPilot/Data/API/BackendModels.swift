import Foundation

// MARK: - Request

struct ReceiptParseRequest: Codable {
    let lines: [String]
    let autoMatch: Bool
    let autoLearn: Bool

    init(lines: [String], autoMatch: Bool = true, autoLearn: Bool = false) {
        self.lines = lines
        self.autoMatch = autoMatch
        self.autoLearn = autoLearn
    }
}

// MARK: - Response

struct ReceiptParseResponse: Codable {
    let parsed: [ParsedAndMatchedLine]
    let stats: ParseStats
}

struct ParsedAndMatchedLine: Codable {
    let rawText: String
    let llm: LLMParsedLine
    let match: ProductMatch?
}

struct LLMParsedLine: Codable {
    let rawText: String
    let productName: String
    let brand: String?
    let quantity: Double?
    let unit: String?
    let unitPrice: Double?
    let category: String?
    let confidence: String?
}

struct ProductMatch: Codable {
    let productId: String
    let canonicalName: String
    let unitText: String?
    let categoryPath: [String]
    let score: Double
}

struct ParseStats: Codable {
    let total: Int
    let matched: Int
    let highConfidence: Int
}
