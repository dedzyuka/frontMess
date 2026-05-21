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
                if let msg = notification.object as? Message, msg.chatId == self?.chat.id {
                    self?.addMessage(msg)
                }
            }
            .store(in: &cancellables)
    }
    
    func loadMessages() {
        Task {
            await MainActor.run { isLoading = true }
            do {
                let variables: [String: Any] = ["chatId": chat.id.uuidString]
                let response: ListMessagesResponse = try await graphQL.perform(
                    query: GraphQLQueries.listMessages,
                    variables: variables,
                    responseType: ListMessagesResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                let loadedMessages = response.message.listMessages.sorted(by: { $0.createdAt < $1.createdAt })
                await MainActor.run {
                    self.messages = loadedMessages
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
        guard !content.isEmpty, let currentUserId = AppState.shared.currentUser?.userId else { return }
        
        Task {
            do {
                let variables: [String: Any] = [
                    "chatId": chat.id.uuidString,
                    "content": content
                ]
                let response: SendMessageResponse = try await graphQL.perform(
                    query: GraphQLQueries.sendMessage,
                    variables: variables,
                    responseType: SendMessageResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                let newMsg = response.message.sendMessage
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
                self.messages.sort(by: { $0.createdAt < $1.createdAt })
            }
        }
    }
    
    func isCurrentUser(senderId: UUID) -> Bool {
        return senderId == AppState.shared.currentUser?.userId
    }
}
