import Foundation

class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isContact = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let userId: UUID
    private let userService = UserService.shared
    private let contactService = ContactService.shared
    private let chatVM = ChatListViewModel()
    
    init(userId: UUID) {
        self.userId = userId
    }
    
    func loadUser() {
        isLoading = true
        Task {
            do {
                let user = try await userService.getUser(userId: userId)
                await MainActor.run {
                    self.user = user
                    self.isContact = self.contactService.isContact(userId: userId)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Не удалось загрузить профиль: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func addToContacts() {
        Task {
            do {
                _ = try await contactService.sendContactRequest(to: userId.uuidString)
                await MainActor.run {
                    self.isContact = true
                    NotificationService.shared.showSuccess("Запрос отправлен")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func removeFromContacts() {
        Task {
            do {
                _ = try await contactService.removeContact(userId: userId.uuidString)
                await MainActor.run {
                    self.isContact = false
                    NotificationService.shared.showInfo("Контакт удалён")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func startPrivateChat() {
        Task {
            if let chat = await chatVM.findOrCreatePrivateChat(with: userId) {
                await MainActor.run {
                    NotificationCenter.default.post(name: .chatCreated, object: chat)
                    NotificationCenter.default.post(name: .openChat, object: chat.id)
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Не удалось создать чат"
                }
            }
        }
    }
}
