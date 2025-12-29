// ./FrontDip/MessengerApp/Services/Database/LocalDatabase.swift
import Foundation
import SQLite

class LocalDatabase {
    static let shared = LocalDatabase()
    
    private var db: Connection?
    private let messagesTable = Table("messages")
    private let chatsTable = Table("chats")
    private let contactsTable = Table("contacts")
    private let contactRequestsTable = Table("contact_requests")
    
    // MARK: - Столбцы для messages таблицы
    private let id = Expression<UUID>("id")
    private let chatId = Expression<UUID>("chat_id")
    private let senderId = Expression<UUID>("sender_id")
    private let content = Expression<String>("content")
    private let type = Expression<String>("type")
    private let timestamp = Expression<Date>("timestamp")
    private let isEncrypted = Expression<Bool>("is_encrypted")
    private let isSent = Expression<Bool>("is_sent")
    private let isDelivered = Expression<Bool>("is_delivered")
    
    // MARK: - Столбцы для chats таблицы (ИСПРАВЛЕНО!)
    private let chatName = Expression<String>("name")
    private let creatorId = Expression<UUID>("creator_id")
    private let createdAt = Expression<Date>("created_at")
    private let memberCount = Expression<Int>("member_count")
    
    // MARK: - Столбцы для contacts таблицы
    private let contactId = Expression<UUID>("id")
    private let contactUserId = Expression<UUID>("user_id")
    private let contactNickname = Expression<String>("nickname")
    private let contactPublicKey = Expression<String>("public_key")
    private let contactAddedAt = Expression<Date>("added_at")
    
    // MARK: - Столбцы для contact_requests таблицы
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
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            
            db = try Connection("\(path)/messenger.sqlite3")
            
            print("📊 Инициализация базы данных по пути: \(path)/messenger.sqlite3")
            
            // ✅ Таблица сообщений (уже есть)
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
            
            // ✅ Новая таблица чатов (ИСПРАВЛЕНО!)
            try db?.run(chatsTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)  // ✅ ИСПРАВЛЕНО: было chatID
                t.column(chatName)
                t.column(creatorId)
                t.column(createdAt)
                t.column(memberCount)
            })
            
            print("✅ Таблица chats создана/проверена")
            
            // ✅ Таблица контактов
            try db?.run(contactsTable.create(ifNotExists: true) { t in
                t.column(contactId, primaryKey: true)
                t.column(contactUserId)
                t.column(contactNickname)
                t.column(contactPublicKey)
                t.column(contactAddedAt)
            })
            
            // ✅ Таблица запросов на контакт
            try db?.run(contactRequestsTable.create(ifNotExists: true) { t in
                t.column(requestId, primaryKey: true)
                t.column(fromUserId)
                t.column(fromNickname)
                t.column(fromPublicKey)
                t.column(requestStatus)
                t.column(requestCreatedAt)
            })
            
            print("✅ Database setup complete with all tables")
            
        } catch {
            print("❌ Database setup error: \(error)")
        }
    }
    
    // MARK: - Chat Operations
    
    func saveOrUpdateChat(_ chat: Chat) -> Bool {
        guard let db = db else { return false }
        
        do {
            // Проверяем, существует ли чат
            let existingChat = chatsTable.filter(id == chat.id)  // ✅ ИСПРАВЛЕНО: было chatID
            let count = try db.scalar(existingChat.count)
            
            if count > 0 {
                // Обновляем существующий чат
                try db.run(existingChat.update(
                    chatName <- chat.name,
                    creatorId <- chat.creatorId,
                    createdAt <- chat.createdAt,
                    memberCount <- chat.memberCount
                ))
                print("✅ Чат обновлен: \(chat.name)")
            } else {
                // Добавляем новый чат
                try db.run(chatsTable.insert(
                    id <- chat.id,  // ✅ ИСПРАВЛЕНО: было chatID
                    chatName <- chat.name,
                    creatorId <- chat.creatorId,
                    createdAt <- chat.createdAt,
                    memberCount <- chat.memberCount
                ))
                print("✅ Чат сохранен: \(chat.name)")
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
            let query = chatsTable.order(createdAt.desc)  // ✅ ИСПРАВЛЕНО: было chatCreatedAt
            
            var chats: [Chat] = []
            for row in try db.prepare(query) {
                let chat = Chat(
                    id: row[id],  // ✅ ИСПРАВЛЕНО: было row[chatID]
                    name: row[chatName],
                    creatorId: row[creatorId],
                    createdAt: row[createdAt],
                    memberCount: row[memberCount]
                )
                chats.append(chat)
                print("📊 Загружен чат: \(chat.name), ID: \(chat.id)")
            }
            
            return chats
        } catch {
            print("❌ Get chats error: \(error)")
            return []
        }
    }
    
    func deleteAllChats() {
        guard let db = db else { return }
        
        do {
            try db.run(chatsTable.delete())
            print("✅ Все чаты очищены из базы данных")
        } catch {
            print("❌ Error clearing chats: \(error)")
        }
    }
    
    // MARK: - Contact Operations
    
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
            print("✅ Контакт сохранен: \(contact.nickname)")
            return true
        } catch {
            print("❌ Save contact error: \(error)")
            return false
        }
    }
    
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
            print("❌ Get contacts error: \(error)")
            return []
        }
    }
    
    func isContact(userId: UUID) -> Bool {
        guard let db = db else { return false }
        
        do {
            let query = contactsTable.filter(contactUserId == userId)
            let count = try db.scalar(query.count)
            return count > 0
        } catch {
            print("❌ Check contact error: \(error)")
            return false
        }
    }
    
    func deleteContact(userId: UUID) -> Bool {
        guard let db = db else { return false }
        
        do {
            let query = contactsTable.filter(contactUserId == userId)
            try db.run(query.delete())
            print("✅ Контакт удален: \(userId)")
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
            // Проверяем, не существует ли уже запрос с таким ID
            let existingQuery = contactRequestsTable.filter(requestId == request.id)
            let count = try db.scalar(existingQuery.count)
            
            if count > 0 {
                // Если уже существует - обновляем
                try db.run(existingQuery.update(
                    fromUserId <- request.fromUserId,
                    fromNickname <- request.fromNickname,
                    fromPublicKey <- request.fromPublicKey,
                    requestStatus <- request.status,
                    requestCreatedAt <- request.createdAt
                ))
                print("✅ Запрос на контакт обновлен: от \(request.fromNickname)")
            } else {
                // Если не существует - создаем новый
                let insert = contactRequestsTable.insert(
                    requestId <- request.id,
                    fromUserId <- request.fromUserId,
                    fromNickname <- request.fromNickname,
                    fromPublicKey <- request.fromPublicKey,
                    requestStatus <- request.status,
                    requestCreatedAt <- request.createdAt
                )
                
                try db.run(insert)
                print("✅ Запрос на контакт сохранен: от \(request.fromNickname)")
            }
            return true
        } catch {
            print("❌ Save contact request error: \(error)")
            return false
        }
    }
    
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
            print("❌ Get contact requests error: \(error)")
            return []
        }
    }
    
    func updateContactRequestStatus(_ requestId: UUID, status: String) -> Bool {
        guard let db = db else { return false }
        
        do {
            let request = contactRequestsTable.filter(self.requestId == requestId)
            try db.run(request.update(requestStatus <- status))
            print("✅ Статус запроса обновлен на: \(status)")
            return true
        } catch {
            print("❌ Update contact request error: \(error)")
            return false
        }
    }
    
    // MARK: - Message Operations
    
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
            print("❌ Save message error: \(error)")
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
            let query = messagesTable.filter(id == messageId)
            let count = try db.scalar(query.count)
            return count > 0
        } catch {
            print("❌ Error checking message existence: \(error)")
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
            print("❌ Error updating message status: \(error)")
            return false
        }
    }
    
    // MARK: - Clear Methods
    
    func clearAllData() {
        guard let db = db else { return }
        
        do {
            // Удаляем все сообщения
            try db.run(messagesTable.delete())
            print("✅ Все сообщения очищены из базы данных")
            
            // Удаляем все чаты
            try db.run(chatsTable.delete())
            print("✅ Все чаты очищены из базы данных")
            
            // Удаляем все контакты
            try db.run(contactsTable.delete())
            print("✅ Все контакты очищены из базы данных")
            
            // Удаляем все запросы на контакт
            try db.run(contactRequestsTable.delete())
            print("✅ Все запросы на контакт очищены из базы данных")
            
        } catch {
            print("❌ Error clearing database: \(error)")
        }
    }
    
    func clearMessages(for chatId: UUID) {
        guard let db = db else { return }
        
        do {
            let query = messagesTable.filter(self.chatId == chatId)
            try db.run(query.delete())
            print("✅ Сообщения очищены для чата: \(chatId)")
        } catch {
            print("❌ Error clearing messages: \(error)")
        }
    }
    
    // MARK: - Migration Helpers
    
    func recreateTables() {
        print("🔄 Пересоздание всех таблиц...")
        
        // Закрываем существующее соединение
        db = nil
        
        // Удаляем файл базы данных
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first!
        
        let databasePath = "\(path)/messenger.sqlite3"
        
        do {
            if FileManager.default.fileExists(atPath: databasePath) {
                try FileManager.default.removeItem(atPath: databasePath)
                print("🗑️ Старая база данных удалена")
            }
        } catch {
            print("❌ Ошибка удаления базы данных: \(error)")
        }
        
        // Создаем новую базу
        setupDatabase()
        print("✅ База данных пересоздана с новой схемой")
    }
    
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
            print("❌ Error getting database size: \(error)")
            return nil
        }
    }
    
    func printDatabaseInfo() {
        guard let db = db else {
            print("❌ База данных не инициализирована")
            return
        }
        
        print("📊 ИНФОРМАЦИЯ О БАЗЕ ДАННЫХ:")
        
        do {
            // Проверяем таблицу chats
            let chatsCount = try db.scalar(chatsTable.count)
            print("   Чатов: \(chatsCount)")
            
            // Проверяем таблицу messages
            let messagesCount = try db.scalar(messagesTable.count)
            print("   Сообщений: \(messagesCount)")
            
            // Проверяем таблицу contacts
            let contactsCount = try db.scalar(contactsTable.count)
            print("   Контактов: \(contactsCount)")
            
            // Проверяем таблицу contact_requests
            let requestsCount = try db.scalar(contactRequestsTable.count)
            print("   Запросов на контакт: \(requestsCount)")
            
            // Показываем схему таблицы chats
            print("   Схема таблицы chats:")
            let pragma = try db.prepare("PRAGMA table_info(chats)")
            for row in pragma {
                print("     Колонка: \(row[1] ?? "?"), Тип: \(row[2] ?? "?")")
            }
            
        } catch {
            print("❌ Ошибка получения информации о базе: \(error)")
        }
    }
}
