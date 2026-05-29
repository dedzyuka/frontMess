import Foundation

class UserService {
    static let shared = UserService()
    private let graphQL = GraphQLClient.shared
    private init() {}
    
    func getUser(userId: UUID) async throws -> User {
        let query = GraphQLQueries.getUser
        let variables = ["userId": userId.uuidString]
        
        // Структура для декодирования ответа
        struct Response: Decodable {
            let user: UserWrapper
        }
        struct UserWrapper: Decodable {
            let get: User
        }
        
        let response: Response = try await graphQL.perform(
            query: query,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        )
        return response.user.get
    }
}
