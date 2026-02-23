import Foundation
import SwiftData

@Model
final class PersistedNormalizationMapping {
    @Attribute(.unique) var rawKey: String
    var canonicalName: String
    var categoryRaw: String?
    var updatedAt: Date

    init(rawKey: String, canonicalName: String, category: FoodCategory? = nil, updatedAt: Date = .now) {
        self.rawKey = rawKey.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.canonicalName = canonicalName
        self.categoryRaw = category?.rawValue
        self.updatedAt = updatedAt
    }

    var category: FoodCategory? {
        categoryRaw.flatMap { FoodCategory(rawValue: $0) }
    }
}
