import Foundation
import Combine

@MainActor
class ChatSidebarViewModel: ObservableObject {
    let chat: Chat
    @Published var allMembers: [ChatMemberItem] = []      // все участники (кроме left)
    @Published var currentUserRole: String = "member"
    @Published var otherUser: User?
    @Published var isContact = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isDeleting = false

    // Вычисляемые списки
    var activeMembers: [ChatMemberItem] {
        allMembers.filter { $0.status == "active" }
    }
    var bannedMembers: [ChatMemberItem] {
        allMembers.filter { $0.status == "banned" }
    }

    private let graphQL = GraphQLClient.shared
    private let contactService = ContactService.shared
    private var cancellables = Set<AnyCancellable>()

    init(chat: Chat) {
        self.chat = chat
        setupBindings()
    }

    private func setupBindings() {
        contactService.$contacts
            .sink { [weak self] contacts in
                guard let self = self, let otherId = self.otherUser?.userId else { return }
                self.isContact = contacts.contains { $0.contactUserId == otherId }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .statusUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                guard let info = notification.object as? [String: Any],
                      let userId = info["userId"] as? UUID,
                      let isOnline = info["is_online"] as? Bool else { return }
                
                // Обновляем только если это наш otherUser
                if userId == self.otherUser?.userId {
                    self.otherUser?.isOnline = isOnline
                    self.objectWillChange.send()
                }
                
                // Также можно обновить статус онлайн для любого участника в списке, но не вызывать loadMembers()
                if let index = self.activeMembers.firstIndex(where: { $0.userId == userId }) {
                    // Если нужно обновить статус онлайн в списке активных – но у нас нет поля isOnline в ChatMemberItem,
                    // оно есть только в User. Поэтому не трогаем.
                }
            }
            .store(in: &cancellables)
    }

    func loadMembers() {
        guard !isDeleting else { return }
        isLoading = true
        Task {
            do {
                let variables = ["chatId": chat.id.uuidString]
                let response: ChatMembersResponse = try await graphQL.perform(
                    query: GraphQLQueries.getChatMembers,
                    variables: variables,
                    responseType: ChatMembersResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                let fetched = response.chat.members
                // ❗️ Исключаем статус "left" – таких участников не показываем вообще
                await MainActor.run {
                    self.allMembers = fetched.filter { $0.status != "left" }
                    if let currentUserId = AppState.shared.currentUser?.userId,
                       let current = fetched.first(where: { $0.userId == currentUserId }) {
                        self.currentUserRole = current.role ?? "member"
                    } else {
                        self.currentUserRole = "member"
                    }
                    self.isLoading = false
                }
                if chat.isPrivate {
                    await loadOtherUser()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func isUserInChat(_ userId: UUID) -> Bool {
        return activeMembers.contains(where: { $0.userId == userId })
    }

    func addUserToChat(_ userId: UUID) async -> Bool {
        do {
            try await ChatService.shared.addChatMember(chatId: chat.id, userId: userId)
            await loadMembers()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func loadOtherUser() async {
        guard let currentUserId = AppState.shared.currentUser?.userId else { return }
        let otherId = activeMembers.first(where: { $0.userId != currentUserId })?.userId
        guard let otherId = otherId else { return }
        do {
            let user = try await UserService.shared.getUser(userId: otherId)
            await MainActor.run {
                self.otherUser = user
                self.isContact = contactService.isContact(userId: otherId)
            }
        } catch {
            print("Failed to load other user: \(error)")
        }
    }

    // MARK: - Actions
    func updateMemberRole(userId: UUID, role: String) async -> Bool {
        do {
            try await ChatService.shared.updateMemberRole(chatId: chat.id, userId: userId, role: role)
            await loadMembers()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func kickMember(userId: UUID) async -> Bool {
        do {
            try await ChatService.shared.kickMember(chatId: chat.id, userId: userId)
            await loadMembers()   // обновляем список
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func banMember(userId: UUID, until: Date?) async -> Bool {
        do {
            try await ChatService.shared.banMember(chatId: chat.id, userId: userId, bannedUntil: until)
            await loadMembers()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func unbanMember(userId: UUID) async -> Bool {
        do {
            try await ChatService.shared.unbanMember(chatId: chat.id, userId: userId)
            await loadMembers()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func leaveChat() async -> Bool {
        do {
            try await ChatService.shared.leaveChat(chatId: chat.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteChat() async -> Bool {
        isDeleting = true
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        do {
            try await ChatService.shared.deleteChat(chatId: chat.id)
            return true
        } catch {
            isDeleting = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    func generateInviteLink() async -> String? {
        do {
            return try await ChatService.shared.generateInviteLink(chatId: chat.id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
