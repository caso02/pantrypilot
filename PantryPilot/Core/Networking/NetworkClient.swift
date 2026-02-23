import Foundation

protocol NetworkClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func upload<T: Decodable>(
        _ endpoint: Endpoint,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> T
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let queryItems: [URLQueryItem]
    let body: Data?
    let retryPolicy: RetryPolicy
    let timeoutInterval: TimeInterval

    init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        retryPolicy: RetryPolicy = .default,
        timeoutInterval: TimeInterval = 30
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.retryPolicy = retryPolicy
        self.timeoutInterval = timeoutInterval
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

final class NetworkClient: NetworkClientProtocol, @unchecked Sendable {
    private let session: URLSession
    private let baseURL: URL
    private let tokenProvider: @Sendable () -> String?

    init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: @escaping @Sendable () -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let urlRequest = try buildRequest(for: endpoint)
        return try await executeWithRetry(urlRequest, retryPolicy: endpoint.retryPolicy)
    }

    func upload<T: Decodable>(
        _ endpoint: Endpoint,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> T {
        let boundary = UUID().uuidString
        var urlRequest = try buildRequest(for: endpoint)
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = createMultipartBody(
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            boundary: boundary
        )
        return try await executeWithRetry(urlRequest, retryPolicy: endpoint.retryPolicy)
    }

    // MARK: - Private

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }
        guard let url = components?.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.timeoutInterval = endpoint.timeoutInterval

        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    private func executeWithRetry<T: Decodable>(
        _ request: URLRequest,
        retryPolicy: RetryPolicy
    ) async throws -> T {
        var lastError: Error = NetworkError.unknown(NSError(domain: "", code: -1))

        for attempt in 0..<retryPolicy.maxAttempts {
            do {
                return try await execute(request)
            } catch let error as NetworkError where error.isTransient && attempt < retryPolicy.maxAttempts - 1 {
                lastError = error
                let delay = retryPolicy.delay(for: attempt)
                AppLogger.network.warning("Retry \(attempt + 1)/\(retryPolicy.maxAttempts) after \(String(format: "%.1f", delay))s")
                try await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            } catch {
                throw error
            }
        }
        throw lastError
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.noConnection
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.unknown(error)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode >= 500 || httpResponse.statusCode == 429 {
                throw NetworkError.serverUnavailable
            }
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    private func createMultipartBody(
        fileData: Data,
        fileName: String,
        mimeType: String,
        boundary: String
    ) -> Data {
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"
        body.append(Data(boundaryPrefix.utf8))
        body.append(Data("Content-Disposition: form-data; name=\"image\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }
}
