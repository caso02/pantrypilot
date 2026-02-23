import Foundation

final class ReceiptRepository: ReceiptRepositoryProtocol, @unchecked Sendable {
    private let client: NetworkClientProtocol

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    func uploadAndParse(imageData: Data) async throws -> ReceiptParseResult {
        let endpoint = Endpoints.uploadReceipt()
        return try await client.upload(
            endpoint,
            fileData: imageData,
            fileName: "receipt.jpg",
            mimeType: "image/jpeg"
        )
    }

    func parseReceiptLines(_ lines: [String]) async throws -> ReceiptParseResponse {
        let endpoint = Endpoints.parseReceipt(lines: lines)
        return try await client.request(endpoint)
    }
}
