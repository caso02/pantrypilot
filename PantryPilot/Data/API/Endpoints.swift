import Foundation

enum Endpoints {
    static func uploadReceipt() -> Endpoint {
        Endpoint(
            path: "/v1/receipts",
            method: .post,
            retryPolicy: .default
        )
    }

    static func parseReceipt(lines: [String]) -> Endpoint {
        let body = ReceiptParseRequest(lines: lines)
        let data = try? JSONEncoder().encode(body)
        return Endpoint(
            path: "/v1/receipts/parse",
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: data,
            retryPolicy: RetryPolicy(maxAttempts: 2, baseDelay: 2.0, maxDelay: 15.0, backoffMultiplier: 2.0),
            timeoutInterval: 180
        )
    }

    static func fetchOffers() -> Endpoint {
        Endpoint(
            path: "/v1/offers",
            method: .get,
            retryPolicy: .default
        )
    }

    static func syncPush(body: Data) -> Endpoint {
        Endpoint(
            path: "/v1/sync/push",
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: body,
            retryPolicy: RetryPolicy(maxAttempts: 2, baseDelay: 1.0, maxDelay: 5.0, backoffMultiplier: 2.0)
        )
    }

    static func syncPull() -> Endpoint {
        Endpoint(
            path: "/v1/sync/pull",
            method: .get,
            retryPolicy: .default
        )
    }

    static func authApple(body: Data) -> Endpoint {
        Endpoint(
            path: "/v1/auth/apple",
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: body,
            retryPolicy: RetryPolicy(maxAttempts: 2, baseDelay: 1.0, maxDelay: 5.0, backoffMultiplier: 2.0)
        )
    }

    static func authGoogle(body: Data) -> Endpoint {
        Endpoint(
            path: "/v1/auth/google",
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: body,
            retryPolicy: RetryPolicy(maxAttempts: 2, baseDelay: 1.0, maxDelay: 5.0, backoffMultiplier: 2.0)
        )
    }
}
