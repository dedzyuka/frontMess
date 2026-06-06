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
    private let reactionsTable = Table("reactions")
    private let attachmentsTable = Table("attachments")
    private let messageStatusesTable = Table("message_statuses")  // новая
    
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
    private let chatLastMessage = Expression<String?>("last_message")
    private let chatMembersCount = Expression<Int>("members_count")
    
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
    private let msgDeliveredAt = Expression<Date?>("delivered_at")
    private let msgReadAt = Expression<Date?>("read_at")
    
    // === Contacts columns ===
    private let contactUserId = Expression<UUID>("user_id")
    private let contactContactUserId = Expression<UUID>("contact_user_id")
    private let contactStatus = Expression<String>("status")
    private let contactCreatedAt = Expression<Date>("created_at")
    private let contactUpdatedAt = Expression<Date>("updated_at")
    private let contactUserJSON = Expression<String?>("contact_user_json")
    
    // === Contact Requests columns ===
    private let reqId = Expression<UUID>("id")
    private let reqFromUserId = Expression<UUID>("from_user_id")
    private let reqFromNickname = Expression<String>("from_nickname")
    private let reqFromAvatarUrl = Expression<String?>("from_avatar_url")
    private let reqStatus = Expression<String>("status")
    private let reqCreatedAt = Expression<Date>("created_at")
    
    // === Reactions columns ===
    private let reactionMessageId = Expression<Int64>("message_id")
    private let reactionUserId = Expression<UUID>("user_id")
    private let reactionEmoji = Expression<String>("emoji")
    private let reactionCreatedAt = Expression<Date>("created_at")
    
    // === Attachments columns ===
    private let attId = Expression<UUID>("attachment_id")
    private let attMessageId = Expression<Int64>("message_id")
    private let attFileName = Expression<String>("file_name")
    private let attFileSize = Expression<Int?>("file_size")
    private let attMimeType = Expression<String?>("mime_type")
    private let attStoragePath = Expression<String>("storage_path")
    private let attUploadedAt = Expression<Date?>("uploaded_at")
    private let attMessageCreatedAt = Expression<Date?>("message_created_at")
    
    // === Message Statuses columns ===
    private let msMessageId = Expression<Int64>("message_id")
    private let msUserId = Expression<UUID>("user_id")
    private let msDeliveredAt = Expression<Date?>("delivered_at")
    private let msReadAt = Expression<Date?>("read_at")
    private let msCreatedAt = Expression<Date>("created_at")
    
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
                t.column(chatLastMessage)
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
                t.column(msgDeliveredAt)
                t.column(msgReadAt)
            })
            
            try db?.run(contactsTable.create(ifNotExists: true) { t in
                t.column(contactUserId)
                t.column(contactContactUserId)
                t.column(contactStatus)
                t.column(contactCreatedAt)
                t.column(contactUpdatedAt)
                t.column(contactUserJSON)
                t.primaryKey(contactUserId, contactContactUserId)
            })
            
            try db?.run(contactRequestsTable.create(ifNotExists: true) { t in
                t.column(reqId, primaryKey: true)
                t.column(reqFromUserId)
                t.column(reqFromNickname)
                t.column(reqFromAvatarUrl)
                t.column(reqStatus)
                t.column(reqCreatedAt)
            })
            
            try db?.run(reactionsTable.create(ifNotExists: true) { t in
                t.column(reactionMessageId)
                t.column(reactionUserId)
                t.column(reactionEmoji)
                t.column(reactionCreatedAt)
                t.primaryKey(reactionMessageId, reactionUserId, reactionEmoji)
            })
            
            try db?.run(attachmentsTable.create(ifNotExists: true) { t in
                t.column(attId, primaryKey: true)
                t.column(attMessageId)
                t.column(attFileName)
                t.column(attFileSize)
                t.column(attMimeType)
                t.column(attStoragePath)
                t.column(attUploadedAt)
                t.column(attMessageCreatedAt)
                t.foreignKey(attMessageId, references: messagesTable, msgId, delete: .cascade)
            })
            
            try db?.run(messageStatusesTable.create(ifNotExists: true) { t in
                t.column(msMessageId)
                t.column(msUserId)
                t.column(msDeliveredAt)
                t.column(msReadAt)
                t.column(msCreatedAt)
                t.primaryKey(msMessageId, msUserId)
                t.foreignKey(msMessageId, references: messagesTable, msgId, delete: .cascade)
            })
            
            print("✅ All tables created")
        } catch {
            print("❌ DB setup error: \(error)")
        }
    }
    
    // MARK: - Chat operations
    func saveOrUpdateChat(_ chat: Chat) -> Bool {
        guard let db = db else { return false }
        do {
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
                    chatCreatedAt <- chat.createdAt ?? Date(),
                    chatMembersCount <- chat.membersCount,
                    chatLastMessage <- chat.lastMessage
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
                    chatCreatedAt <- chat.createdAt ?? Date(),
                    chatMembersCount <- chat.membersCount,
                    chatLastMessage <- chat.lastMessage
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
                    lastMessage: row[chatLastMessage]
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
            let existing = messagesTable.filter(msgId == message.messageId)
            if try db.scalar(existing.count) > 0 {
                return updateMessage(message)
            }
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
                msgIsEdited <- message.isEdited,
                msgDeliveredAt <- message.deliveredAt,
                msgReadAt <- message.readAt
            ))
            return true
        } catch {
            print("❌ saveMessage error: \(error)")
            return false
        }
    }
    
    func updateMessage(_ message: Message) -> Bool {
        guard let db = db else { return false }
        do {
            let query = messagesTable.filter(msgId == message.messageId)
            let count = try db.scalar(query.count)
            guard count > 0 else {
                print("⚠️ updateMessage: message with id \(message.messageId) not found")
                return false
            }
            try db.run(query.update(
                msgContent <- message.content,
                msgUpdatedAt <- message.updatedAt,
                msgIsEdited <- message.isEdited,
                msgDeliveredAt <- message.deliveredAt,
                msgReadAt <- message.readAt
            ))
            return true
        } catch {
            print("❌ updateMessage error: \(error)")
            return false
        }
    }
    
    func getMessages(for chatId: UUID) -> [Message] {
        guard let db = db else { return [] }
        let query = messagesTable.filter(msgChatId == chatId).order(msgCreatedAt.asc)
        do {
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
                    isEdited: row[msgIsEdited],
                    deliveredAt: row[msgDeliveredAt],
                    readAt: row[msgReadAt]
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
    
    // MARK: - Message Statuses
    func saveMessageStatus(messageId: Int64, userId: UUID, deliveredAt: Date?, readAt: Date?) -> Bool {
        guard let db = db else { return false }
        do {
            let existing = messageStatusesTable.filter(msMessageId == messageId && msUserId == userId)
            let count = try db.scalar(existing.count)
            if count > 0 {
                try db.run(existing.update(
                    msDeliveredAt <- deliveredAt,
                    msReadAt <- readAt
                ))
            } else {
                try db.run(messageStatusesTable.insert(
                    msMessageId <- messageId,
                    msUserId <- userId,
                    msDeliveredAt <- deliveredAt,
                    msReadAt <- readAt,
                    msCreatedAt <- Date()
                ))
            }
            return true
        } catch {
            print("❌ saveMessageStatus error: \(error)")
            return false
        }
    }
    
    func getMessageStatus(for messageId: Int64, userId: UUID) -> (deliveredAt: Date?, readAt: Date?)? {
        guard let db = db else { return nil }
        let query = messageStatusesTable.filter(msMessageId == messageId && msUserId == userId)
        do {
            if let row = try db.pluck(query) {
                return (row[msDeliveredAt], row[msReadAt])
            }
        } catch {
            print("❌ getMessageStatus error: \(error)")
        }
        return nil
    }
    
    // MARK: - Attachments
    func saveAttachments(_ attachments: [Attachment], for messageId: Int64, messageCreatedAt: Date) -> Bool {
        guard let db = db else { return false }
        do {
            // Удаляем старые вложения
            try db.run(attachmentsTable.filter(attMessageId == messageId).delete())
            for att in attachments {
                try db.run(attachmentsTable.insert(
                    attId <- att.attachmentId,
                    attMessageId <- messageId,
                    attMessageCreatedAt <- messageCreatedAt,
                    attFileName <- att.fileName,
                    attFileSize <- att.fileSize,
                    attMimeType <- att.mimeType,
                    attStoragePath <- att.storagePath,
                    attUploadedAt <- att.uploadedAt ?? Date()
                ))
            }
            return true
        } catch {
            print("❌ saveAttachments error: \(error)")
            return false
        }
    }
    
    func getAttachments(for messageId: Int64) -> [Attachment] {
        guard let db = db else { return [] }
        let query = attachmentsTable.filter(attMessageId == messageId)
        do {
            var attachments: [Attachment] = []
            for row in try db.prepare(query) {
                let att = Attachment(
                    attachmentId: row[attId],
                    fileName: row[attFileName],
                    fileSize: row[attFileSize],
                    mimeType: row[attMimeType],
                    storagePath: row[attStoragePath],
                    uploadedAt: row[attUploadedAt],
                    messageCreatedAt: row[attMessageCreatedAt]
                )
                attachments.append(att)
            }
            return attachments
        } catch {
            print("❌ getAttachments error: \(error)")
            return []
        }
    }
    
    func deleteAttachments(for messageId: Int64) -> Bool {
        guard let db = db else { return false }
        do {
            try db.run(attachmentsTable.filter(attMessageId == messageId).delete())
            return true
        } catch {
            print("❌ deleteAttachments error: \(error)")
            return false
        }
    }
    
    // MARK: - Reactions
    func saveReaction(_ reaction: Reaction) -> Bool {
        guard let db = db else { return false }
        do {
            let query = reactionsTable.filter(
                reactionMessageId == reaction.messageId &&
                reactionUserId == reaction.userId &&
                reactionEmoji == reaction.emoji
            )
            if try db.scalar(query.count) > 0 {
                try db.run(query.update(reactionCreatedAt <- reaction.createdAt))
                print("✅ Updated reaction for msg \(reaction.messageId)")
            } else {
                try db.run(reactionsTable.insert(
                    reactionMessageId <- reaction.messageId,
                    reactionUserId <- reaction.userId,
                    reactionEmoji <- reaction.emoji,
                    reactionCreatedAt <- reaction.createdAt
                ))
                print("✅ Inserted reaction for msg \(reaction.messageId)")
            }
            return true
        } catch {
            print("❌ saveReaction error: \(error)")
            return false
        }
    }
    
    func getReactions(for messageId: Int64) -> [Reaction] {
        guard let db = db else { return [] }
        let query = reactionsTable.filter(reactionMessageId == messageId)
        do {
            var reactions: [Reaction] = []
            for row in try db.prepare(query) {
                let reaction = Reaction(
                    messageId: row[reactionMessageId],
                    userId: row[reactionUserId],
                    emoji: row[reactionEmoji],
                    createdAt: row[reactionCreatedAt]
                )
                reactions.append(reaction)
            }
            return reactions
        } catch {
            print("❌ getReactions error: \(error)")
            return []
        }
    }
    
    func deleteReaction(messageId: Int64, userId: UUID, emoji: String) -> Bool {
        guard let db = db else { return false }
        let query = reactionsTable.filter(
            reactionMessageId == messageId &&
            reactionUserId == userId &&
            reactionEmoji == emoji
        )
        do {
            try db.run(query.delete())
            return true
        } catch {
            print("❌ deleteReaction error: \(error)")
            return false
        }
    }
    
    func deleteAllReactions() {
        guard let db = db else { return }
        do { try db.run(reactionsTable.delete()) } catch { print(error) }
    }
    
    // MARK: - Contacts
    func saveContact(_ contact: Contact) -> Bool {
        guard let db = db else { return false }
        do {
            let userJSON = contact.contactUser.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
            let existing = contactsTable.filter(contactUserId == contact.userId && contactContactUserId == contact.contactUserId)
            let count = try db.scalar(existing.count)
            if count > 0 {
                try db.run(existing.update(
                    contactStatus <- contact.status,
                    contactUpdatedAt <- contact.updatedAt ?? Date(),
                    contactUserJSON <- userJSON
                ))
            } else {
                try db.run(contactsTable.insert(
                    contactUserId <- contact.userId,
                    contactContactUserId <- contact.contactUserId,
                    contactStatus <- contact.status,
                    contactCreatedAt <- contact.createdAt,
                    contactUpdatedAt <- contact.updatedAt ?? Date(),
                    contactUserJSON <- userJSON
                ))
            }
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
            try db.run(reactionsTable.delete())
            try db.run(attachmentsTable.delete())
            try db.run(messageStatusesTable.delete())
        } catch {
            print("❌ clearAllData error: \(error)")
        }
    }
    
    func clearMessages(for chatId: UUID) {
        guard let db = db else { return }
        do {
            try db.run(messagesTable.filter(msgChatId == chatId).delete())
            try db.run(attachmentsTable.delete())
            try db.run(messageStatusesTable.delete())
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
    // Для совместимости со старым кодом
    func updateMessageStatusLocally(messageId: Int64, deliveredAt: Date?, readAt: Date?) -> Bool {
        guard let currentUserId = AppState.shared.currentUser?.userId else { return false }
        return saveMessageStatus(messageId: messageId, userId: currentUserId, deliveredAt: deliveredAt, readAt: readAt)
    }
    func deleteMessage(_ messageId: Int64) -> Bool {
        guard let db = db else { return false }
        do {
            // Удаляем зависимые записи (foreign keys не настроены каскадно, делаем вручную)
            try db.run(attachmentsTable.filter(attMessageId == messageId).delete())
            try db.run(reactionsTable.filter(reactionMessageId == messageId).delete())
            try db.run(messageStatusesTable.filter(msMessageId == messageId).delete())
            // Удаляем само сообщение
            try db.run(messagesTable.filter(msgId == messageId).delete())
            print("✅ Message \(messageId) deleted from local DB")
            return true
        } catch {
            print("❌ deleteMessage error: \(error)")
            return false
        }
    }
}
