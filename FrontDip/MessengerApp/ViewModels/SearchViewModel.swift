import Foundation
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [UserPublicResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let contactService = ContactService.shared
    
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
                let results = try await contactService.searchUsers(query: searchQuery)
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
        contactService.sendContactRequest(to: user)
        DispatchQueue.main.async {
            self.searchResults.removeAll { $0.user_id == user.user_id }
        }
    }
}
