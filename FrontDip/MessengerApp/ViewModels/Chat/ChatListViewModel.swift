import Foundation
import Combine

class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let graphQL = GraphQLClient.shared
    
    func loadChats() async {
        await MainActor.run { isLoading = true }
        
        do {
            let response: ListChatsResponse = try await graphQL.perform(
                query: GraphQLQueries.listChats,
                variables: [:],
                responseType: ListChatsResponse.self
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
                    max_members: 200,
                    created_at: chatResponse.created_at,
                    updated_at: chatResponse.updated_at,
                    last_activity_at: chatResponse.created_at,
                    visibility: "PRIVATE",
                    join_policy: "INVITE_ONLY",
                    members_count: chatResponse.members_count,
                    last_message_preview: chatResponse.last_message_preview.map { preview in
                        MessagePreview(
                            message_id: Int64(preview.message_id), // если preview.message_id Int, конвертируем
                            sender_id: UUID(uuidString: preview.sender_id) ?? UUID(),
                            type: preview.type,
                            text_preview: preview.text_preview,
                            created_at: preview.created_at,
                            is_deleted: preview.is_deleted
                        )
                    }
                )
            }
            await MainActor.run {
                self.chats = loadedChats
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка загрузки чатов: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
