import Foundation

enum GraphQLError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case networkError(Error)
    case httpError(Int, String?)
    case graphQLErrors([String])

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL"
        case .noData: return "Нет данных от сервера"
        case .decodingError(let msg): return "Ошибка данных: \(msg)"
        case .networkError(let err): return "Ошибка сети: \(err.localizedDescription)"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg ?? "Неизвестная ошибка")"
        case .graphQLErrors(let msgs): return msgs.joined(separator: ", ")
        }
    }
}

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLErrorDetail]?
}

struct GraphQLErrorDetail: Decodable {
    let message: String
}

class GraphQLClient {
    static let shared = GraphQLClient()
    private let baseURL = AppConfig.graphqlURL
    private let session = URLSession.shared
    
    // Блокировка для предотвращения множественных refresh
    private var isRefreshing = false
    private var pendingRequests: [(String, Any?, Decodable.Type, String?) -> Void] = []
    
    private init() {}
    
    func perform<Response: Decodable>(
        query: String,
        variables: [String: Any]? = nil,
        responseType: Response.Type,
        authToken: String? = nil
    ) async throws -> Response {
        // Попытка запроса с текущим токеном
        do {
            return try await performRequest(query: query, variables: variables, responseType: responseType, authToken: authToken)
        } catch let error as GraphQLError {
            // Если 401 и есть refresh token – обновляем и повторяем
            if case .httpError(let code, _) = error, code == 401 {
                let refreshed = await refreshTokenIfNeeded()
                if refreshed, let newToken = TokenManager.shared.accessToken {
                    return try await performRequest(query: query, variables: variables, responseType: responseType, authToken: newToken)
                }
            }
            throw error
        } catch {
            throw error
        }
    }
    
    private func performRequest<Response: Decodable>(
        query: String,
        variables: [String: Any]?,
        responseType: Response.Type,
        authToken: String?
    ) async throws -> Response {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = ["query": query, "variables": variables ?? [:]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GraphQLError.networkError(URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw GraphQLError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8))
        }
        
        let rawString = String(data: data, encoding: .utf8) ?? "nil"
        print("📦 Raw response for \(Response.self): \(rawString)")
        
        let decoder = JSONDecoder.snakeCaseDecoder
        do {
            let graphQLResponse = try decoder.decode(GraphQLResponse<Response>.self, from: data)
            if let errors = graphQLResponse.errors, !errors.isEmpty {
                throw GraphQLError.graphQLErrors(errors.map { $0.message })
            }
            guard let data = graphQLResponse.data else {
                throw GraphQLError.noData
            }
            return data
        } catch let DecodingError.dataCorrupted(context) {
            print("❌ Data corrupted: \(context)")
            throw GraphQLError.decodingError("Data corrupted: \(context.debugDescription)")
        } catch let DecodingError.keyNotFound(key, context) {
            print("❌ Key '\(key)' not found: \(context.debugDescription)")
            throw GraphQLError.decodingError("Missing key '\(key)'")
        } catch let DecodingError.typeMismatch(type, context) {
            print("❌ Type mismatch for type \(type): \(context.debugDescription)")
            throw GraphQLError.decodingError("Type mismatch for \(type)")
        } catch let DecodingError.valueNotFound(type, context) {
            print("❌ Value not found for type \(type): \(context.debugDescription)")
            throw GraphQLError.decodingError("Value not found for \(type)")
        } catch {
            print("❌ Other decoding error: \(error)")
            throw GraphQLError.decodingError(error.localizedDescription)
        }
    }
    
    private func refreshTokenIfNeeded() async -> Bool {
        // Блокировка параллельных вызовов
        if isRefreshing {
            // Ждём завершения текущего refresh
            return await withCheckedContinuation { continuation in
                pendingRequests.append { _, _, _, _ in
                    continuation.resume(returning: TokenManager.shared.accessToken != nil)
                }
            }
        }
        isRefreshing = true
        defer { isRefreshing = false }
        
        guard let refreshToken = TokenManager.shared.refreshToken else { return false }
        let success = await AuthViewModel().restoreSession()
        
        // Выполнить все ожидающие запросы
        for pending in pendingRequests {
            pending("", nil, EmptyResponse.self, nil)
        }
        pendingRequests.removeAll()
        
        return success
    }
}

// Пустой тип для заглушки
private struct EmptyResponse: Decodable {}
