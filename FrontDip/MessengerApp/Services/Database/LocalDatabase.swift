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
    private let chatUpdatedAt = Expression<Date?>("updated_at")
    private let chatLastActivityAt = Expression<Date?>("last_activity_at")
    private let chatVisibility = Expression<String>("visibility")
    private let chatJoinPolicy = Expression<String>("join_policy")
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
                t.column(chatUpdatedAt)
                t.column(chatLastActivityAt)
                t.column(chatVisibility)
                t.column(chatJoinPolicy)
                t.column(chatMembersCount)
                t.column(chatLastMessagePreviewJSON)
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
            let previewJSON = chat.last_message_preview.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
            let existing = chatsTable.filter(chatId == chat.chat_id)
            let count = try db.scalar(existing.count)
            if count > 0 {
                try db.run(existing.update(
                    chatType <- chat.chat_type,
                    chatName <- chat.name,
                    chatDescription <- chat.description,
                    chatAvatarUrl <- chat.avatar_url,
                    chatCreatorId <- chat.creator_id,
                    chatIsPublic <- chat.is_public,
                    chatMaxMembers <- chat.max_members,
                    chatCreatedAt <- chat.created_at,
                    chatUpdatedAt <- chat.updated_at,
                    chatLastActivityAt <- chat.last_activity_at,
                    chatVisibility <- chat.visibility,
                    chatJoinPolicy <- chat.join_policy,
                    chatMembersCount <- chat.members_count,
                    chatLastMessagePreviewJSON <- previewJSON
                ))
            } else {
                try db.run(chatsTable.insert(
                    chatId <- chat.chat_id,
                    chatType <- chat.chat_type,
                    chatName <- chat.name,
                    chatDescription <- chat.description,
                    chatAvatarUrl <- chat.avatar_url,
                    chatCreatorId <- chat.creator_id,
                    chatIsPublic <- chat.is_public,
                    chatMaxMembers <- chat.max_members,
                    chatCreatedAt <- chat.created_at,
                    chatUpdatedAt <- chat.updated_at,
                    chatLastActivityAt <- chat.last_activity_at,
                    chatVisibility <- chat.visibility,
                    chatJoinPolicy <- chat.join_policy,
                    chatMembersCount <- chat.members_count,
                    chatLastMessagePreviewJSON <- previewJSON
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
                var preview: MessagePreview? = nil
                if let jsonStr = row[chatLastMessagePreviewJSON],
                   let data = jsonStr.data(using: .utf8) {
                    preview = try? JSONDecoder().decode(MessagePreview.self, from: data)
                }
                let chat = Chat(
                    chat_id: row[chatId],
                    chat_type: row[chatType],
                    name: row[chatName],
                    description: row[chatDescription],
                    avatar_url: row[chatAvatarUrl],
                    creator_id: row[chatCreatorId],
                    is_public: row[chatIsPublic],
                    max_members: row[chatMaxMembers],
                    created_at: row[chatCreatedAt],
                    updated_at: row[chatUpdatedAt],
                    last_activity_at: row[chatLastActivityAt],
                    visibility: row[chatVisibility],
                    join_policy: row[chatJoinPolicy],
                    members_count: row[chatMembersCount],
                    last_message_preview: preview
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
                msgId <- message.message_id,
                msgChatId <- message.chat_id,
                msgSenderId <- message.sender_id,
                msgReplyToId <- message.reply_to_id,
                msgContent <- message.content,
                msgType <- message.type,
                msgCreatedAt <- message.created_at,
                msgUpdatedAt <- message.updated_at,
                msgDeletedAt <- message.deleted_at,
                msgIsEdited <- message.is_edited
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
                    message_id: row[msgId],
                    chat_id: row[msgChatId],
                    sender_id: row[msgSenderId],
                    reply_to_id: row[msgReplyToId],
                    content: row[msgContent],
                    type: row[msgType],
                    created_at: row[msgCreatedAt],
                    updated_at: row[msgUpdatedAt],
                    deleted_at: row[msgDeletedAt],
                    is_edited: row[msgIsEdited]
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
            let userJSON = contact.contact_user.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
            try db.run(contactsTable.insert(
                contactIdCol <- contact.id,
                contactUserId <- contact.user_id,
                contactContactUserId <- contact.contact_user_id,
                contactStatus <- contact.status,
                contactCreatedAt <- contact.created_at,
                contactUpdatedAt <- contact.updated_at,
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
                    id: row[contactIdCol],
                    user_id: row[contactUserId],
                    contact_user_id: row[contactContactUserId],
                    status: row[contactStatus],
                    created_at: row[contactCreatedAt],
                    updated_at: row[contactUpdatedAt],
                    contact_user: contactUser
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
            let existing = contactRequestsTable.filter(reqId == request.id)
            let count = try db.scalar(existing.count)
            if count > 0 {
                try db.run(existing.update(
                    reqFromUserId <- request.from_user_id,
                    reqFromNickname <- request.from_nickname,
                    reqFromAvatarUrl <- request.from_avatar_url,
                    reqStatus <- request.status,
                    reqCreatedAt <- request.created_at
                ))
            } else {
                try db.run(contactRequestsTable.insert(
                    reqId <- request.id,
                    reqFromUserId <- request.from_user_id,
                    reqFromNickname <- request.from_nickname,
                    reqFromAvatarUrl <- request.from_avatar_url,
                    reqStatus <- request.status,
                    reqCreatedAt <- request.created_at
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
                    id: row[reqId],
                    from_user_id: row[reqFromUserId],
                    from_nickname: row[reqFromNickname],
                    from_avatar_url: row[reqFromAvatarUrl],
                    status: row[reqStatus],
                    created_at: row[reqCreatedAt]
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
