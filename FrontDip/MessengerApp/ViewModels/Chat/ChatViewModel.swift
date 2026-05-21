import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessageText = ""
    @Published var isLoading = false

    let chat: Chat
    private let graphQL = GraphQLClient.shared
    private var cancellables = Set<AnyCancellable>()

    init(chat: Chat) {
        self.chat = chat
        setupNotifications()
        loadMessages()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .newMessageReceived)
            .sink { [weak self] notification in
                if let msg = notification.object as? Message, msg.chat_id == self?.chat.id {
                    self?.addMessage(msg)
                }
            }
            .store(in: &cancellables)
    }

    func loadMessages() {
        Task {
            await MainActor.run { isLoading = true }
            do {
                let response: ListMessagesResponse = try await graphQL.perform(
                    query: GraphQLQueries.listMessages,
                    variables: ["chat_id": chat.id.uuidString],
                    responseType: ListMessagesResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                let loadedMessages = response.message.list_messages.map { gqlMsg in
                    Message(
                        message_id: Int64(gqlMsg.message_id),
                        chat_id: gqlMsg.chat_id,
                        sender_id: gqlMsg.sender_id,
                        reply_to_id: nil,
                        content: gqlMsg.content,
                        type: gqlMsg.type,
                        created_at: gqlMsg.created_at,
                        updated_at: gqlMsg.updated_at,
                        deleted_at: nil,
                        is_edited: gqlMsg.is_edited
                    )
                }
                await MainActor.run {
                    self.messages = loadedMessages.sorted(by: { $0.created_at < $1.created_at })
                    self.isLoading = false
                }
            } catch {
                print("Load messages error: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    func sendMessage() {
        let content = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, let currentUserId = AppState.shared.currentUser?.id else { return }

        Task {
            do {
                let response: SendMessageResponse = try await graphQL.perform(
                    query: GraphQLQueries.sendMessage,
                    variables: [
                        "chat_id": chat.id.uuidString,
                        "content": content
                    ],
                    responseType: SendMessageResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                let gqlMsg = response.message.send_message
                let newMsg = Message(
                    message_id: Int64(gqlMsg.message_id),
                    chat_id: gqlMsg.chat_id,
                    sender_id: gqlMsg.sender_id,
                    reply_to_id: nil,
                    content: gqlMsg.content,
                    type: gqlMsg.type,
                    created_at: gqlMsg.created_at,
                    updated_at: gqlMsg.updated_at,
                    deleted_at: nil,
                    is_edited: gqlMsg.is_edited
                )
                await MainActor.run {
                    self.messages.append(newMsg)
                    self.newMessageText = ""
                }
            } catch {
                print("Send error: \(error)")
            }
        }
    }

    private func addMessage(_ message: Message) {
        DispatchQueue.main.async {
            if !self.messages.contains(where: { $0.id == message.id }) {
                self.messages.append(message)
                self.messages.sort(by: { $0.created_at < $1.created_at })
            }
        }
    }

    func isCurrentUser(senderId: UUID) -> Bool {
        return senderId == AppState.shared.currentUser?.id
    }
}
