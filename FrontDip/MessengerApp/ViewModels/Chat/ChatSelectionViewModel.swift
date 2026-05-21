import Foundation
import Combine

class ChatSelectionViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let graphQL = GraphQLClient.shared
    let contact: Contact  // теперь Contact содержит contact_user_id и т.д.
    
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
                let loadedChats = response.chat.list.map { chatResponse in
                    Chat(
                        chat_id: chatResponse.chat_id,
                        chat_type: chatResponse.chat_type,
                        name: chatResponse.name,
                        description: chatResponse.description,
                        avatar_url: chatResponse.avatar_url,
                        creator_id: chatResponse.creator_id,
                        is_public: chatResponse.is_public,
                        max_members: 30,
                        created_at: chatResponse.created_at,
                        updated_at: chatResponse.updated_at,
                        last_activity_at: chatResponse.created_at,       // или другое поле
                        visibility: "PRIVATE",                          // дефолт или из chatResponse
                        join_policy: "INVITE_ONLY",                     // дефолт или из chatResponse
                        members_count: chatResponse.members_count ?? 0, // если есть
                        last_message_preview: chatResponse.last_message_preview == nil ? nil :
                            MessagePreview(
                                message_id: Int64(chatResponse.last_message_preview!.message_id),
                                sender_id: UUID(uuidString: chatResponse.last_message_preview!.sender_id) ?? UUID(),
                                type: chatResponse.last_message_preview!.type,
                                text_preview: chatResponse.last_message_preview!.text_preview,
                                created_at: chatResponse.last_message_preview!.created_at,
                                is_deleted: chatResponse.last_message_preview!.is_deleted
                            )
                    )
                }
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
            let variables = ["chat_id": chat.chat_id.uuidString]
            let response: ChatMembersResponse = try await graphQL.perform(
                query: GraphQLQueries.getChatMembers,
                variables: variables,
                responseType: ChatMembersResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            return response.chat.members.contains { $0.user_id == contact.contact_user_id }
        } catch {
            return false
        }
    }
    
    func addContactToChat(_ chat: Chat) async -> Bool {
        let variables: [String: Any] = [
            "chatId": chat.chat_id.uuidString,
            "userId": contact.contact_user_id.uuidString
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
