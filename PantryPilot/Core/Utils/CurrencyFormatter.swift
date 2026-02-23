import Foundation

enum CurrencyFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "de_CH")
        f.currencyCode = "CHF"
        f.currencySymbol = "CHF"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static func formatMoney(amount: Decimal) -> String {
        formatter.string(from: amount as NSDecimalNumber) ?? "CHF \(amount)"
    }

    static func formatMoney(amount: Double) -> String {
        formatMoney(amount: Decimal(amount))
    }
}
