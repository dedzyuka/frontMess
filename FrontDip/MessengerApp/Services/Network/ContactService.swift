import Foundation
import Combine

// MARK: - SearchResponse (вынесен вне класса для доступности)
struct SearchResponse: Decodable {
    let user: UserSearchResult
}

struct UserSearchResult: Decodable {
    let search: [SearchedUser]
}

struct SearchedUser: Decodable {
    let user_id: String
    let nick_name: String
    let avatar_url: String?
    let is_online: Bool
}

class ContactService: ObservableObject {
    static let shared = ContactService()
    
    @Published var contacts: [Contact] = []
    @Published var pendingRequests: [ContactRequest] = []
    @Published var isLoading = false
    
    private let graphQL = GraphQLClient.shared
    private let database = LocalDatabase.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadContacts()
        loadPendingRequests()
        setupWebSocketHandlers()
    }
    
    // MARK: - GraphQL Mutations & Queries
    
    func sendContactRequest(to userId: String) async throws -> Bool {
        let variables: [String: Any] = ["contactUserId": userId]
        let _: AddContactResponse = try await graphQL.perform(
            query: GraphQLQueries.addContact,
            variables: variables,
            responseType: AddContactResponse.self
        )
        return true
    }
    
    func getPendingRequests() async throws -> [ContactRequest] {
        let variables: [String: Any] = ["status": "pending"]
        let response: ListContactsResponse = try await graphQL.perform(
            query: GraphQLQueries.listContacts,
            variables: variables,
            responseType: ListContactsResponse.self
        )
        return response.contacts.map { apiContact in
            ContactRequest(
                id: UUID(),
                fromUserId: UUID(uuidString: apiContact.contactUserId.uuidString) ?? UUID(),
                fromNickname: apiContact.contactUser?.nickName ?? "",
                fromPublicKey: apiContact.contactUser?.publicKey ?? "",
                status: apiContact.status,
                createdAt: apiContact.createdAt
            )
        }
    }
    
    func respondToContactRequest(requestId: String, status: String) async throws -> Bool {
        let variables: [String: Any] = ["contactUserId": requestId]
        if status == "accepted" {
            let _: AcceptContactResponse = try await graphQL.perform(
                query: GraphQLQueries.acceptContact,
                variables: variables,
                responseType: AcceptContactResponse.self
            )
        } else {
            let _: RemoveContactResponse = try await graphQL.perform(
                query: GraphQLQueries.removeContact,
                variables: variables,
                responseType: RemoveContactResponse.self
            )
        }
        return true
    }
    
    func getContactsFromServer() async throws -> [Contact] {
        let variables: [String: Any] = ["status": "accepted"]
        let response: ListContactsResponse = try await graphQL.perform(
            query: GraphQLQueries.listContacts,
            variables: variables,
            responseType: ListContactsResponse.self
        )
        return response.contacts.map { apiContact in
            let contactUserId = UUID(uuidString: apiContact.contactUserId.uuidString) ?? UUID()
            return Contact(
                id: UUID(),
                userId: contactUserId,
                contactUserId: contactUserId,
                nickname: apiContact.contactUser?.nickName ?? "",
                publicKey: apiContact.contactUser?.publicKey ?? "",
                addedAt: apiContact.createdAt
            )
        }
    }
    
    func removeContactFromServer(userId: String) async throws -> Bool {
        let variables: [String: Any] = ["contactUserId": userId]
        let _: RemoveContactResponse = try await graphQL.perform(
            query: GraphQLQueries.removeContact,
            variables: variables,
            responseType: RemoveContactResponse.self
        )
        return true
    }
    
    // MARK: - Local Database Methods
    
    func loadContacts() {
        contacts = database.getContacts()
    }
    
    func loadPendingRequests() {
        pendingRequests = database.getPendingContactRequests()
    }
    
    func saveContactLocally(_ contact: Contact) -> Bool {
        return database.saveContact(contact)
    }
    
    func saveContactRequestLocally(_ request: ContactRequest) -> Bool {
        return database.saveContactRequest(request)
    }
    
    func updateContactRequestStatusLocally(_ requestId: UUID, status: String) -> Bool {
        return database.updateContactRequestStatus(requestId, status: status)
    }
    
    func removeContactLocally(userId: UUID) -> Bool {
        return database.deleteContact(userId: userId)
    }
    
    // MARK: - Business Logic
    
    func sendContactRequest(to user: UserPublicResponse) {
        guard let currentUser = AppState.shared.currentUser else {
            NotificationService.shared.showError("Текущий пользователь не найден")
            return
        }
        guard currentUser.id != user.user_id else {
            NotificationService.shared.showError("Нельзя отправить запрос самому себе")
            return
        }
        guard !isContact(userId: user.user_id) else {
            NotificationService.shared.showInfo("Пользователь уже в контактах")
            return
        }
        
        Task {
            do {
                // Передаём строку, используя .uuidString
                let success = try await sendContactRequest(to: user.user_id.uuidString)
                if success {
                    let request = ContactRequest(
                        id: UUID(),
                        fromUserId: currentUser.id,
                        fromNickname: currentUser.nickName,
                        fromPublicKey: "",
                        status: "pending",
                        createdAt: Date()
                    )
                    if saveContactRequestLocally(request) {
                        await MainActor.run {
                            loadPendingRequests()
                            NotificationService.shared.showSuccess("Запрос отправлен пользователю \(user.nickname)")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка отправки запроса: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func acceptContactRequest(_ request: ContactRequest) {
        Task {
            do {
                // Преобразуем UUID в String через .uuidString
                let success = try await respondToContactRequest(requestId: request.fromUserId.uuidString, status: "accepted")
                if success && database.updateContactRequestStatus(request.id, status: "accepted") {
                    let contact = Contact(
                        id: UUID(),
                        userId: request.fromUserId,
                        contactUserId: request.fromUserId,
                        nickname: request.fromNickname,
                        publicKey: request.fromPublicKey,
                        addedAt: Date()
                    )
                    if saveContactLocally(contact) {
                        await MainActor.run {
                            loadContacts()
                            loadPendingRequests()
                            NotificationService.shared.showSuccess("Контакт \(request.fromNickname) добавлен")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка принятия запроса: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func declineContactRequest(_ request: ContactRequest) {
        Task {
            do {
                let success = try await respondToContactRequest(requestId: request.fromUserId.uuidString, status: "declined")
                if success && database.updateContactRequestStatus(request.id, status: "declined") {
                    await MainActor.run {
                        loadPendingRequests()
                        NotificationService.shared.showInfo("Запрос отклонен")
                    }
                }
            } catch {
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка отклонения запроса: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func removeContact(userId: UUID) {
        Task {
            do {
                let success = try await removeContactFromServer(userId: userId.uuidString)
                if success && removeContactLocally(userId: userId) {
                    await MainActor.run {
                        loadContacts()
                        NotificationService.shared.showInfo("Контакт удален")
                    }
                }
            } catch {
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка удаления контакта: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func syncContacts() {
        Task {
            do {
                let serverContacts = try await getContactsFromServer()
                for contact in serverContacts {
                    if !isContact(userId: contact.userId) {
                        _ = saveContactLocally(contact)
                    }
                }
                await MainActor.run { loadContacts() }
            } catch {
                print("❌ Ошибка синхронизации контактов: \(error)")
            }
        }
    }
    
    func syncPendingRequests() {
        Task {
            do {
                let serverRequests = try await getPendingRequests()
                for request in serverRequests {
                    if !pendingRequests.contains(where: { $0.id == request.id }) {
                        _ = saveContactRequestLocally(request)
                    }
                }
                await MainActor.run { loadPendingRequests() }
            } catch {
                print("❌ Ошибка синхронизации запросов: \(error)")
            }
        }
    }
    
    func isContact(userId: UUID) -> Bool {
        return contacts.contains(where: { $0.userId == userId })
    }
    
    // MARK: - Search Users
    func searchUsers(query: String) async throws -> [UserPublicResponse] {
        let searchQuery = """
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
        let variables = ["query": query]
        let response: SearchResponse = try await graphQL.perform(
            query: searchQuery,
            variables: variables,
            responseType: SearchResponse.self
        )
        return response.user.search.map { apiUser in
            UserPublicResponse(
                user_id: UUID(uuidString: apiUser.user_id)!,
                nickname: apiUser.nick_name,
                public_key: ""
            )
        }
    }
    
    // MARK: - WebSocket Handlers
    private func setupWebSocketHandlers() {
        NotificationCenter.default.publisher(for: .newContactRequest)
            .sink { [weak self] notification in
                if let request = notification.object as? ContactRequest {
                    self?.handleIncomingContactRequest(request)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .contactRequestAccepted)
            .sink { [weak self] notification in
                if let contact = notification.object as? Contact {
                    self?.handleContactRequestAccepted(contact)
                }
            }
            .store(in: &cancellables)
    }
    
    func handleIncomingContactRequest(_ request: ContactRequest) {
        guard let currentUserId = AppState.shared.currentUser?.id else { return }
        guard request.fromUserId != currentUserId else { return }
        guard !isContact(userId: request.fromUserId) else { return }
        guard !pendingRequests.contains(where: { $0.fromUserId == request.fromUserId && $0.status == "pending" }) else { return }
        
        if saveContactRequestLocally(request) {
            loadPendingRequests()
            NotificationService.shared.showInfo("Новый запрос на контакт от \(request.fromNickname)")
        }
    }
    
    func handleContactRequestAccepted(_ contact: Contact) {
        if saveContactLocally(contact) {
            loadContacts()
            if let request = pendingRequests.first(where: { $0.fromUserId == contact.userId }) {
                _ = database.updateContactRequestStatus(request.id, status: "accepted")
                loadPendingRequests()
            }
            NotificationService.shared.showSuccess("\(contact.nickname) принял(а) ваш запрос")
        }
    }
}
