import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessage = ""
    @Published var isLoading = false
    
    let chat: Chat
    private let messageService = MessageService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(chat: Chat) {
        self.chat = chat
        setupNotifications()
        loadMessages()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .newMessageReceived)
            .sink { [weak self] notification in
                if let message = notification.object as? Message, message.chat_id == self?.chat.id {
                    self?.addNewMessage(message)
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadMessages() {
        Task {
            await MainActor.run { isLoading = true }
            do {
                let response: ListMessagesResponse = try await GraphQLClient.shared.perform(
                    query: GraphQLQueries.listMessages,
                    variables: ["chat_id": chat.id.uuidString],
                    responseType: ListMessagesResponse.self
                )
                let loadedMessages = response.message.list_messages.map { msgResponse in
                    Message(
                        message_id: Int64(msgResponse.message_id),
                        chat_id: msgResponse.chat_id,
                        sender_id: msgResponse.sender_id,
                        reply_to_id: nil,
                        content: msgResponse.content,
                        type: msgResponse.type,
                        created_at: msgResponse.created_at,
                        updated_at: msgResponse.updated_at,
                        deleted_at: nil,
                        is_edited: msgResponse.is_edited
                    )
                }
                await MainActor.run {
                    self.messages = loadedMessages.sorted(by: { $0.created_at < $1.created_at })
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func addNewMessage(_ message: Message) {
        DispatchQueue.main.async {
            // обновление self.messages
            if !self.messages.contains(where: { $0.id == message.id }) {
                self.messages.append(message)
                self.messages.sort(by: { $0.created_at < $1.created_at })
            }
        }
    }
    
    func sendMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUser = AppState.shared.currentUser else { return }
        
        let content = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        newMessage = ""
        
        Task {
            do {
                let response: SendMessageResponse = try await GraphQLClient.shared.perform(
                    query: GraphQLQueries.sendMessage,
                    variables: [
                        "chat_id": chat.id.uuidString,
                        "content": content
                    ],
                    responseType: SendMessageResponse.self
                )
                let sentMessage = response.message.send_message
                let message = Message(
                    message_id: Int64(sentMessage.message_id),
                    chat_id: sentMessage.chat_id,
                    sender_id: sentMessage.sender_id,
                    reply_to_id: nil,
                    content: sentMessage.content,
                    type: sentMessage.type,
                    created_at: sentMessage.created_at,
                    updated_at: sentMessage.updated_at,
                    deleted_at: nil,
                    is_edited: sentMessage.is_edited
                )
                addNewMessage(message)
            } catch {
                print("Send message error: \(error)")
            }
        }
    }
    
    func isCurrentUser(senderId: UUID) -> Bool {
        return senderId == AppState.shared.currentUser?.id
    }
}
