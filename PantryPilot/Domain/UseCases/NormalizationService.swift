import Foundation
import SwiftData

final class NormalizationService {

    private var userMappings: [String: (canonicalName: String, category: FoodCategory?)] = [:]

    private let abbreviations: [String: String] = [
        "bio": "Bio",
        "h-": "H-",
        "voll": "Vollmilch",
        "mager": "Magerquark",
        "tief": "Tiefkühl",
        "frischmilch": "Frische Milch",
        "wz": "Weizen",
        "vk": "Vollkorn",
        "erdb.": "Erdbeere",
        "tom.": "Tomate",
        "kart.": "Kartoffel",
        "schw.": "Schwein",
        "hähn.": "Hähnchen",
        "naturj.": "Naturjoghurt",
        "butterm.": "Buttermilch",
        "rüebli": "Karotten",
        "poulet": "Poulet",
        "zopf": "Zopf",
        "m-classic": "M-Classic",
        "m-budget": "M-Budget",
        "aha!": "Aha!",
    ]

    private let nonFoodKeywords: Set<String> = [
        "pfand", "sack", "gebühr", "rabatt", "bon", "total", "subtotal",
        "mwst", "zahlung", "karte", "bar", "retoure", "tasche", "beutel"
    ]

    private let stripPatterns: [String] = [
        "\\d+[.,]\\d{2}\\s*[A-Z]?$",
        "^\\d+\\s*[xX×]\\s*",
        "\\d+\\s*(ml|l|g|kg|stk|st)\\b",
        "[*#]+",
        "\\s{2,}"
    ]

    func loadUserMappings(from context: ModelContext) {
        let descriptor = FetchDescriptor<PersistedNormalizationMapping>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        if let mappings = try? context.fetch(descriptor) {
            for mapping in mappings {
                userMappings[mapping.rawKey] = (mapping.canonicalName, mapping.category)
            }
        }
    }

    func saveUserMapping(rawText: String, canonicalName: String, category: FoodCategory?, context: ModelContext) {
        let key = rawText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        userMappings[key] = (canonicalName, category)

        let descriptor = FetchDescriptor<PersistedNormalizationMapping>(
            predicate: #Predicate { $0.rawKey == key }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.canonicalName = canonicalName
            existing.categoryRaw = category?.rawValue
            existing.updatedAt = .now
        } else {
            let mapping = PersistedNormalizationMapping(
                rawKey: key, canonicalName: canonicalName, category: category
            )
            context.insert(mapping)
        }
        try? context.save()
    }

    func isNonFood(_ rawText: String) -> Bool {
        let lower = rawText.lowercased()
        return nonFoodKeywords.contains(where: { lower.contains($0) })
    }

    func normalize(_ rawText: String) -> String {
        let key = rawText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let mapped = userMappings[key] {
            return mapped.canonicalName
        }

        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        for pattern in stripPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(
                    in: text,
                    range: NSRange(text.startIndex..., in: text),
                    withTemplate: ""
                )
            }
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        for (abbrev, expanded) in abbreviations {
            if text.lowercased().contains(abbrev) {
                text = text.replacingOccurrences(
                    of: abbrev,
                    with: expanded,
                    options: .caseInsensitive
                )
            }
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return rawText }

        return text.prefix(1).uppercased() + text.dropFirst()
    }

    func guessCategory(for name: String) -> FoodCategory {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let mapped = userMappings[key], let cat = mapped.category {
            return cat
        }

        let lower = name.lowercased()

        let categoryKeywords: [(FoodCategory, [String])] = [
            (.dairy, ["milch", "joghurt", "käse", "quark", "sahne", "butter", "schmand", "frischkäse", "rahm"]),
            (.meat, ["fleisch", "hähnchen", "schwein", "rind", "wurst", "schinken", "lachs", "fisch", "thunfisch", "poulet", "poultry"]),
            (.produce, ["apfel", "äpfel", "banane", "tomate", "salat", "gurke", "kartoffel", "zwiebel", "karotte", "rüebli", "paprika", "obst", "gemüse", "erdbeere"]),
            (.bakery, ["brot", "brötchen", "kuchen", "toast", "croissant", "semmel", "zopf", "weggli"]),
            (.frozen, ["tiefkühl", "eis", "pizza tk", "tk "]),
            (.canned, ["dose", "konserve", "mais dose", "bohnen dose"]),
            (.beverages, ["wasser", "saft", "cola", "bier", "wein", "tee", "kaffee", "limonade", "rivella"]),
            (.snacks, ["chips", "schokolade", "keks", "gummibär", "nüsse", "riegel"]),
            (.condiments, ["ketchup", "senf", "mayo", "sauce", "essig", "öl", "salz", "pfeffer", "gewürz", "aromat"]),
            (.grains, ["nudel", "reis", "mehl", "hafer", "müsli", "cornflakes", "spaghetti", "penne"])
        ]

        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { lower.contains($0) }) {
                return category
            }
        }
        return .other
    }

    static let defaultLocationForCategory: [FoodCategory: StorageLocation] = [
        .dairy: .fridge,
        .meat: .fridge,
        .produce: .fridge,
        .bakery: .pantry,
        .frozen: .freezer,
        .canned: .pantry,
        .beverages: .pantry,
        .snacks: .pantry,
        .condiments: .pantry,
        .grains: .pantry,
        .other: .pantry,
    ]
}
