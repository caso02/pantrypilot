import Foundation

protocol ReceiptRepositoryProtocol: Sendable {
    func uploadAndParse(imageData: Data) async throws -> ReceiptParseResult
    func parseReceiptLines(_ lines: [String]) async throws -> ReceiptParseResponse
}
