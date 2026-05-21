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
                    let isSelf = currentUserId == user.userId
                    let isContact = self.contactService.isContact(userId: user.userId)
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
        guard let currentUser = AppState.shared.currentUser else { return }
        guard currentUser.id != user.userId else { return }
        guard !contactService.isContact(userId: user.userId) else { return }
        
        Task {
            do {
                _ = try await contactService.sendContactRequest(to: user.userId.uuidString)
                await MainActor.run {
                    NotificationService.shared.showSuccess("Запрос отправлен \(user.nickName)")
                    // Удаляем из результатов поиска
                    self.searchResults.removeAll { $0.userId == user.userId }
                }
            } catch {
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка: \(error.localizedDescription)")
                }
            }
        }
    }
}
