import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidRequest
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingFailed(Error)
    case noConnection
    case timeout
    case serverUnavailable
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL."
        case .invalidRequest: return "Invalid request."
        case .invalidResponse: return "Invalid response from server."
        case .httpError(let code, _): return "HTTP error \(code)."
        case .decodingFailed(let err): return "Decoding failed: \(err.localizedDescription)"
        case .noConnection: return "No internet connection."
        case .timeout: return "Request timed out."
        case .serverUnavailable: return "Server unavailable."
        case .unknown(let err): return err.localizedDescription
        }
    }

    var isTransient: Bool {
        switch self {
        case .noConnection, .timeout, .serverUnavailable: return true
        case .httpError(let code, _): return code >= 500 || code == 429
        default: return false
        }
    }
}
