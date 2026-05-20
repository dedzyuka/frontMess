import Foundation

// MARK: - GraphQL Error
enum GraphQLError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case networkError(Error)
    case httpError(Int, String?)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received"
        case .decodingError(let msg): return "Decoding error: \(msg)"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg ?? "Unknown error")"
        }
    }
}

// MARK: - GraphQL Response Wrappers
struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLErrorDetail]?
}

struct GraphQLErrorDetail: Decodable {
    let message: String
}

// MARK: - GraphQL Client
class GraphQLClient {
    static let shared = GraphQLClient()
    private let baseURL = "http://localhost:8000/graphql"
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
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables ?? [:]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GraphQLError.networkError(URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw GraphQLError.httpError(httpResponse.statusCode, errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let graphQLResponse = try decoder.decode(GraphQLResponse<Response>.self, from: data)
        
        if let errors = graphQLResponse.errors, !errors.isEmpty {
            throw GraphQLError.decodingError(errors.first?.message ?? "GraphQL error")
        }
        
        guard let data = graphQLResponse.data else {
            throw GraphQLError.noData
        }
        
        return data
    }
}
