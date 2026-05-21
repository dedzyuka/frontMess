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
        loadContacts()
        loadPendingRequests()
    }
    
    // MARK: - GraphQL
    
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
            // Преобразуем ContactResponseData в Contact
            return response.contact.list.map { apiContact in
                Contact(
                    id: UUID(),   // локальный ID, можно сгенерировать
                    user_id: apiContact.user_id,
                    contact_user_id: apiContact.contact_user_id,
                    status: apiContact.status,
                    created_at: apiContact.created_at,
                    updated_at: apiContact.updated_at,
                    contact_user: apiContact.contact_user.map { contactUserInfo in
                        User(
                            user_id: contactUserInfo.user_id,
                            nick_name: contactUserInfo.nick_name,
                            first_name: nil,
                            last_name: nil,
                            middle_name: nil,
                            email: nil,
                            phone: nil,
                            avatar_url: contactUserInfo.avatar_url,
                            bio: nil,
                            last_seen: nil,
                            is_online: false,
                            status: "active",
                            email_verified: false,
                            phone_verified: false,
                            is_admin: false,
                            created_at: Date(),
                            updated_at: Date()
                        )
                    }
                )
            }
        }
        
        func fetchIncomingRequests() async throws -> [Contact] {
            let response: ListContactsResponse = try await graphQL.perform(
                query: GraphQLQueries.incomingRequests,
                variables: [:],
                responseType: ListContactsResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            return response.contact.list.map { apiContact in
                Contact(
                    id: UUID(),
                    user_id: apiContact.user_id,
                    contact_user_id: apiContact.contact_user_id,
                    status: apiContact.status,
                    created_at: apiContact.created_at,
                    updated_at: apiContact.updated_at,
                    contact_user: apiContact.contact_user.map { contactUserInfo in
                        User(
                            user_id: contactUserInfo.user_id,
                            nick_name: contactUserInfo.nick_name,
                            first_name: nil, last_name: nil, middle_name: nil,
                            email: nil, phone: nil,
                            avatar_url: contactUserInfo.avatar_url,
                            bio: nil, last_seen: nil, is_online: false,
                            status: "active", email_verified: false, phone_verified: false,
                            is_admin: false, created_at: Date(), updated_at: Date()
                        )
                    }
                )
            }
        }
    
    // MARK: - Local
    
    func loadContacts() {
        Task {
            do {
                let fetched = try await fetchContacts()
                await MainActor.run { self.contacts = fetched }
            } catch {
                print("Failed to load contacts: \(error)")
            }
        }
    }
    
    func loadPendingRequests() {
        Task {
            do {
                let fetched = try await fetchIncomingRequests()
                await MainActor.run { self.pendingRequests = fetched.filter { $0.status == "pending" } }
            } catch {
                print("Failed to load pending: \(error)")
            }
        }
    }
    
    func syncContacts() { loadContacts() }
    func syncPendingRequests() { loadPendingRequests() }
    
    func isContact(userId: UUID) -> Bool {
           contacts.contains(where: { $0.contact_user_id == userId })
       }
       
       func sendContactRequest(to user: UserPublicResponse) {
           guard let currentUser = AppState.shared.currentUser else { return }
           guard currentUser.id != user.user_id else { return }
           guard !isContact(userId: user.user_id) else { return }
           
           Task {
               do {
                   _ = try await sendContactRequest(to: user.user_id.uuidString)
                   await MainActor.run {
                       NotificationService.shared.showSuccess("Запрос отправлен \(user.nick_name)")
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
                   _ = try await acceptContact(contactUserId: request.contact_user_id.uuidString)
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
                   _ = try await removeContact(userId: request.contact_user_id.uuidString)
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
       
       func searchUsers(query: String) async throws -> [UserPublicResponse] {
           let variables: [String: Any] = ["query": query]
           let response: SearchUsersResponse = try await graphQL.perform(
               query: GraphQLQueries.searchUsers,
               variables: variables,
               responseType: SearchUsersResponse.self,
               authToken: TokenManager.shared.accessToken
           )
           return response.user.search.map { apiUser in
               UserPublicResponse(
                   user_id: apiUser.user_id,
                   nick_name: apiUser.nick_name,
                   avatar_url: apiUser.avatar_url,
                   is_online: apiUser.is_online
               )
           }
       }
   }
