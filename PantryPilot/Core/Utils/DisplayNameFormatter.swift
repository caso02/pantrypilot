import Foundation

enum DisplayNameFormatter {
    static func format(_ name: String) -> String {
        guard !name.isEmpty else { return name }

        let uppercaseRatio = letterUppercaseRatio(in: name)
        guard uppercaseRatio > 0.7 else { return name }

        return name
            .split(separator: " ")
            .map { titleCaseWord(String($0)) }
            .joined(separator: " ")
    }

    private static func titleCaseWord(_ word: String) -> String {
        for brand in preservedBrands where brand.caseInsensitiveCompare(word) == .orderedSame {
            return brand
        }
        if word.count <= 2 { return word }
        if word.contains("-") {
            return word
                .split(separator: "-")
                .map { part in
                    let p = String(part)
                    guard p.count > 1 else { return p.uppercased() }
                    return p.prefix(1).uppercased() + p.dropFirst().lowercased()
                }
                .joined(separator: "-")
        }
        return word.prefix(1).uppercased() + word.dropFirst().lowercased()
    }

    private static func letterUppercaseRatio(in string: String) -> Double {
        let letters = string.filter(\.isLetter)
        guard !letters.isEmpty else { return 0 }
        let uppercase = letters.filter(\.isUppercase)
        return Double(uppercase.count) / Double(letters.count)
    }

    private static let preservedBrands = ["M-Classic", "M-Budget", "IP-SUISSE", "Bio"]
}
