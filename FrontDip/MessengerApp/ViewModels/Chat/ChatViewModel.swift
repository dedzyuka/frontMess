import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessage = ""
    @Published var isLoading = false
    
    private let messageService = MessageService.shared
    private let database = LocalDatabase.shared
    private var cancellables = Set<AnyCancellable>() // ДОБАВЛЯЕМ ЭТУ СТРОКУ
    
    let chat: Chat
    
    init(chat: Chat) {
        self.chat = chat
        setupNotifications()
        loadLocalMessages()
    }
    
    private func setupNotifications() {
        // Подписываемся на новые сообщения
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
        // Загружаем из локальной БД
        messages = database.getMessages(for: chat.id)
            .sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    private func addNewMessage(_ message: Message) {
        DispatchQueue.main.async {
            // Проверяем, нет ли уже такого сообщения
            if !self.messages.contains(where: { $0.id == message.id }) {
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
        
        // Создаем сообщение
        let message = Message(
            id: UUID(),
            chatId: chat.id,
            senderId: currentUser.id,
            content: content,
            type: .text,
            timestamp: Date(),
            isEncrypted: true
        )
        
        // Отправляем через MessageService
        messageService.sendMessage(message, to: chat.id)
        
        // Немедленно добавляем в UI
        addNewMessage(message)
    }
    
    func isCurrentUser(senderId: UUID) -> Bool {
        return senderId == AppState.shared.currentUser?.id
    }
    
}
