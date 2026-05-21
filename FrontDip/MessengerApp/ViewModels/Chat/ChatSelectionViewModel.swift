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
                // ⬅️ ЭТА СТРОКА БЫЛА ПРОПУЩЕНА
                let response: ListChatsResponse = try await graphQL.perform(
                    query: GraphQLQueries.listChats,
                    variables: [:],
                    responseType: ListChatsResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                
                // Теперь response доступен
                let loadedChats = response.chat.list.map { chatResponse in
                    let lastMessagePreview = chatResponse.last_message.flatMap { msg -> MessagePreview? in
                        guard let senderId = UUID(uuidString: msg.sender_id.uuidString) else { return nil }
                        return MessagePreview(
                            message_id: msg.message_id,
                            sender_id: senderId,
                            type: msg.type,
                            text_preview: msg.content,
                            created_at: msg.created_at,
                            is_deleted: false
                        )
                    }
                    
                    return Chat(
                        chat_id: chatResponse.chat_id,
                        chat_type: chatResponse.chat_type,
                        name: chatResponse.name,
                        description: chatResponse.description,
                        avatar_url: chatResponse.avatar_url,
                        creator_id: chatResponse.creator_id,
                        is_public: chatResponse.is_public,
                        max_members: chatResponse.max_members ?? 200,
                        created_at: chatResponse.created_at,
                        updated_at: nil,
                        last_activity_at: chatResponse.created_at,
                        visibility: "PRIVATE",
                        join_policy: "INVITE_ONLY",
                        members_count: chatResponse.members_count,
                        last_message_preview: lastMessagePreview
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
