//
//  UserProfileViewModel.swift
//  FrontDip
//
//

import Foundation

class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var contactStatus: String?  // nil, "pending", "accepted", "incoming_pending"
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let userId: UUID
    private let userService = UserService.shared
    private let contactService = ContactService.shared
    private let graphQL = GraphQLClient.shared
    
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
                    self.contactStatus = self.contactService.getContactStatus(for: userId)
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
                    self.contactStatus = "pending"
                    self.contactService.loadOutgoingRequests()
                    NotificationService.shared.showSuccess("Запрос отправлен")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func cancelOutgoingRequest() {
        Task {
            do {
                _ = try await contactService.removeContact(userId: userId.uuidString)
                await MainActor.run {
                    self.contactStatus = nil
                    self.contactService.loadOutgoingRequests()
                    NotificationService.shared.showInfo("Запрос отменён")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func acceptIncomingRequest() {
        Task {
            await contactService.syncPendingRequests()
            if let request = contactService.pendingRequests.first(where: { $0.userId == userId }) {
                do {
                    _ = try await contactService.acceptContact(contactUserId: request.userId.uuidString)  // передаём userId отправителя
                    await MainActor.run {
                        self.contactStatus = "accepted"
                        self.contactService.loadContacts()
                        self.contactService.loadPendingRequests()
                        NotificationService.shared.showSuccess("Контакт добавлен")
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Ошибка: \(error.localizedDescription)"
                    }
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Запрос уже обработан или не найден"
                    self.contactStatus = nil
                }
            }
        }
    }

    func declineIncomingRequest() {
        Task {
            await contactService.syncPendingRequests()
            if let request = contactService.pendingRequests.first(where: { $0.userId == userId }) {
                do {
                    _ = try await contactService.removeContact(userId: request.userId.uuidString)
                    await MainActor.run {
                        self.contactStatus = nil
                        self.contactService.loadPendingRequests()
                        NotificationService.shared.showInfo("Запрос отклонён")
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Ошибка: \(error.localizedDescription)"
                    }
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Запрос уже обработан или не найден"
                    self.contactStatus = nil
                }
            }
        }
    }
    
    func removeFromContacts() {
        Task {
            do {
                _ = try await contactService.removeContact(userId: userId.uuidString)
                await MainActor.run {
                    self.contactStatus = nil
                    self.contactService.loadContacts()
                    NotificationService.shared.showInfo("Контакт удалён")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка: \(error.localizedDescription)"
                }
            }
        }
    }
    
    
    func startPrivateChatAndGetChat() async -> Chat? {
        let vm = ChatListViewModel()

        if let chat = await vm.findOrCreatePrivateChat(with: userId) {

            NotificationCenter.default.post(
                name: .chatUpdated,
                object: nil
            )

            return chat
        }

        return nil
    }
}
