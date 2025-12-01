// ./FrontDip/MessengerApp/ViewModels/SearchViewModel.swift
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
            searchResults = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await contactService.searchUsers(query: searchQuery)
                
                await MainActor.run {
                    // Фильтруем уже добавленных в контакты и самого себя
                    self.searchResults = results.filter { user in
                        !self.contactService.isContact(userId: user.user_id) &&
                        user.user_id != AppState.shared.currentUser?.id
                    }
                    self.isLoading = false
                    print("Найдено пользователей: \(self.searchResults.count)")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка поиска: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Ошибка поиска: \(error)")
                }
            }
        }
    }
    
    func sendContactRequest(to user: UserPublicResponse) {
        contactService.sendContactRequest(to: user)
        
        // Убираем из результатов поиска
        searchResults.removeAll { $0.user_id == user.user_id }
        
        // Показываем уведомление
        NotificationCenter.default.post(
            name: .showNotification,
            object: "Запрос отправлен пользователю \(user.nickname)"
        )
    }
}
