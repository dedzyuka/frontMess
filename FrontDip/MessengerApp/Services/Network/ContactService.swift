// ./FrontDip/MessengerApp/Services/Network/ContactService.swift
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
                object: NotificationData(
                    type: .info,
                    message: "У вас \(pendingRequests.count) новых запросов"
                )
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
        
        print("📤 Отправляем запрос на контакт пользователю \(user.nickname)")
        
        // Сохраняем локально как исходящий запрос
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
            print("✅ Запрос сохранен локально")
        }
        
        // Отправляем через WebSocket
        webSocketService.sendContactRequest(to: user.user_id)  // ✅ Используем правильный метод
        
        // Показываем уведомление
        NotificationService.shared.showInfo("Запрос отправлен пользователю \(user.nickname)")
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
        
        // Отправляем подтверждение через WebSocket
        webSocketService.sendContactAccept(to: request.fromUserId)  // ✅ Используем правильный метод
        
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
        
        NotificationCenter.default.publisher(for: .websocketConnected)
            .sink { [weak self] _ in
                print("🔗 WebSocket подключен, обновляем контакты...")
                self?.refreshAllData()
            }
            .store(in: &cancellables)
    }
    
     func handleIncomingContactRequest(_ request: ContactRequest) {
        print("📩 Получен запрос на контакт от \(request.fromNickname)")
        
        // Сохраняем входящий запрос
        if database.saveContactRequest(request) {
            loadPendingRequests()
            
            // Показываем уведомление
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .showNotification,
                    object: NotificationData(
                        type: .info,
                        message: "Новый запрос на контакт от \(request.fromNickname)"
                    )
                )
            }
        }
    }
    
    func handleContactRequestAccepted(_ contact: Contact) {
        print("✅ Запрос на контакт принят: \(contact.nickname)")
        
        // Добавляем в контакты
        if database.saveContact(contact) {
            loadContacts()
            
            // Показываем уведомление
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .showNotification,
                    object: NotificationData(
                        type: .success,
                        message: "\(contact.nickname) принял(а) ваш запрос на контакт"
                    )
                )
            }
        }
    }
}
