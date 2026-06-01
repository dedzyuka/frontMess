import Foundation
import Combine

class ContactService: ObservableObject {
    static let shared = ContactService()
    
    @Published var contacts: [Contact] = []
    @Published var pendingRequests: [Contact] = []
    @Published var outgoingRequests: [Contact] = []
    @Published var isLoading = false
    
    private let graphQL = GraphQLClient.shared
    private let database = LocalDatabase.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .userLoggedIn)
            .sink { [weak self] _ in
                self?.loadContacts()
                self?.loadPendingRequests()
                self?.loadOutgoingRequests()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - GraphQL Requests
    
    func sendContactRequest(to userId: String) async throws -> Bool {
        guard let currentUserId = AppState.shared.currentUser?.userId.uuidString else {
            throw NSError(domain: "ContactService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        guard currentUserId != userId else {
            throw NSError(domain: "ContactService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot add yourself as contact"])
        }
        let variables: [String: Any] = ["contactUserId": userId]
        
        struct SimpleResponse: Decodable {
            let contact: SimpleWrapper
            struct SimpleWrapper: Decodable {
                let add: SimpleContact
                struct SimpleContact: Decodable {
                    let userId: String
                    let contactUserId: String
                    let status: String
                    let createdAt: String
                }
            }
        }
        
        let _: SimpleResponse = try await graphQL.perform(
            query: GraphQLQueries.addContact,
            variables: variables,
            responseType: SimpleResponse.self,
            authToken: TokenManager.shared.accessToken
        )
        return true
    }
    
    func acceptContact(contactUserId: String) async throws -> Bool {
        let variables: [String: Any] = ["contactUserId": contactUserId]
        let _: AcceptContactResponse = try await graphQL.perform(
            query: GraphQLQueries.acceptContact,
            variables: variables,
            responseType: AcceptContactResponse.self,
            authToken: TokenManager.shared.accessToken
        )
        return true
    }
    
    func removeContact(userId: String) async throws -> Bool {
        let variables: [String: Any] = ["contactUserId": userId]
        let _: RemoveContactResponse = try await graphQL.perform(
            query: GraphQLQueries.removeContact,
            variables: variables,
            responseType: RemoveContactResponse.self,
            authToken: TokenManager.shared.accessToken
        )
        return true
    }
    
    func fetchContacts(status: String? = "accepted") async throws -> [Contact] {
        var variables: [String: Any] = [:]
        if let status = status { variables["status"] = status }
        let response: ListContactsResponse = try await graphQL.perform(
            query: GraphQLQueries.listContacts,
            variables: variables,
            responseType: ListContactsResponse.self,
            authToken: TokenManager.shared.accessToken
        )
        return response.contact.list
    }
    
    func fetchIncomingRequests() async throws -> [Contact] {
        let response: IncomingContactsResponse = try await graphQL.perform(
            query: GraphQLQueries.incomingRequests,
            variables: [:],
            responseType: IncomingContactsResponse.self,
            authToken: TokenManager.shared.accessToken
        )
        return response.contact.incoming
    }
    
    func searchUsers(query: String) async throws -> [UserPublicResponse] {
        let variables: [String: Any] = ["query": query]
        let response: SearchUsersResponse = try await graphQL.perform(
            query: GraphQLQueries.searchUsers,
            variables: variables,
            responseType: SearchUsersResponse.self,
            authToken: TokenManager.shared.accessToken
        )
        return response.user.search
    }
    
    // MARK: - Local Data Management
    
    func loadContacts() {
        guard TokenManager.shared.accessToken != nil else { return }
        Task {
            do {
                let fetched = try await fetchContacts(status: "accepted")
                await MainActor.run {
                    self.contacts = fetched
                    for contact in fetched {
                        _ = LocalDatabase.shared.saveContact(contact)
                    }
                }
            } catch {
                print("Failed to load contacts: \(error)")
                await MainActor.run { self.contacts = [] }
            }
        }
    }
    
    func loadPendingRequests() {
        guard TokenManager.shared.accessToken != nil else { return }
        Task {
            do {
                let fetched = try await fetchIncomingRequests()
                let pending = fetched.filter { $0.status.lowercased() == "pending" }
                await MainActor.run {
                    self.pendingRequests = pending
                    for request in pending {
                        _ = LocalDatabase.shared.saveContact(request)
                    }
                }
            } catch {
                print("Failed to load pending requests: \(error)")
                await MainActor.run { self.pendingRequests = [] }
            }
        }
    }
    
    func loadOutgoingRequests() {
        guard TokenManager.shared.accessToken != nil else { return }
        Task {
            do {
                let fetched = try await fetchContacts(status: "pending")
                let pendingOutgoing = fetched.filter { $0.status.lowercased() == "pending" }
                await MainActor.run {
                    self.outgoingRequests = pendingOutgoing
                }
            } catch {
                print("Failed to load outgoing requests: \(error)")
                await MainActor.run { self.outgoingRequests = [] }
            }
        }
    }
    
    // MARK: - Sync Helpers
    
    func syncContacts() { loadContacts() }
    func syncPendingRequests() async {
        guard TokenManager.shared.accessToken != nil else { return }
        do {
            let fetched = try await fetchIncomingRequests()
            let pending = fetched.filter { $0.status.lowercased() == "pending" }
            await MainActor.run { self.pendingRequests = pending }
        } catch {
            print("Sync pending failed: \(error)")
        }
    }
    func syncOutgoingRequests() async {
        guard TokenManager.shared.accessToken != nil else { return }
        do {
            let fetched = try await fetchContacts(status: "pending")
            let pendingOutgoing = fetched.filter { $0.status.lowercased() == "pending" }
            await MainActor.run { self.outgoingRequests = pendingOutgoing }
        } catch {
            print("Sync outgoing failed: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    func isContact(userId: UUID) -> Bool {
        return contacts.contains(where: { $0.contactUserId == userId })
    }
    
    func getContactStatus(for userId: UUID) -> String? {
        if contacts.contains(where: { $0.contactUserId == userId }) {
            return "accepted"
        }
        if outgoingRequests.contains(where: { $0.contactUserId == userId }) {
            return "pending"
        }
        if pendingRequests.contains(where: { $0.contactUserId == userId }) {
            return "incoming_pending"
        }
        return nil
    }
    
    func sendContactRequest(to user: UserPublicResponse) {
        guard let currentUser = AppState.shared.currentUser else { return }
        guard currentUser.id != user.userId else { return }
        guard getContactStatus(for: user.userId) == nil else { return }
        
        Task {
            do {
                _ = try await sendContactRequest(to: user.userId.uuidString)
                await MainActor.run {
                    self.loadOutgoingRequests()
                    NotificationService.shared.showSuccess("Запрос отправлен \(user.nickName)")
                }
            } catch {
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func acceptContactRequest(_ request: Contact) {
        Task {
            do {
                _ = try await acceptContact(contactUserId: request.userId.uuidString)
                await MainActor.run {
                    self.loadContacts()
                    self.loadPendingRequests()
                    NotificationService.shared.showSuccess("Контакт добавлен")
                }
            } catch {
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func declineContactRequest(_ request: Contact) {
        Task {
            do {
                _ = try await removeContact(userId: request.userId.uuidString)
                await MainActor.run {
                    self.loadPendingRequests()
                    NotificationService.shared.showInfo("Запрос отклонён")
                }
            } catch {
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func removeContact(userId: UUID) {
        Task {
            do {
                _ = try await removeContact(userId: userId.uuidString)
                await MainActor.run {
                    self.loadContacts()
                    self.loadOutgoingRequests()
                    NotificationService.shared.showInfo("Контакт удалён")
                }
            } catch {
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func cancelOutgoingRequest(userId: UUID) {
        Task {
            do {
                _ = try await removeContact(userId: userId.uuidString)
                await MainActor.run {
                    self.loadOutgoingRequests()
                    NotificationService.shared.showInfo("Запрос отменён")
                }
            } catch {
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка: \(error.localizedDescription)")
                }
            }
        }
    }
}
