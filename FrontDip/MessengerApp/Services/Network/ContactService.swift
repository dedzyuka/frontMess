// ./FrontDip/MessengerApp/Services/Contact/ContactService.swift
import Foundation
import Combine

class ContactService: ObservableObject {
    static let shared = ContactService()
    
    @Published var contacts: [Contact] = []
    @Published var pendingRequests: [ContactRequest] = []
    
    private let database = LocalDatabase.shared
    private let webSocketService = WebSocketService.shared
    private let apiService = APIService.shared
    private let keychainService = KeychainService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadContacts()
        loadPendingRequests()
        setupWebSocketHandlers()
        
        // Обновляем данные при каждом появлении пользователя
        NotificationCenter.default.publisher(for: .userLoggedIn)
            .sink { [weak self] _ in
                self?.refreshAllData()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Загрузка данных
    
    func loadContacts() {
        contacts = database.getContacts()
        print("📱 Загружено контактов: \(contacts.count)")
    }
    
    func loadPendingRequests() {
        pendingRequests = database.getPendingContactRequests()
        print("📱 Загружено запросов: \(pendingRequests.count)")
    }
    
    func refreshAllData() {
        loadContacts()
        loadPendingRequests()
        
        // Уведомляем UI о новых запросах
        if !pendingRequests.isEmpty {
            NotificationCenter.default.post(
                name: .showNotification,
                object: "У вас \(pendingRequests.count) новых запросов"
            )
        }
    }
    
    // MARK: - Поиск пользователей
    
    func searchUsers(query: String) async throws -> [UserPublicResponse] {
        guard let deviceId = keychainService.loadDeviceId() else {
            throw NSError(domain: "Auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Device ID не найден"])
        }
        
        do {
            let users = try await apiService.searchUsers(query: query, deviceId: deviceId)
            print("✅ Найдено пользователей: \(users.count)")
            return users
        } catch {
            print("❌ Ошибка поиска пользователей: \(error)")
            throw error
        }
    }
    
    // MARK: - Управление контактами
    
    func addContact(_ user: UserPublicResponse) {
        let contact = Contact(
            id: UUID(),
            userId: user.user_id,
            nickname: user.nickname,
            publicKey: user.public_key,
            addedAt: Date()
        )
        
        if database.saveContact(contact) {
            loadContacts()
            print("✅ Контакт добавлен: \(user.nickname)")
        }
    }
    
    func removeContact(userId: UUID) {
        if database.deleteContact(userId: userId) {
            loadContacts()
            print("🗑️ Контакт удален")
        }
    }
    
    func isContact(userId: UUID) -> Bool {
        return database.isContact(userId: userId)
    }
    
    // MARK: - Запросы на контакт
    
    func sendContactRequest(to user: UserPublicResponse) {
        guard let currentUser = AppState.shared.currentUser else {
            print("❌ Текущий пользователь не найден")
            return
        }
        
        // Сохраняем как исходящий запрос
        let request = ContactRequest(
            id: UUID(),
            fromUserId: currentUser.id,
            fromNickname: currentUser.nickname,
            fromPublicKey: currentUser.publicKey,
            status: "pending",
            createdAt: Date()
        )
        
        if database.saveContactRequest(request) {
            loadPendingRequests()
            print("📤 Запрос на контакт сохранен локально")
        }
        
        // Отправляем через WebSocket (ИСПРАВЛЕНО: правильный порядок аргументов)
        let message = WebSocketMessage(
            type: "contact_request",
            senderId: currentUser.id,  // Теперь здесь
            recipientId: user.user_id, // Теперь здесь
            contactData: WebSocketMessage.ContactData(
                userId: currentUser.id,
                nickname: currentUser.nickname,
                publicKey: currentUser.publicKey
            )
        )
        
        webSocketService.sendMessage(message)
        print("📤 Запрос на контакт отправлен через WebSocket")
    }
    
    func acceptContactRequest(_ request: ContactRequest) {
        // Добавляем в контакты
        let contact = Contact(
            id: UUID(),
            userId: request.fromUserId,
            nickname: request.fromNickname,
            publicKey: request.fromPublicKey,
            addedAt: Date()
        )
        
        if database.saveContact(contact) {
            loadContacts()
            print("✅ Контакт добавлен: \(request.fromNickname)")
        }
        
        // Обновляем статус запроса
        if database.updateContactRequestStatus(request.id, status: "accepted") {
            loadPendingRequests()
            print("✅ Статус запроса обновлен на 'accepted'")
        }
        
        // Отправляем подтверждение
        guard let currentUser = AppState.shared.currentUser else { return }
        
        // ИСПРАВЛЕНО: правильный порядок аргументов
        let acceptMessage = WebSocketMessage(
            type: "contact_accept",
            senderId: currentUser.id,  // Теперь здесь
            recipientId: request.fromUserId, // Теперь здесь
            contactData: WebSocketMessage.ContactData(
                userId: currentUser.id,
                nickname: currentUser.nickname,
                publicKey: currentUser.publicKey
            )
        )
        
        webSocketService.sendMessage(acceptMessage)
        print("✅ Подтверждение отправлено")
    }
    
    func declineContactRequest(_ request: ContactRequest) {
        if database.updateContactRequestStatus(request.id, status: "declined") {
            loadPendingRequests()
            print("❌ Запрос отклонен")
        }
    }
    
    // MARK: - WebSocket обработчики
    
    private func setupWebSocketHandlers() {
        NotificationCenter.default.publisher(for: .newContactRequest)
            .sink { [weak self] notification in
                if let request = notification.object as? ContactRequest {
                    self?.handleIncomingContactRequest(request)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .contactRequestAccepted)
            .sink { [weak self] notification in
                if let contact = notification.object as? Contact {
                    self?.handleContactRequestAccepted(contact)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleIncomingContactRequest(_ request: ContactRequest) {
        // Сохраняем входящий запрос
        if database.saveContactRequest(request) {
            loadPendingRequests()
            
            // Показываем уведомление
            NotificationCenter.default.post(
                name: .showNotification,
                object: "Новый запрос на контакт от \(request.fromNickname)"
            )
            
            print("📩 Новый запрос на контакт от \(request.fromNickname)")
        }
    }
    
    private func handleContactRequestAccepted(_ contact: Contact) {
        // Добавляем в контакты
        if database.saveContact(contact) {
            loadContacts()
            
            // Показываем уведомление
            NotificationCenter.default.post(
                name: .showNotification,
                object: "\(contact.nickname) принял(а) ваш запрос на контакт"
            )
            
            print("✅ Запрос принят: \(contact.nickname)")
        }
    }
}

// Расширение для Notification
extension Notification.Name {
    static let newContactRequest = Notification.Name("newContactRequest")
    static let contactRequestAccepted = Notification.Name("contactRequestAccepted")
    static let showNotification = Notification.Name("showNotification")
    static let userLoggedIn = Notification.Name("userLoggedIn")
}
