import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessage = ""
    @Published var isLoading = false
    
    private let messageService = MessageService.shared
    private let database = LocalDatabase.shared
    private var cancellables = Set<AnyCancellable>()
    
    let chat: Chat
    
    init(chat: Chat) {
        self.chat = chat
        setupNotifications()
        loadLocalMessages()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .newMessageReceived)
            .sink { [weak self] notification in
                if let message = notification.object as? Message,
                   message.chatId == self?.chat.id {
                    self?.addNewMessage(message)
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadLocalMessages() {
        messages = database.getMessages(for: chat.id)
            .sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    private func addNewMessage(_ message: Message) {
        DispatchQueue.main.async {
            if let msgId = message.id, !self.messages.contains(where: { $0.id == msgId }) {
                self.messages.append(message)
                self.messages.sort(by: { $0.timestamp < $1.timestamp })
            } else if message.id == nil {
                self.messages.append(message)
                self.messages.sort(by: { $0.timestamp < $1.timestamp })
            }
        }
    }
    
    func sendMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUser = AppState.shared.currentUser else {
            return
        }
        
        let content = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        newMessage = ""
        
        let message = Message(
            id: UUID(),
            chatId: chat.id,
            senderId: currentUser.id,
            content: content,
            type: .text,
            timestamp: Date(),
            isEncrypted: true
        )
        
        messageService.sendMessage(message, to: chat.id)
        addNewMessage(message)
    }
    
    func isCurrentUser(senderId: UUID) -> Bool {
        return senderId == AppState.shared.currentUser?.id
    }
    
    func loadHistory() async {
        await MainActor.run { isLoading = true }
        // TODO: GraphQL запрос истории сообщений
        await MainActor.run { isLoading = false }
    }
}
