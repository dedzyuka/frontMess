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
    private let baseURL = "http://localhost:8002/graphql"
    private let session = URLSession.shared
    
    private init() {}
    
    func perform<Response: Decodable>(
        query: String,
        variables: [String: Any]? = nil,
        responseType: Response.Type,
        authToken: String? = nil
    ) async throws -> Response {
        guard let url = URL(string: baseURL) else {
            throw GraphQLError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔑 Auth token used: \(authToken?.prefix(20) ?? "nil")")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables ?? [:]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        print("📤 GraphQL Query: \(query)")
        let (data, response) = try await session.data(for: request)
        
        // Логируем ответ для отладки
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📦 Response JSON: \(jsonString.prefix(2000))")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GraphQLError.networkError(URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw GraphQLError.httpError(httpResponse.statusCode, errorMessage)
        }
        
        
        let decoder = JSONDecoder.snakeCaseDecoder
        
        let graphQLResponse = try decoder.decode(GraphQLResponse<Response>.self, from: data)
        
        if let errors = graphQLResponse.errors, !errors.isEmpty {
            throw GraphQLError.graphQLErrors(errors.map { $0.message })
        }
        
        guard let data = graphQLResponse.data else {
            throw GraphQLError.noData
        }
        
        return data
    }
}
