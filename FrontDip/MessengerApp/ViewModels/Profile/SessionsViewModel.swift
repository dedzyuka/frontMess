import Foundation

class SessionsViewModel: ObservableObject {
    @Published var sessions: [SessionInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let graphQL = GraphQLClient.shared
    
    func loadSessions() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            
            do {
                let response: ListSessionsResponse = try await graphQL.perform(
                    query: GraphQLQueries.listSessions,
                    variables: [:],
                    responseType: ListSessionsResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                self.sessions = response.auth.sessions
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func revokeSession(sessionId: String) async -> Bool {
        do {
            let _: RevokeSessionResponse = try await graphQL.perform(
                query: GraphQLQueries.revokeSession,
                variables: ["sessionId": sessionId],
                responseType: RevokeSessionResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            await loadSessions()
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
    
    func logoutAllOther() async -> Bool {
        do {
            let _: LogoutAllResponse = try await graphQL.perform(
                query: GraphQLQueries.logoutAllOtherSessions,
                variables: [:],
                responseType: LogoutAllResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            await loadSessions()
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}
