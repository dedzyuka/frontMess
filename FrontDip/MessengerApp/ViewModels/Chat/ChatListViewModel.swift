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
                responseType: ListChatsResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            let loadedChats = response.chat.list.map { chatResponse in
                // Преобразуем sender_id из String в UUID
                let lastMessagePreview = chatResponse.last_message_preview.flatMap { preview -> MessagePreview? in
                    guard let senderId = UUID(uuidString: preview.sender_id) else { return nil }
                    return MessagePreview(
                        message_id: Int64(preview.message_id),
                        sender_id: senderId,
                        type: "text",
                        text_preview: preview.text_preview,
                        created_at: preview.created_at,
                        is_deleted: false
                    )
                }
                return Chat(
                    chat_id: chatResponse.chat_id,
                    chat_type: chatResponse.chat_type,
                    name: chatResponse.name,
                    description: nil,
                    avatar_url: nil,
                    creator_id: nil,
                    is_public: false,
                    max_members: 200,
                    created_at: chatResponse.created_at,
                    updated_at: chatResponse.updated_at,
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
                self.errorMessage = "Ошибка загрузки чатов: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func createChat(name: String) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        guard let currentUserId = AppState.shared.currentUser?.id.uuidString else {
            await MainActor.run { errorMessage = "Пользователь не авторизован" }
            return false
        }

        let variables: [String: Any] = [
            "chatType": "group",
            "name": trimmedName,
            "memberIds": [currentUserId],
            "isPublic": false
        ]

        do {
            let response: CreateChatResponse = try await graphQL.perform(
                query: GraphQLQueries.createChat,
                variables: variables,
                responseType: CreateChatResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            let created = response.chat.create
            let newChat = Chat(
                chat_id: created.chat_id,
                chat_type: created.chat_type,
                name: created.name,
                description: nil,
                avatar_url: nil,
                creator_id: UUID(uuidString: currentUserId),
                is_public: false,
                max_members: 200,
                created_at: created.created_at,
                updated_at: created.updated_at,
                last_activity_at: created.created_at,
                visibility: "PRIVATE",
                join_policy: "INVITE_ONLY",
                members_count: created.members_count,
                last_message_preview: nil
            )
            await MainActor.run {
                self.chats.insert(newChat, at: 0)
                self.errorMessage = nil
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка создания чата: \(error.localizedDescription)"
            }
            return false
        }
    }
}
