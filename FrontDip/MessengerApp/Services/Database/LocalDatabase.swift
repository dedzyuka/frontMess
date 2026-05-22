import Foundation
import SQLite

class LocalDatabase {
    static let shared = LocalDatabase()
    
    private var db: Connection?
    
    // Таблицы
    private let chatsTable = Table("chats")
    private let messagesTable = Table("messages")
    private let contactsTable = Table("contacts")
    private let contactRequestsTable = Table("contact_requests")
    
    // === Chats columns ===
    private let chatId = Expression<UUID>("chat_id")
    private let chatType = Expression<String>("chat_type")
    private let chatName = Expression<String?>("name")
    private let chatDescription = Expression<String?>("description")
    private let chatAvatarUrl = Expression<String?>("avatar_url")
    private let chatCreatorId = Expression<UUID?>("creator_id")
    private let chatIsPublic = Expression<Bool>("is_public")
    private let chatMaxMembers = Expression<Int>("max_members")
    private let chatCreatedAt = Expression<Date>("created_at")
//    private let chatUpdatedAt = Expression<Date?>("updated_at")
//    private let chatLastActivityAt = Expression<Date?>("last_activity_at")
//    private let chatVisibility = Expression<String>("visibility")
//    private let chatJoinPolicy = Expression<String>("join_policy")
    private let chatLastMessageJSON = Expression<String?>("last_message_json")
    private let chatMembersCount = Expression<Int>("members_count")
    
    // Для last_message_preview храним JSON
    private let chatLastMessagePreviewJSON = Expression<String?>("last_message_preview_json")
    
    // === Messages columns ===
    private let msgId = Expression<Int64>("message_id")
    private let msgChatId = Expression<UUID>("chat_id")
    private let msgSenderId = Expression<UUID>("sender_id")
    private let msgReplyToId = Expression<Int64?>("reply_to_id")
    private let msgContent = Expression<String?>("content")
    private let msgType = Expression<String>("type")
    private let msgCreatedAt = Expression<Date>("created_at")
    private let msgUpdatedAt = Expression<Date>("updated_at")
    private let msgDeletedAt = Expression<Date?>("deleted_at")
    private let msgIsEdited = Expression<Bool>("is_edited")
    
    // === Contacts columns ===
    private let contactIdCol = Expression<UUID>("id")
    private let contactUserId = Expression<UUID>("user_id")
    private let contactContactUserId = Expression<UUID>("contact_user_id")
    private let contactStatus = Expression<String>("status")
    private let contactCreatedAt = Expression<Date>("created_at")
    private let contactUpdatedAt = Expression<Date>("updated_at")
    private let contactUserJSON = Expression<String?>("contact_user_json") // запасной
    
    // === Contact Requests columns ===
    private let reqId = Expression<UUID>("id")
    private let reqFromUserId = Expression<UUID>("from_user_id")
    private let reqFromNickname = Expression<String>("from_nickname")
    private let reqFromAvatarUrl = Expression<String?>("from_avatar_url")
    private let reqStatus = Expression<String>("status")
    private let reqCreatedAt = Expression<Date>("created_at")
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            db = try Connection("\(path)/messenger.sqlite3")
            print("✅ Database at \(path)/messenger.sqlite3")
            
            try db?.run(chatsTable.create(ifNotExists: true) { t in
                t.column(chatId, primaryKey: true)
                t.column(chatType)
                t.column(chatName)
                t.column(chatDescription)
                t.column(chatAvatarUrl)
                t.column(chatCreatorId)
                t.column(chatIsPublic)
                t.column(chatMaxMembers)
                t.column(chatCreatedAt)
                t.column(chatMembersCount)
                t.column(chatLastMessageJSON)  // новая колонка
                // остальные (updatedAt, lastActivityAt, visibility, joinPolicy) удалить
            })
            
            try db?.run(messagesTable.create(ifNotExists: true) { t in
                t.column(msgId, primaryKey: true)
                t.column(msgChatId)
                t.column(msgSenderId)
                t.column(msgReplyToId)
                t.column(msgContent)
                t.column(msgType)
                t.column(msgCreatedAt)
                t.column(msgUpdatedAt)
                t.column(msgDeletedAt)
                t.column(msgIsEdited)
            })
            
            try db?.run(contactsTable.create(ifNotExists: true) { t in
                t.column(contactIdCol, primaryKey: true)
                t.column(contactUserId)
                t.column(contactContactUserId)
                t.column(contactStatus)
                t.column(contactCreatedAt)
                t.column(contactUpdatedAt)
                t.column(contactUserJSON)
            })
            
            try db?.run(contactRequestsTable.create(ifNotExists: true) { t in
                t.column(reqId, primaryKey: true)
                t.column(reqFromUserId)
                t.column(reqFromNickname)
                t.column(reqFromAvatarUrl)
                t.column(reqStatus)
                t.column(reqCreatedAt)
            })
            
            print("✅ Tables created")
        } catch {
            print("❌ DB setup error: \(error)")
        }
    }
    
    // MARK: - Chat operations
    func saveOrUpdateChat(_ chat: Chat) -> Bool {
        guard let db = db else { return false }
        do {
            let lastMessageString = chat.lastMessage   // String?
            let existing = chatsTable.filter(chatId == chat.chatId)
            let count = try db.scalar(existing.count)
            if count > 0 {
                try db.run(existing.update(
                    chatType <- chat.chatType,
                    chatName <- chat.name,
                    chatDescription <- chat.description,
                    chatAvatarUrl <- chat.avatarUrl,
                    chatCreatorId <- chat.creatorId,
                    chatIsPublic <- chat.isPublic,
                    chatMaxMembers <- chat.maxMembers,
                    chatCreatedAt <- chat.createdAt,
                    chatMembersCount <- chat.membersCount,
                    chatLastMessageJSON <- lastMessageString
                ))
            } else {
                try db.run(chatsTable.insert(
                    chatId <- chat.chatId,
                    chatType <- chat.chatType,
                    chatName <- chat.name,
                    chatDescription <- chat.description,
                    chatAvatarUrl <- chat.avatarUrl,
                    chatCreatorId <- chat.creatorId,
                    chatIsPublic <- chat.isPublic,
                    chatMaxMembers <- chat.maxMembers,
                    chatCreatedAt <- chat.createdAt,
                    chatMembersCount <- chat.membersCount,
                    chatLastMessageJSON <- lastMessageString
                ))
            }
            return true
        } catch {
            print("❌ saveOrUpdateChat error: \(error)")
            return false
        }
    }
    
    func getChats() -> [Chat] {
        guard let db = db else { return [] }
        do {
            var chats: [Chat] = []
            for row in try db.prepare(chatsTable.order(chatCreatedAt.desc)) {
                let lastMessageString = row[chatLastMessageJSON]  // теперь это String?
                
                let chat = Chat(
                    chatId: row[chatId],
                    chatType: row[chatType],
                    name: row[chatName],
                    description: row[chatDescription],
                    avatarUrl: row[chatAvatarUrl],
                    creatorId: row[chatCreatorId],
                    isPublic: row[chatIsPublic],
                    maxMembers: row[chatMaxMembers],
                    createdAt: row[chatCreatedAt],
                    membersCount: row[chatMembersCount],
                    lastMessage: lastMessageString   // тип String?
                )
                chats.append(chat)
            }
            return chats
        } catch {
            print("❌ getChats error: \(error)")
            return []
        }
    }
    
    func deleteAllChats() {
        guard let db = db else { return }
        do { try db.run(chatsTable.delete()) } catch { print(error) }
    }
    
    // MARK: - Message operations
    func saveMessage(_ message: Message) -> Bool {
        guard let db = db else { return false }
        do {
            try db.run(messagesTable.insert(
                msgId <- message.messageId,
                msgChatId <- message.chatId,
                msgSenderId <- message.senderId,
                msgReplyToId <- message.replyToId,
                msgContent <- message.content,
                msgType <- message.type,
                msgCreatedAt <- message.createdAt,
                msgUpdatedAt <- message.updatedAt,
                msgDeletedAt <- message.deletedAt,
                msgIsEdited <- message.isEdited
            ))
            return true
        } catch {
            print("❌ saveMessage error: \(error)")
            return false
        }
    }
    
    func getMessages(for chatId: UUID) -> [Message] {
        guard let db = db else { return [] }
        do {
            let query = messagesTable.filter(msgChatId == chatId).order(msgCreatedAt.asc)
            var messages: [Message] = []
            for row in try db.prepare(query) {
                let msg = Message(
                    messageId: row[msgId],
                    chatId: row[msgChatId],
                    senderId: row[msgSenderId],
                    replyToId: row[msgReplyToId],
                    content: row[msgContent],
                    type: row[msgType],
                    createdAt: row[msgCreatedAt],
                    updatedAt: row[msgUpdatedAt],
                    deletedAt: row[msgDeletedAt],
                    isEdited: row[msgIsEdited]
                )
                messages.append(msg)
            }
            return messages
        } catch {
            print("❌ getMessages error: \(error)")
            return []
        }
    }
    
    func deleteMessages(for chatId: UUID) -> Bool {
        guard let db = db else { return false }
        do {
            try db.run(messagesTable.filter(msgChatId == chatId).delete())
            return true
        } catch {
            print("❌ deleteMessages error: \(error)")
            return false
        }
    }
    
    func messageExists(_ messageId: Int64) -> Bool {
        guard let db = db else { return false }
        do {
            let count = try db.scalar(messagesTable.filter(msgId == messageId).count)
            return count > 0
        } catch {
            return false
        }
    }
    
    func updateMessageStatus(messageId: Int64, isSent: Bool, isDelivered: Bool) -> Bool {
        // не храним статусы в локальной БД – можно игнорировать
        return true
    }
    
    // MARK: - Contacts
    func saveContact(_ contact: Contact) -> Bool {
        guard let db = db else { return false }
        do {
            let userJSON = contact.contactUser.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
            try db.run(contactsTable.insert(
                contactUserId <- contact.userId,
                contactContactUserId <- contact.contactUserId,
                contactStatus <- contact.status,
                contactCreatedAt <- contact.createdAt,
                contactUpdatedAt <- contact.updatedAt ?? Date(),
                contactUserJSON <- userJSON
            ))
            return true
        } catch {
            print("❌ saveContact error: \(error)")
            return false
        }
    }
    
    func getContacts() -> [Contact] {
        guard let db = db else { return [] }
        do {
            var contacts: [Contact] = []
            for row in try db.prepare(contactsTable) {
                var contactUser: User? = nil
                if let jsonStr = row[contactUserJSON], let data = jsonStr.data(using: .utf8) {
                    contactUser = try? JSONDecoder().decode(User.self, from: data)
                
                }
                let contact = Contact(
                    userId: row[contactUserId],
                    contactUserId: row[contactContactUserId],
                    status: row[contactStatus],
                    createdAt: row[contactCreatedAt],
                    updatedAt: row[contactUpdatedAt],
                    contactUser: contactUser
                )
                contacts.append(contact)
            }
            return contacts
        } catch {
            print("❌ getContacts error: \(error)")
            return []
        }
    }
    
    func isContact(userId: UUID) -> Bool {
        guard let db = db else { return false }
        do {
            let count = try db.scalar(contactsTable.filter(contactContactUserId == userId).count)
            return count > 0
        } catch {
            return false
        }
    }
    
    func deleteContact(userId: UUID) -> Bool {
        guard let db = db else { return false }
        do {
            try db.run(contactsTable.filter(contactContactUserId == userId).delete())
            return true
        } catch {
            print("❌ deleteContact error: \(error)")
            return false
        }
    }
    
    // MARK: - Contact Requests
    func saveContactRequest(_ request: ContactRequest) -> Bool {
        guard let db = db else { return false }
        do {
            let existing = contactRequestsTable.filter(reqFromUserId == request.fromUserId && reqStatus == "pending")
            let count = try db.scalar(existing.count)
            if count > 0 {
                try db.run(existing.update(
                    reqFromNickname <- request.fromNickname,
                    reqFromAvatarUrl <- request.fromAvatarUrl,
                    reqStatus <- request.status,
                    reqCreatedAt <- request.createdAt
                ))
            } else {
                try db.run(contactRequestsTable.insert(
                    reqFromUserId <- request.fromUserId,
                    reqFromNickname <- request.fromNickname,
                    reqFromAvatarUrl <- request.fromAvatarUrl,
                    reqStatus <- request.status,
                    reqCreatedAt <- request.createdAt
                ))
            }
            return true
        } catch {
            print("❌ saveContactRequest error: \(error)")
            return false
        }
    }
    
    func getPendingContactRequests() -> [ContactRequest] {
        guard let db = db else { return [] }
        do {
            let query = contactRequestsTable.filter(reqStatus == "pending").order(reqCreatedAt.desc)
            var requests: [ContactRequest] = []
            for row in try db.prepare(query) {
                let req = ContactRequest(
                    fromUserId: row[reqFromUserId],
                    fromNickname: row[reqFromNickname],
                    fromAvatarUrl: row[reqFromAvatarUrl],
                    status: row[reqStatus],
                    createdAt: row[reqCreatedAt]
                )
                requests.append(req)
            }
            return requests
        } catch {
            print("❌ getPendingContactRequests error: \(error)")
            return []
        }
    }
    
    func updateContactRequestStatus(_ requestId: UUID, status: String) -> Bool {
        guard let db = db else { return false }
        do {
            let request = contactRequestsTable.filter(reqId == requestId)
            try db.run(request.update(reqStatus <- status))
            return true
        } catch {
            print("❌ updateContactRequestStatus error: \(error)")
            return false
        }
    }
    
    // MARK: - Clear
    func clearAllData() {
        guard let db = db else { return }
        do {
            try db.run(chatsTable.delete())
            try db.run(messagesTable.delete())
            try db.run(contactsTable.delete())
            try db.run(contactRequestsTable.delete())
        } catch {
            print("❌ clearAllData error: \(error)")
        }
    }
    
    func clearMessages(for chatId: UUID) {
        guard let db = db else { return }
        do {
            try db.run(messagesTable.filter(msgChatId == chatId).delete())
        } catch {
            print("❌ clearMessages error: \(error)")
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
