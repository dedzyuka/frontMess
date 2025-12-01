import Foundation

struct ChatWithContactInfo: Identifiable {
    let id: UUID
    let chat: Chat
    let isContactInChat: Bool
    
    init(chat: Chat, isContactInChat: Bool) {
        self.id = chat.id
        self.chat = chat
        self.isContactInChat = isContactInChat
    }
}
