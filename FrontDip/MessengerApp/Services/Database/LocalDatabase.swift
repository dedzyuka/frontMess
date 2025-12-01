import Foundation
import SQLite

class LocalDatabase {
    static let shared = LocalDatabase()
    
    private var db: Connection?
    private let messagesTable = Table("messages")
    
    private let id = Expression<UUID>("id")
    private let chatId = Expression<UUID>("chat_id")
    private let senderId = Expression<UUID>("sender_id")
    private let content = Expression<String>("content")
    private let type = Expression<String>("type")
    private let timestamp = Expression<Date>("timestamp")
    private let isEncrypted = Expression<Bool>("is_encrypted")
    
    
    private let chatsTable = Table("chats")

    private let chatID = Expression<UUID>("id")
    private let chatName = Expression<String>("name")
    private let chatCreatorId = Expression<UUID>("creator_id")
    private let chatCreatedAt = Expression<Date>("created_at")
    private let chatMemberCount = Expression<Int>("member_count")

    
    // В LocalDatabase.swift добавляем:

    private let contactsTable = Table("contacts")
    private let contactRequestsTable = Table("contact_requests")

    // Столбцы для contacts
    private let contactId = Expression<UUID>("id")
    private let contactUserId = Expression<UUID>("user_id")
    private let contactNickname = Expression<String>("nickname")
    private let contactPublicKey = Expression<String>("public_key")
    private let contactAddedAt = Expression<Date>("added_at")

    // Столбцы для contact_requests
    private let requestId = Expression<UUID>("id")
    private let fromUserId = Expression<UUID>("from_user_id")
    private let fromNickname = Expression<String>("from_nickname")
    private let fromPublicKey = Expression<String>("from_public_key")
    private let requestStatus = Expression<String>("status") // "pending", "accepted", "declined"
    private let requestCreatedAt = Expression<Date>("created_at")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            
            db = try Connection("\(path)/messenger.sqlite3")
            
            // Таблица сообщений (уже есть)
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
            
            // Новая таблица чатов
            try db?.run(chatsTable.create(ifNotExists: true) { t in
                t.column(chatId, primaryKey: true)
                t.column(chatName)
                t.column(chatCreatorId)
                t.column(chatCreatedAt)
                t.column(chatMemberCount)
            })
            
            try db?.run(contactsTable.create(ifNotExists: true) { t in
                t.column(contactId, primaryKey: true)
                t.column(contactUserId)
                t.column(contactNickname)
                t.column(contactPublicKey)
                t.column(contactAddedAt)
            })
            
            // Таблица запросов на контакт
            try db?.run(contactRequestsTable.create(ifNotExists: true) { t in
                t.column(requestId, primaryKey: true)
                t.column(fromUserId)
                t.column(fromNickname)
                t.column(fromPublicKey)
                t.column(requestStatus)
                t.column(requestCreatedAt)
            })
            
            print("✅ Database setup complete with chats table")
        } catch {
            print("❌ Database setup error: \(error)")
        }
    }
    // MARK: - Contact Operations

    // Сохранить контакт
    func saveContact(_ contact: Contact) -> Bool {
        guard let db = db else { return false }
        
        do {
            let insert = contactsTable.insert(
                contactId <- contact.id,
                contactUserId <- contact.userId,
                contactNickname <- contact.nickname,
                contactPublicKey <- contact.publicKey,
                contactAddedAt <- contact.addedAt
            )
            
            try db.run(insert)
            return true
        } catch {
            print("Save contact error: \(error)")
            return false
        }
    }

    // Получить все контакты
    func getContacts() -> [Contact] {
        guard let db = db else { return [] }
        
        do {
            let query = contactsTable.order(contactAddedAt.desc)
            
            var contacts: [Contact] = []
            for row in try db.prepare(query) {
                let contact = Contact(
                    id: row[contactId],
                    userId: row[contactUserId],
                    nickname: row[contactNickname],
                    publicKey: row[contactPublicKey],
                    addedAt: row[contactAddedAt]
                )
                contacts.append(contact)
            }
            
            return contacts
        } catch {
            print("Get contacts error: \(error)")
            return []
        }
    }

    // Проверить, есть ли пользователь в контактах
    func isContact(userId: UUID) -> Bool {
        guard let db = db else { return false }
        
        do {
            let query = contactsTable.filter(contactUserId == userId)
            let count = try db.scalar(query.count)
            return count > 0
        } catch {
            print("Check contact error: \(error)")
            return false
        }
    }

    // Удалить контакт
    func deleteContact(userId: UUID) -> Bool {
        guard let db = db else { return false }
        
        do {
            let query = contactsTable.filter(contactUserId == userId)
            try db.run(query.delete())
            return true
        } catch {
            print("Delete contact error: \(error)")
            return false
        }
    }

    // MARK: - Contact Requests Operations

    // Сохранить запрос на контакт
    func saveContactRequest(_ request: ContactRequest) -> Bool {
        guard let db = db else { return false }
        
        do {
            let insert = contactRequestsTable.insert(
                requestId <- request.id,
                fromUserId <- request.fromUserId,
                fromNickname <- request.fromNickname,
                fromPublicKey <- request.fromPublicKey,
                requestStatus <- request.status,
                requestCreatedAt <- request.createdAt
            )
            
            try db.run(insert)
            return true
        } catch {
            print("Save contact request error: \(error)")
            return false
        }
    }

    // Получить все pending запросы
    func getPendingContactRequests() -> [ContactRequest] {
        guard let db = db else { return [] }
        
        do {
            let query = contactRequestsTable
                .filter(requestStatus == "pending")
                .order(requestCreatedAt.desc)
            
            var requests: [ContactRequest] = []
            for row in try db.prepare(query) {
                let request = ContactRequest(
                    id: row[requestId],
                    fromUserId: row[fromUserId],
                    fromNickname: row[fromNickname],
                    fromPublicKey: row[fromPublicKey],
                    status: row[requestStatus],
                    createdAt: row[requestCreatedAt]
                )
                requests.append(request)
            }
            
            return requests
        } catch {
            print("Get contact requests error: \(error)")
            return []
        }
    }

    // Обновить статус запроса
    func updateContactRequestStatus(_ requestId: UUID, status: String) -> Bool {
        guard let db = db else { return false }
        
        do {
            let request = contactRequestsTable.filter(self.requestId == requestId)
            try db.run(request.update(requestStatus <- status))
            return true
        } catch {
            print("Update contact request error: \(error)")
            return false
        }
    }

    // MARK: - Chat Operations
    func saveChat(_ chat: Chat) -> Bool {
        guard let db = db else { return false }
        
        do {
            let insert = chatsTable.insert(
                chatId <- chat.id,
                chatName <- chat.name,
                chatCreatorId <- chat.creatorId,
                chatCreatedAt <- chat.createdAt,
                chatMemberCount <- chat.memberCount
            )
            
            try db.run(insert)
            return true
        } catch {
            print("Save chat error: \(error)")
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
                    id: row[chatId],
                    name: row[chatName],
                    creatorId: row[chatCreatorId],
                    createdAt: row[chatCreatedAt],
                    memberCount: row[chatMemberCount]
                )
                chats.append(chat)
            }
            
            return chats
        } catch {
            print("Get chats error: \(error)")
            return []
        }
    }

    func deleteAllChats() {
        guard let db = db else { return }
        
        do {
            try db.run(chatsTable.delete())
            print("All chats cleared from database")
        } catch {
            print("Error clearing chats: \(error)")
        }
    }

    // MARK: - Chat Operations





    
    private let isSent = Expression<Bool>("is_sent")
    private let isDelivered = Expression<Bool>("is_delivered")

    

    // MARK: - CRUD Operations
    
    func saveMessage(_ message: Message) -> Bool {
        guard let db = db else { return false }
        
        do {
            let insert = messagesTable.insert(
                id <- message.id ?? UUID(),
                chatId <- message.chatId,
                senderId <- message.senderId,
                content <- message.content,
                type <- message.type.rawValue,
                timestamp <- message.timestamp,
                isEncrypted <- message.isEncrypted
            )
            
            try db.run(insert)
            return true
        } catch {
            print("Save message error: \(error)")
            return false
        }
    }
    
    func getMessages(for chatUUID: UUID) -> [Message] {
        guard let db = db else { return [] }
        
        do {
            let query = messagesTable.filter(self.chatId == chatUUID)
                .order(timestamp.asc)
            
            var messages: [Message] = []
            
            for row in try db.prepare(query) {
                guard let messageType = MessageType(rawValue: row[type]) else { continue }
                
                let message = Message(
                    id: row[id],
                    chatId: row[chatId],
                    senderId: row[senderId],
                    content: row[content],
                    type: messageType,
                    timestamp: row[timestamp],
                    isEncrypted: row[isEncrypted]
                )
                
                messages.append(message)
            }
            
            return messages
        } catch {
            print("Get messages error: \(error)")
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
            print("Delete messages error: \(error)")
            return false
        }
    }
    
    // MARK: - Clear Methods
    
    func clearAllData() {
        guard let db = db else { return }
        
        do {
            // Удаляем все сообщения
            try db.run(messagesTable.delete())
            print("All messages cleared from database")
        } catch {
            print("Error clearing database: \(error)")
        }
    }
    
    func clearMessages(for chatId: UUID) {
        guard let db = db else { return }
        
        do {
            let query = messagesTable.filter(self.chatId == chatId)
            try db.run(query.delete())
            print("Messages cleared for chat: \(chatId)")
        } catch {
            print("Error clearing messages: \(error)")
        }
    }
    
    
    // MARK: - Статус сообщений (реализация или удаление)
    
    // Вариант 1: Удаляем неиспользуемый метод
    // func updateMessageStatus(messageId: UUID, isSent: Bool, isDelivered: Bool) -> Bool {
    //     // Не реализовано
    //     return false
    // }
    
    // Вариант 2: Добавляем поля в таблицу и реализуем метод
    // В текущей схеме нет полей для статуса, поэтому:
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
            print("Error updating message status: \(error)")
            return false
        }
    }
    
    // MARK: - Migration Helpers
    
    func getDatabasePath() -> String? {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first!
        
        return "\(path)/messenger.sqlite3"
    }
    
    func getDatabaseSize() -> Int64? {
        guard let path = getDatabasePath() else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64
        } catch {
            print("Error getting database size: \(error)")
            return nil
        }
    }
    func messageExists(_ messageId: UUID) -> Bool {
        guard let db = db else { return false }
        
        do {
            let query = messagesTable.filter(id == messageId)
            let count = try db.scalar(query.count)
            return count > 0
        } catch {
            print("Error checking message existence: \(error)")
            return false
        }
    }
}
