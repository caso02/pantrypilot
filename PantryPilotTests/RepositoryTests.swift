import XCTest
@testable import PantryPilot

final class MockReceiptRepository: ReceiptRepositoryProtocol {
    var uploadResult: ReceiptParseResult?
    var shouldFail = false

    func uploadAndParse(imageData: Data) async throws -> ReceiptParseResult {
        if shouldFail { throw NetworkError.serverUnavailable }
        return uploadResult ?? ReceiptParseResult(
            merchant: "TestMarkt",
            purchaseDate: "2026-02-23",
            lineItems: [
                ParsedLineItem(rawText: "Testmilch", quantity: 1, unit: "L", price: 1.29)
            ]
        )
    }
}

final class MockInventoryRepository: InventoryRepositoryProtocol {
    var items: [InventoryItem] = []
    var shouldFail = false

    func fetchAll() async throws -> [InventoryItem] {
        if shouldFail { throw NetworkError.unknown(NSError(domain: "", code: -1)) }
        return items
    }

    func save(_ item: InventoryItem) async throws {
        if shouldFail { throw NetworkError.unknown(NSError(domain: "", code: -1)) }
        items.append(item)
    }

    func saveAll(_ newItems: [InventoryItem]) async throws {
        if shouldFail { throw NetworkError.unknown(NSError(domain: "", code: -1)) }
        items.append(contentsOf: newItems)
    }

    func delete(_ item: InventoryItem) async throws {
        items.removeAll { $0.id == item.id }
    }

    func update(_ item: InventoryItem) async throws {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        }
    }

    func syncWithRemote() async throws {}
}

final class ReceiptRepositoryTests: XCTestCase {
    func testMockUploadReturnsResult() async throws {
        let repo = MockReceiptRepository()
        let result = try await repo.uploadAndParse(imageData: Data())
        XCTAssertEqual(result.merchant, "TestMarkt")
        XCTAssertEqual(result.lineItems.count, 1)
    }

    func testMockUploadFailure() async {
        let repo = MockReceiptRepository()
        repo.shouldFail = true
        do {
            _ = try await repo.uploadAndParse(imageData: Data())
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }
}

final class InventoryRepositoryTests: XCTestCase {
    func testSaveAndFetch() async throws {
        let repo = MockInventoryRepository()
        let item = InventoryItem(canonicalName: "Milch", quantity: 1, unit: "L", location: .fridge)
        try await repo.save(item)
        let fetched = try await repo.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.canonicalName, "Milch")
    }

    func testDelete() async throws {
        let repo = MockInventoryRepository()
        let item = InventoryItem(canonicalName: "Butter")
        try await repo.save(item)
        try await repo.delete(item)
        let fetched = try await repo.fetchAll()
        XCTAssertTrue(fetched.isEmpty)
    }

    func testUpdate() async throws {
        let repo = MockInventoryRepository()
        var item = InventoryItem(canonicalName: "Eier", quantity: 6)
        try await repo.save(item)
        item.quantity = 10
        try await repo.update(item)
        let fetched = try await repo.fetchAll()
        XCTAssertEqual(fetched.first?.quantity, 10)
    }
}
