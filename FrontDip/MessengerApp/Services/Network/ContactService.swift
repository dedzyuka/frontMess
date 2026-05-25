// ./FrontDip/MessengerApp/Services/Network/ContactService.swift

import Foundation
import Combine

class ContactService: ObservableObject {
    static let shared = ContactService()
    
    @Published var contacts: [Contact] = []
    @Published var pendingRequests: [Contact] = []
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
            }
            .store(in: &cancellables)
    }
    
    // MARK: - GraphQL Requests
    
    func sendContactRequest(to userId: String) async throws -> Bool {
        let variables: [String: Any] = ["contactUserId": userId]
        let _: AddContactResponse = try await graphQL.perform(
            query: GraphQLQueries.addContact,
            variables: variables,
            responseType: AddContactResponse.self,
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
                let fetched = try await fetchContacts()
                await MainActor.run {
                    self.contacts = fetched
                    // Сохраняем в БД
                    for contact in fetched {
                        _ = self.database.saveContact(contact)
                    }
                }
            } catch {
                print("Failed to load contacts: \(error)")
                // Загружаем из БД
                let storedContacts = self.database.getContacts()
                await MainActor.run {
                    self.contacts = storedContacts
                }
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
                    // Сохраняем в базу (опционально)
                    for req in pending {
                        let contactRequest = ContactRequest(
                            fromUserId: req.contactUserId,
                            fromNickname: req.contactUser?.nickName ?? "Unknown",
                            fromAvatarUrl: req.contactUser?.avatarUrl,
                            status: req.status,
                            createdAt: req.createdAt
                        )
                        _ = self.database.saveContactRequest(contactRequest)
                    }
                }
            } catch {
                print("Failed to load pending requests: \(error)")
                // Загружаем из локальной БД
                let stored = self.database.getPendingContactRequests()
                await MainActor.run {
                    self.pendingRequests = stored.compactMap { req in
                        Contact(
                            userId: req.fromUserId,
                            contactUserId: req.fromUserId,
                            status: req.status,
                            createdAt: req.createdAt,
                            updatedAt: req.createdAt,
                            contactUser: User(
                                userId: req.fromUserId,
                                nickName: req.fromNickname,
                                firstName: nil,
                                lastName: nil,
                                middleName: nil,
                                email: nil,
                                phone: nil,
                                avatarUrl: req.fromAvatarUrl,
                                bio: nil,
                                lastSeen: nil,
                                isOnline: false,
                                status: nil,
                                emailVerified: nil,
                                phoneVerified: nil,
                                isAdmin: nil,
                                createdAt: nil,
                                updatedAt: nil
                            )
                        )
                    }
                }
            }
        }
    }
    
    func syncContacts() { loadContacts() }
    func syncPendingRequests() { loadPendingRequests() }
    
    // MARK: - Helpers
    
    func isContact(userId: UUID) -> Bool {
        return contacts.contains(where: { $0.contactUserId == userId })
    }
    
    func sendContactRequest(to user: UserPublicResponse) {
        guard let currentUser = AppState.shared.currentUser else { return }
        guard currentUser.id != user.userId else { return }
        guard !isContact(userId: user.userId) else { return }
        
        Task {
            do {
                _ = try await sendContactRequest(to: user.userId.uuidString)
                await MainActor.run {
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
                _ = try await acceptContact(contactUserId: request.contactUserId.uuidString)
                await MainActor.run {
                    loadContacts()
                    loadPendingRequests()
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
                _ = try await removeContact(userId: request.contactUserId.uuidString)
                await MainActor.run {
                    loadPendingRequests()
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
                    loadContacts()
                    NotificationService.shared.showInfo("Контакт удалён")
                }
            } catch {
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка: \(error.localizedDescription)")
                }
            }
        }
    }
}
