import Foundation
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [UserPublicResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let contactService = ContactService.shared
    private let client = GraphQLClient.shared
    
    func search() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            DispatchQueue.main.async {
                self.searchResults = []
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        Task {
            do {
                let query = """
                query Search($query: String!) {
                    user {
                        search(query: $query, page: 1, page_size: 20) {
                            user_id
                            nick_name
                            avatar_url
                            is_online
                        }
                    }
                }
                """
                let variables = ["query": searchQuery]
                let response: SearchResponse = try await client.perform(
                    query: query,
                    variables: variables,
                    responseType: SearchResponse.self
                )
                
                let results = response.user.search.map { apiUser in
                    UserPublicResponse(
                        user_id: UUID(uuidString: apiUser.user_id)!,
                        nickname: apiUser.nick_name,
                        public_key: ""
                    )
                }
                
                let currentUserId = AppState.shared.currentUser?.id
                let filtered = results.filter { user in
                    let isSelf = currentUserId == user.user_id
                    let isContact = self.contactService.isContact(userId: user.user_id)
                    return !isSelf && !isContact
                }
                
                await MainActor.run {
                    self.searchResults = filtered
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка поиска: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func sendContactRequest(to user: UserPublicResponse) {
        let userId = user.user_id
        guard !contactService.isContact(userId: user.user_id) else {
            NotificationService.shared.showInfo("\(user.nickname) уже в ваших контактах")
            return
        }
        
        guard let currentUserId = AppState.shared.currentUser?.id,
              user.user_id != currentUserId else {
            NotificationService.shared.showError("Нельзя отправить запрос самому себе")
            return
        }
        
        contactService.sendContactRequest(to: user)
        
        DispatchQueue.main.async {
            self.searchResults.removeAll { $0.user_id == user.user_id }
        }
        
        NotificationService.shared.showSuccess("Запрос отправлен пользователю \(user.nickname)")
    }
}

