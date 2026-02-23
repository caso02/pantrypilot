import XCTest
@testable import PantryPilot

final class CurrencyFormatterTests: XCTestCase {

    func testFormatDecimal() {
        let result = CurrencyFormatter.formatMoney(amount: Decimal(3.95))
        XCTAssertTrue(result.contains("CHF"), "Should contain CHF: \(result)")
        XCTAssertTrue(result.contains("3.95") || result.contains("3,95"), "Should contain amount: \(result)")
    }

    func testFormatDouble() {
        let result = CurrencyFormatter.formatMoney(amount: 1.60)
        XCTAssertTrue(result.contains("CHF"))
        XCTAssertTrue(result.contains("1.60") || result.contains("1,60"))
    }

    func testFormatZero() {
        let result = CurrencyFormatter.formatMoney(amount: Decimal(0))
        XCTAssertTrue(result.contains("CHF"))
        XCTAssertTrue(result.contains("0.00") || result.contains("0,00"))
    }

    func testFormatLargeAmount() {
        let result = CurrencyFormatter.formatMoney(amount: Decimal(1234.50))
        XCTAssertTrue(result.contains("CHF"))
    }
}
