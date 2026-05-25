import Foundation

class UserService {
    static let shared = UserService()
    private let graphQL = GraphQLClient.shared
    private init() {}
    
    func getUser(userId: UUID) async throws -> User {
        let query = """
        query GetUser($userId: String!) {
            user {
                get(id: $userId) {
                    userId
                    nickName
                    firstName
                    lastName
                    middleName
                    email
                    phone
                    avatarUrl
                    bio
                    lastSeen
                    isOnline
                    status
                    emailVerified
                    phoneVerified
                    isAdmin
                    createdAt
                    updatedAt
                }
            }
        }
        """
        struct Response: Decodable {
            let user: UserWrapper
        }
        struct UserWrapper: Decodable {
            let get: User
        }
        let variables = ["userId": userId.uuidString]
        let response: Response = try await graphQL.perform(
            query: query,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        )
        return response.user.get
    }
}
