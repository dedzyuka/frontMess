import Foundation
import Combine

class ChatSelectionViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let graphQL = GraphQLClient.shared
    let contact: Contact
    
    init(contact: Contact) {
        self.contact = contact
    }
    
    func loadChats() {
        Task {
            await MainActor.run { isLoading = true }
            do {
                let response: ListChatsResponse = try await graphQL.perform(
                    query: GraphQLQueries.listChats,
                    variables: [:],
                    responseType: ListChatsResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                let loadedChats = response.chat.list
                await MainActor.run {
                    self.chats = loadedChats
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func isContactInChat(_ chat: Chat) async -> Bool {
        do {
            let variables = ["chatId": chat.id.uuidString]
            let response: ChatMembersResponse = try await graphQL.perform(
                query: GraphQLQueries.getChatMembers,
                variables: variables,
                responseType: ChatMembersResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            return response.chat.members.contains { $0.userId == contact.contactUserId }
        } catch {
            return false
        }
    }
    
    func addContactToChat(_ chat: Chat) async -> Bool {
        let variables: [String: Any] = [
            "chatId": chat.id.uuidString,
            "userId": contact.contactUserId.uuidString
        ]
        do {
            let _: AddChatMemberResponse = try await graphQL.perform(
                query: GraphQLQueries.addChatMember,
                variables: variables,
                responseType: AddChatMemberResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            return true
        } catch {
            return false
        }
    }
}
