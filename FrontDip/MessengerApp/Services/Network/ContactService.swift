// ./FrontDip/MessengerApp/Services/Network/ContactService.swift
import Foundation
import Combine

class ContactService: ObservableObject {
    static let shared = ContactService()
    
    @Published var contacts: [Contact] = []
    @Published var pendingRequests: [ContactRequest] = []
    @Published var isLoading = false
    
    private let database = LocalDatabase.shared
    private let webSocketService = WebSocketService.shared
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var pendingContactRequestsQueue: [(UserPublicResponse, UUID)] = []
    
    private init() {
        loadContacts()
        loadPendingRequests()
        setupWebSocketHandlers()
        setupBindings()
    }
    
    private func setupBindings() {
        // Отправляем запросы из очереди при подключении WebSocket
        NotificationCenter.default.publisher(for: .websocketConnected)
            .sink { [weak self] _ in
                self?.sendQueuedContactRequests()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
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
    }
    
    // MARK: - User Search
    
    func searchUsers(query: String) async throws -> [UserPublicResponse] {
        guard let deviceId = KeychainService.shared.loadDeviceId() else {
            throw NSError(domain: "Auth", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Device ID не найден"])
        }
        
        return try await apiService.searchUsers(
            query: query,
            deviceId: deviceId
        )
    }
    
    // MARK: - Contact Management
    
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
    
    // MARK: - Contact Requests
    
    func sendContactRequest(to user: UserPublicResponse) {
        guard let currentUser = AppState.shared.currentUser else {
            print("❌ Текущий пользователь не найден")
            return
        }
        
        // Проверяем, что не отправляем самому себе
        guard currentUser.id != user.user_id else {
            print("⚠️ Нельзя отправить запрос самому себе")
            NotificationService.shared.showError("Нельзя отправить запрос самому себе")
            return
        }
        
        // Проверяем, что пользователь уже не в контактах
        guard !isContact(userId: user.user_id) else {
            print("⚠️ Пользователь уже в контактах")
            NotificationService.shared.showInfo("Пользователь уже в контактах")
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
        
        // Отправляем через WebSocket, если подключен
        if webSocketService.isConnected {
            webSocketService.sendContactRequest(to: user.user_id)
        } else {
            // Сохраняем в очередь для отправки позже
            pendingContactRequestsQueue.append((user, request.id))
            print("⏳ WebSocket не подключен, запрос добавлен в очередь")
            NotificationService.shared.showInfo("Запрос будет отправлен при подключении")
        }
        
        NotificationService.shared.showInfo("Запрос отправлен пользователю \(user.nickname)")
    }
    
    private func sendQueuedContactRequests() {
        guard !pendingContactRequestsQueue.isEmpty else { return }
        
        print("📤 Отправка запросов из очереди: \(pendingContactRequestsQueue.count)")
        
        for (user, requestId) in pendingContactRequestsQueue {
            webSocketService.sendContactRequest(to: user.user_id)
        }
        
        pendingContactRequestsQueue.removeAll()
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
        webSocketService.sendContactAccept(to: request.fromUserId)
        
        print("✅ Подтверждение отправлено")
        NotificationService.shared.showSuccess("Контакт \(request.fromNickname) добавлен")
    }
    
    func declineContactRequest(_ request: ContactRequest) {
        if database.updateContactRequestStatus(request.id, status: "declined") {
            loadPendingRequests()
            print("❌ Запрос отклонен")
            NotificationService.shared.showInfo("Запрос отклонен")
        }
    }
    
    // MARK: - WebSocket Handlers
    
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
    
    func handleIncomingContactRequest(_ request: ContactRequest) {
        print("📩 Получен запрос на контакт от \(request.fromNickname)")
        
        // Проверяем, что запрос не от нас самих
        guard let currentUserId = AppState.shared.currentUser?.id,
              request.fromUserId != currentUserId else {
            print("⚠️ Получен запрос от самого себя, игнорируем")
            return
        }
        
        // Проверяем, что пользователь уже не в контактах
        guard !isContact(userId: request.fromUserId) else {
            print("⚠️ Пользователь уже в контактах")
            return
        }
        
        // Сохраняем входящий запрос
        if database.saveContactRequest(request) {
            loadPendingRequests()
            
            NotificationService.shared.showInfo(
                "Новый запрос на контакт от \(request.fromNickname)"
            )
        }
    }
    
    func handleContactRequestAccepted(_ contact: Contact) {
        print("✅ Запрос на контакт принят: \(contact.nickname)")
        
        // Добавляем в контакты
        if database.saveContact(contact) {
            loadContacts()
            
            NotificationService.shared.showSuccess(
                "\(contact.nickname) принял(а) ваш запрос на контакт"
            )
        }
    }
}
