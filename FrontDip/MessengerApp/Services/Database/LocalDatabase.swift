import Foundation
import SQLite

class LocalDatabase {
    static let shared = LocalDatabase()
    
    private var db: Connection?
    private let messagesTable = Table("messages")
    private let chatsTable = Table("chats")
    private let contactsTable = Table("contacts")
    private let contactRequestsTable = Table("contact_requests")
    
    // MARK: - Columns for messages
    private let id = Expression<UUID>("id")
    private let chatId = Expression<UUID>("chat_id")
    private let senderId = Expression<UUID>("sender_id")
    private let content = Expression<String>("content")
    private let type = Expression<String>("type")
    private let timestamp = Expression<Date>("timestamp")
    private let isEncrypted = Expression<Bool>("is_encrypted")
    private let isSent = Expression<Bool>("is_sent")
    private let isDelivered = Expression<Bool>("is_delivered")
    
    // MARK: - Columns for chats
    private let chatPrimaryId = Expression<UUID>("id")
    private let chatName = Expression<String>("name")
    private let chatCreatorId = Expression<UUID>("creator_id")
    private let chatCreatedAt = Expression<Date>("created_at")
    private let chatMemberCount = Expression<Int>("member_count")
    
    // MARK: - Columns for contacts
    private let contactId = Expression<UUID>("id")
    private let contactUserId = Expression<UUID>("user_id")           // владелец (текущий пользователь)
    private let contactContactUserId = Expression<UUID>("contact_user_id") // ID другого пользователя
    private let contactNickname = Expression<String>("nickname")
    private let contactPublicKey = Expression<String>("public_key")
    private let contactAddedAt = Expression<Date>("added_at")
    
    // MARK: - Columns for contact_requests
    private let requestId = Expression<UUID>("id")
    private let fromUserId = Expression<UUID>("from_user_id")
    private let fromNickname = Expression<String>("from_nickname")
    private let fromPublicKey = Expression<String>("from_public_key")
    private let requestStatus = Expression<String>("status")
    private let requestCreatedAt = Expression<Date>("created_at")
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            db = try Connection("\(path)/messenger.sqlite3")
            print("📊 Database at: \(path)/messenger.sqlite3")
            
            try db?.run(messagesTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(chatId)
                t.column(senderId)
                t.column(content)
                t.column(type)
                t.column(timestamp)
                t.column(isEncrypted)
                t.column(isSent, defaultValue: false)
                t.column(isDelivered, defaultValue: false)
            })
            
            try db?.run(chatsTable.create(ifNotExists: true) { t in
                t.column(chatPrimaryId, primaryKey: true)
                t.column(chatName)
                t.column(chatCreatorId)
                t.column(chatCreatedAt)
                t.column(chatMemberCount)
            })
            
            try db?.run(contactsTable.create(ifNotExists: true) { t in
                t.column(contactId, primaryKey: true)
                t.column(contactUserId)
                t.column(contactContactUserId)
                t.column(contactNickname)
                t.column(contactPublicKey)
                t.column(contactAddedAt)
            })
            
            try db?.run(contactRequestsTable.create(ifNotExists: true) { t in
                t.column(requestId, primaryKey: true)
                t.column(fromUserId)
                t.column(fromNickname)
                t.column(fromPublicKey)
                t.column(requestStatus)
                t.column(requestCreatedAt)
            })
            
            print("✅ Database setup complete")
        } catch {
            print("❌ DB setup error: \(error)")
        }
    }
    
    // MARK: - Chat Operations
    func saveOrUpdateChat(_ chat: Chat) -> Bool {
        guard let db = db else { return false }
        do {
            let existingChat = chatsTable.filter(chatPrimaryId == chat.id)
            let count = try db.scalar(existingChat.count)
            if count > 0 {
                try db.run(existingChat.update(
                    chatName <- (chat.name ?? ""),
                    chatCreatorId <- (chat.creatorId ?? UUID()),
                    chatCreatedAt <- chat.createdAt,
                    chatMemberCount <- chat.membersCount
                ))
            } else {
                try db.run(chatsTable.insert(
                    chatPrimaryId <- chat.id,
                    chatName <- (chat.name ?? ""),
                    chatCreatorId <- (chat.creatorId ?? UUID()),
                    chatCreatedAt <- chat.createdAt,
                    chatMemberCount <- chat.membersCount
                ))
            }
            return true
        } catch {
            print("❌ Save/update chat error: \(error)")
            return false
        }
    }
    
    func getChats() -> [Chat] {
        guard let db = db else { return [] }
        do {
            let query = chatsTable.order(chatCreatedAt.desc)
            var chats: [Chat] = []
            for row in try db.prepare(query) {
                let chat = Chat(
                    id: row[chatPrimaryId],
                    chatType: "group",
                    name: row[chatName],
                    description: nil,
                    avatarUrl: nil,
                    creatorId: row[chatCreatorId],
                    isPublic: false,
                    membersCount: row[chatMemberCount],
                    createdAt: row[chatCreatedAt],
                    updatedAt: row[chatCreatedAt],
                    lastMessagePreview: nil
                )
                chats.append(chat)
            }
            return chats
        } catch {
            print("❌ Get chats error: \(error)")
            return []
        }
    }
    
    func deleteAllChats() {
        guard let db = db else { return }
        do { try db.run(chatsTable.delete()) } catch { print(error) }
    }
    
    // MARK: - Contact Operations
    func saveContact(_ contact: Contact) -> Bool {
        guard let db = db, let currentUserId = AppState.shared.currentUser?.id else { return false }
        do {
            try db.run(contactsTable.insert(
                contactId <- contact.id,
                contactUserId <- currentUserId,
                contactContactUserId <- contact.userId,  // userId контакта
                contactNickname <- contact.nickname,
                contactPublicKey <- contact.publicKey,
                contactAddedAt <- contact.addedAt
            ))
            return true
        } catch {
            print("❌ Save contact error: \(error)")
            return false
        }
    }
    
    func getContacts() -> [Contact] {
        guard let db = db, let currentUserId = AppState.shared.currentUser?.id else { return [] }
        do {
            let query = contactsTable.filter(contactUserId == currentUserId).order(contactAddedAt.desc)
            var contacts: [Contact] = []
            for row in try db.prepare(query) {
                let contact = Contact(
                    id: row[contactId],
                    userId: row[contactContactUserId],
                    contactUserId: row[contactContactUserId],
                    nickname: row[contactNickname],
                    publicKey: row[contactPublicKey],
                    addedAt: row[contactAddedAt]
                )
                contacts.append(contact)
            }
            return contacts
        } catch {
            print("❌ Get contacts error: \(error)")
            return []
        }
    }
    
    func isContact(userId: UUID) -> Bool {
        guard let db = db, let currentUserId = AppState.shared.currentUser?.id else { return false }
        do {
            let query = contactsTable.filter(contactUserId == currentUserId && contactContactUserId == userId)
            let count = try db.scalar(query.count)
            return count > 0
        } catch {
            return false
        }
    }
    
    func deleteContact(userId: UUID) -> Bool {
        guard let db = db, let currentUserId = AppState.shared.currentUser?.id else { return false }
        do {
            let query = contactsTable.filter(contactUserId == currentUserId && contactContactUserId == userId)
            try db.run(query.delete())
            return true
        } catch {
            print("❌ Delete contact error: \(error)")
            return false
        }
    }
    
    // MARK: - Contact Requests Operations
    func saveContactRequest(_ request: ContactRequest) -> Bool {
        guard let db = db else { return false }
        do {
            let existing = contactRequestsTable.filter(requestId == request.id)
            let count = try db.scalar(existing.count)
            if count > 0 {
                try db.run(existing.update(
                    fromUserId <- request.fromUserId,
                    fromNickname <- request.fromNickname,
                    fromPublicKey <- request.fromPublicKey,
                    requestStatus <- request.status,
                    requestCreatedAt <- request.createdAt
                ))
            } else {
                try db.run(contactRequestsTable.insert(
                    requestId <- request.id,
                    fromUserId <- request.fromUserId,
                    fromNickname <- request.fromNickname,
                    fromPublicKey <- request.fromPublicKey,
                    requestStatus <- request.status,
                    requestCreatedAt <- request.createdAt
                ))
            }
            return true
        } catch {
            print("❌ Save contact request error: \(error)")
            return false
        }
    }
    
    func getPendingContactRequests() -> [ContactRequest] {
        guard let db = db, let currentUserId = AppState.shared.currentUser?.id else { return [] }
        do {
            // Входящие запросы: от других пользователей к currentUserId
            let query = contactRequestsTable.filter(requestStatus == "pending" && fromUserId != currentUserId).order(requestCreatedAt.desc)
            var requests: [ContactRequest] = []
            for row in try db.prepare(query) {
                let req = ContactRequest(
                    id: row[requestId],
                    fromUserId: row[fromUserId],
                    fromNickname: row[fromNickname],
                    fromPublicKey: row[fromPublicKey],
                    status: row[requestStatus],
                    createdAt: row[requestCreatedAt]
                )
                requests.append(req)
            }
            return requests
        } catch {
            print("❌ Get pending requests error: \(error)")
            return []
        }
    }
    
    func updateContactRequestStatus(_ requestId: UUID, status: String) -> Bool {
        guard let db = db else { return false }
        do {
            let request = contactRequestsTable.filter(self.requestId == requestId)
            try db.run(request.update(requestStatus <- status))
            return true
        } catch {
            print("❌ Update request status error: \(error)")
            return false
        }
    }
    
    // MARK: - Message Operations
    func saveMessage(_ message: Message) -> Bool {
        guard let db = db, let messageId = message.id else { return false }
        do {
            try db.run(messagesTable.insert(
                id <- messageId,
                chatId <- message.chatId,
                senderId <- message.senderId,
                content <- message.content,
                type <- message.type.rawValue,
                timestamp <- message.timestamp,
                isEncrypted <- message.isEncrypted
            ))
            return true
        } catch {
            print("❌ Save message error: \(error)")
            return false
        }
    }
    
    func getMessages(for chatUUID: UUID) -> [Message] {
        guard let db = db else { return [] }
        do {
            let query = messagesTable.filter(chatId == chatUUID).order(timestamp.asc)
            var messages: [Message] = []
            for row in try db.prepare(query) {
                guard let msgType = MessageType(rawValue: row[type]) else { continue }
                messages.append(Message(
                    id: row[id],
                    chatId: row[chatId],
                    senderId: row[senderId],
                    content: row[content],
                    type: msgType,
                    timestamp: row[timestamp],
                    isEncrypted: row[isEncrypted]
                ))
            }
            return messages
        } catch {
            print("❌ Get messages error: \(error)")
            return []
        }
    }
    
    func deleteMessages(for chatId: UUID) -> Bool {
        guard let db = db else { return false }
        do {
            let query = messagesTable.filter(self.chatId == chatId)
            try db.run(query.delete())
            return true
        } catch {
            print("❌ Delete messages error: \(error)")
            return false
        }
    }
    
    func messageExists(_ messageId: UUID) -> Bool {
        guard let db = db else { return false }
        do {
            let count = try db.scalar(messagesTable.filter(id == messageId).count)
            return count > 0
        } catch {
            return false
        }
    }
    
    func updateMessageStatus(messageId: UUID, isSent: Bool, isDelivered: Bool) -> Bool {
        guard let db = db else { return false }
        do {
            let message = messagesTable.filter(id == messageId)
            try db.run(message.update(
                self.isSent <- isSent,
                self.isDelivered <- isDelivered
            ))
            return true
        } catch {
            print("❌ Update message status error: \(error)")
            return false
        }
    }
    
    // MARK: - Clear Methods
    func clearAllData() {
        guard let db = db else { return }
        do {
            try db.run(messagesTable.delete())
            try db.run(chatsTable.delete())
            try db.run(contactsTable.delete())
            try db.run(contactRequestsTable.delete())
        } catch {
            print("❌ Clear all error: \(error)")
        }
    }
    
    func clearMessages(for chatId: UUID) {
        guard let db = db else { return }
        do {
            try db.run(messagesTable.filter(self.chatId == chatId).delete())
        } catch {
            print("❌ Clear messages error: \(error)")
        }
    }
    
    func recreateTables() {
        db = nil
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let dbPath = "\(path)/messenger.sqlite3"
        try? FileManager.default.removeItem(atPath: dbPath)
        setupDatabase()
    }
}
