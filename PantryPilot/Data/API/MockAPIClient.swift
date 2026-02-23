import Foundation

final class MockAPIClient: NetworkClientProtocol, @unchecked Sendable {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        try await Task.sleep(for: .milliseconds(500))

        if endpoint.path.contains("receipts/parse") {
            return try decodeMockParseResponse()
        }
        if endpoint.path.contains("receipts") {
            return try decodeMockReceipt()
        }
        if endpoint.path.contains("offers") {
            return try decodeMockOffers()
        }
        throw NetworkError.invalidRequest
    }

    func upload<T: Decodable>(
        _ endpoint: Endpoint,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> T {
        try await Task.sleep(for: .seconds(1))
        return try decodeMockReceipt()
    }

    private func decodeMockReceipt<T: Decodable>() throws -> T {
        let json = """
        {
            "merchant": "MIGROS",
            "purchaseDate": "2026-02-23",
            "lineItems": [
                {"rawText": "M-CLASSIC MILCH 1L", "quantity": 1, "unit": "L", "price": 1.60},
                {"rawText": "JOGHURT NATUR 500G", "quantity": 500, "unit": "g", "price": 1.20},
                {"rawText": "RÜEBLI 1KG", "quantity": 1, "unit": "kg", "price": 2.50},
                {"rawText": "ÄPFEL 1KG", "quantity": 1, "unit": "kg", "price": 3.90},
                {"rawText": "BROT ZOPF", "quantity": 1, "unit": "Stk", "price": 3.20},
                {"rawText": "EIER FREIL 10ST", "quantity": 10, "unit": "Stk", "price": 5.90},
                {"rawText": "POULETBRUST", "quantity": 0.4, "unit": "kg", "price": 8.40},
                {"rawText": "KÄSE SCHEIBEN", "quantity": 1, "unit": "Stk", "price": 3.50},
                {"rawText": "PFAND", "quantity": null, "unit": null, "price": 0.30},
                {"rawText": "SACK GEBÜHR", "quantity": null, "unit": null, "price": 0.05}
            ]
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func decodeMockParseResponse<T: Decodable>() throws -> T {
        let json = """
        {
            "parsed": [
                {
                    "rawText": "M-CLASSIC MILCH 1L",
                    "llm": {"rawText": "M-CLASSIC MILCH 1L", "productName": "M-Classic Vollmilch", "brand": "M-Classic", "quantity": 1, "unit": "L", "category": "Milchprodukte", "confidence": "high"},
                    "match": {"productId": "mock-1", "canonicalName": "M-Classic Vollmilch UHT", "unitText": "1L", "categoryPath": ["Milchprodukte"], "score": 0.85}
                },
                {
                    "rawText": "BIO JOGHURT NATUR 500G",
                    "llm": {"rawText": "BIO JOGHURT NATUR 500G", "productName": "Bio Joghurt Natur", "brand": "Bio", "quantity": 500, "unit": "g", "category": "Milchprodukte", "confidence": "high"},
                    "match": {"productId": "mock-2", "canonicalName": "Bio Joghurt Nature", "unitText": "500g", "categoryPath": ["Milchprodukte"], "score": 0.78}
                },
                {
                    "rawText": "RÜEBLI 1KG",
                    "llm": {"rawText": "RÜEBLI 1KG", "productName": "Rüebli (Karotten)", "brand": null, "quantity": 1, "unit": "kg", "category": "Gemüse", "confidence": "high"},
                    "match": null
                },
                {
                    "rawText": "POULETBRUST 400G",
                    "llm": {"rawText": "POULETBRUST 400G", "productName": "Pouletbrust", "brand": "Optigal", "quantity": 400, "unit": "g", "category": "Fleisch", "confidence": "high"},
                    "match": {"productId": "mock-4", "canonicalName": "Optigal Pouletbrust", "unitText": "400g", "categoryPath": ["Fleisch"], "score": 0.92}
                },
                {
                    "rawText": "PFAND",
                    "llm": {"rawText": "PFAND", "productName": "Pfand", "brand": null, "quantity": null, "unit": null, "category": "Sonstiges", "confidence": "low"},
                    "match": null
                }
            ],
            "stats": {"total": 5, "matched": 3, "highConfidence": 4}
        }
        """
        let data = Data(json.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func decodeMockOffers<T: Decodable>() throws -> T {
        let json = """
        [
            {
                "id": "\(UUID().uuidString)",
                "merchantId": "\(UUID().uuidString)",
                "name": "M-Classic Vollmilch",
                "startsAt": "2026-02-20T00:00:00Z",
                "endsAt": "2026-02-28T23:59:59Z",
                "discountText": "-20%"
            }
        ]
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
