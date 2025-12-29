// ./FrontDip/MessengerApp/Services/Network/ContactService.swift
import Foundation
import Combine

class ContactService: ObservableObject {
    static let shared = ContactService()
    
    @Published var contacts: [Contact] = []
    @Published var pendingRequests: [ContactRequest] = []
    @Published var isLoading = false
    
    private let apiService = APIService.shared
    private let webSocketService = WebSocketService.shared
    private let database = LocalDatabase.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadContacts()
        loadPendingRequests()
        setupWebSocketHandlers()
    }
    
    // MARK: - REST API Methods
    
    func sendContactRequest(to userId: UUID) async throws -> Bool {
        guard let deviceId = KeychainService.shared.loadDeviceId() else {
            throw NSError(domain: "Auth", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Device ID не найден"])
        }
        
        let url = URL(string: "\(apiService.baseURL)/contacts/requests")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let body: [String: Any] = [
            "to_user_id": userId.uuidString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 201 {
            // После успешной отправки, отправляем WebSocket уведомление
            webSocketService.sendContactRequest(to: userId)
            return true
        } else {
            throw URLError(.badServerResponse)
        }
    }
    
    func getPendingRequests() async throws -> [ContactRequest] {
        guard let deviceId = KeychainService.shared.loadDeviceId() else {
            throw NSError(domain: "Auth", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Device ID не найден"])
        }
        
        let url = URL(string: "\(apiService.baseURL)/contacts/requests/pending")!
        
        var request = URLRequest(url: url)
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoder = JSONDecoder.flexibleISO8601
        let response = try decoder.decode(ContactRequestListResponse.self, from: data)
        
        return response.requests.map { apiRequest in
            ContactRequest(
                id: apiRequest.id,
                fromUserId: apiRequest.from_user_id,
                fromNickname: apiRequest.from_nickname,
                fromPublicKey: "", // TODO: Получить с сервера
                status: apiRequest.status,
                createdAt: apiRequest.created_at
            )
        }
    }
    
    func respondToContactRequest(requestId: UUID, status: String) async throws -> Bool {
        guard let deviceId = KeychainService.shared.loadDeviceId() else {
            throw NSError(domain: "Auth", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Device ID не найден"])
        }
        
        let urlString = "\(apiService.baseURL)/contacts/requests/\(requestId.uuidString)/respond"
        print("📤 Отправляем ответ на запрос контакта: \(urlString)")
        print("📤 Status: \(status)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let body: [String: Any] = [
            "status": status
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Error encoding body: \(error)")
            throw error
        }
        
        print("📤 Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Not an HTTP response")
                throw URLError(.badServerResponse)
            }
            
            print("📥 Response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Response body: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ Contact request responded successfully")
                
                // Отправляем WebSocket уведомление
                if status == "accepted" {
                    // Получаем информацию о запросе
                    if let request = pendingRequests.first(where: { $0.id == requestId }) {
                        webSocketService.sendContactAccept(to: request.fromUserId)
                    }
                }
                return true
            } else {
                // Пытаемся получить детали ошибки
                if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let errorMessage = errorDict["detail"] as? String ?? "Unknown error"
                    print("❌ Server error: \(errorMessage)")
                    throw NSError(domain: "API", code: httpResponse.statusCode,
                                 userInfo: [NSLocalizedDescriptionKey: errorMessage])
                } else {
                    print("❌ Unknown server error: \(httpResponse.statusCode)")
                    throw URLError(.badServerResponse)
                }
            }
        } catch {
            print("❌ Network error: \(error)")
            throw error
        }
    }
    
    func getContactsFromServer() async throws -> [Contact] {
        guard let deviceId = KeychainService.shared.loadDeviceId() else {
            throw NSError(domain: "Auth", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Device ID не найден"])
        }
        
        let url = URL(string: "\(apiService.baseURL)/contacts/")!
        
        var request = URLRequest(url: url)
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoder = JSONDecoder.flexibleISO8601
        let response = try decoder.decode(ContactListResponse.self, from: data)
        
        return response.contacts.map { apiContact in
            Contact(
                id: UUID(),
                userId: apiContact.user_id,
                nickname: apiContact.nickname,
                publicKey: apiContact.public_key,
                addedAt: Date() // TODO: Использовать created_at с сервера
            )
        }
    }
    
    func removeContactFromServer(userId: UUID) async throws -> Bool {
        guard let deviceId = KeychainService.shared.loadDeviceId() else {
            throw NSError(domain: "Auth", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Device ID не найден"])
        }
        
        let url = URL(string: "\(apiService.baseURL)/contacts/\(userId.uuidString)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        return httpResponse.statusCode == 200
    }
    
    // MARK: - Local Database Methods
    
    func loadContacts() {
        contacts = database.getContacts()
    }
    
    func loadPendingRequests() {
        pendingRequests = database.getPendingContactRequests()
    }
    
    func saveContactLocally(_ contact: Contact) -> Bool {
        return database.saveContact(contact)
    }
    
    func saveContactRequestLocally(_ request: ContactRequest) -> Bool {
        return database.saveContactRequest(request)
    }
    
    func updateContactRequestStatusLocally(_ requestId: UUID, status: String) -> Bool {
        return database.updateContactRequestStatus(requestId, status: status)
    }
    
    func removeContactLocally(userId: UUID) -> Bool {
        return database.deleteContact(userId: userId)
    }
    
    // MARK: - Business Logic
    
    func sendContactRequest(to user: UserPublicResponse) {
        guard let currentUser = AppState.shared.currentUser else {
            print("❌ Текущий пользователь не найден")
            return
        }
        
        // Проверяем, что не отправляем самому себе
        guard currentUser.id != user.user_id else {
            NotificationService.shared.showError("Нельзя отправить запрос самому себе")
            return
        }
        
        // Проверяем, что пользователь уже не в контактах
        guard !isContact(userId: user.user_id) else {
            NotificationService.shared.showInfo("Пользователь уже в контактах")
            return
        }
        
        print("📤 Отправляем запрос на контакт пользователю \(user.nickname)")
        
        Task {
            do {
                let success = try await sendContactRequest(to: user.user_id)
                
                if success {
                    // Сохраняем локально как исходящий запрос
                    let request = ContactRequest(
                        id: UUID(),
                        fromUserId: currentUser.id,
                        fromNickname: currentUser.nickname,
                        fromPublicKey: currentUser.publicKey,
                        status: "pending",
                        createdAt: Date()
                    )
                    
                    if saveContactRequestLocally(request) {
                        await MainActor.run {
                            loadPendingRequests()
                            NotificationService.shared.showSuccess("Запрос отправлен пользователю \(user.nickname)")
                        }
                    }
                }
            } catch {
                print("❌ Ошибка отправки запроса: \(error)")
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка отправки запроса: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func acceptContactRequest(_ request: ContactRequest) {
        Task {
            do {
                let success = try await respondToContactRequest(requestId: request.id, status: "accepted")
                
                if success {
                    // Обновляем статус локально
                    if updateContactRequestStatusLocally(request.id, status: "accepted") {
                        // Добавляем в контакты
                        let contact = Contact(
                            id: UUID(),
                            userId: request.fromUserId,
                            nickname: request.fromNickname,
                            publicKey: request.fromPublicKey,
                            addedAt: Date()
                        )
                        
                        if saveContactLocally(contact) {
                            await MainActor.run {
                                loadContacts()
                                loadPendingRequests()
                                NotificationService.shared.showSuccess("Контакт \(request.fromNickname) добавлен")
                            }
                        }
                    }
                }
            } catch {
                print("❌ Ошибка принятия запроса: \(error)")
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка принятия запроса: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func declineContactRequest(_ request: ContactRequest) {
        Task {
            do {
                let success = try await respondToContactRequest(requestId: request.id, status: "declined")
                
                if success {
                    // Обновляем статус локально
                    if updateContactRequestStatusLocally(request.id, status: "declined") {
                        await MainActor.run {
                            loadPendingRequests()
                            NotificationService.shared.showInfo("Запрос отклонен")
                        }
                    }
                }
            } catch {
                print("❌ Ошибка отклонения запроса: \(error)")
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка отклонения запроса: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func removeContact(userId: UUID) {
        Task {
            do {
                let success = try await removeContactFromServer(userId: userId)
                
                if success {
                    if removeContactLocally(userId: userId) {
                        await MainActor.run {
                            loadContacts()
                            NotificationService.shared.showInfo("Контакт удален")
                        }
                    }
                }
            } catch {
                print("❌ Ошибка удаления контакта: \(error)")
                await MainActor.run {
                    NotificationService.shared.showError("Ошибка удаления контакта: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func syncContacts() {
        Task {
            do {
                let serverContacts = try await getContactsFromServer()
                
                // Синхронизируем с локальной базой
                for contact in serverContacts {
                    if !isContact(userId: contact.userId) {
                        _ = saveContactLocally(contact)
                    }
                }
                
                await MainActor.run {
                    loadContacts()
                }
            } catch {
                print("❌ Ошибка синхронизации контактов: \(error)")
            }
        }
    }
    
    func syncPendingRequests() {
        Task {
            do {
                let serverRequests = try await getPendingRequests()
                
                // Синхронизируем с локальной базой
                for request in serverRequests {
                    // Проверяем, нет ли уже такого запроса
                    if !pendingRequests.contains(where: { $0.id == request.id }) {
                        _ = saveContactRequestLocally(request)
                    }
                }
                
                await MainActor.run {
                    loadPendingRequests()
                }
            } catch {
                print("❌ Ошибка синхронизации запросов: \(error)")
            }
        }
    }
    
    func isContact(userId: UUID) -> Bool {
        return contacts.contains(where: { $0.userId == userId })
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
        
        // Усиленная проверка: убедимся, что запрос не от самого себя
        guard let currentUserId = AppState.shared.currentUser?.id else {
            print("❌ Текущий пользователь не найден")
            return
        }
        
        // Проверяем, что запрос не от нас самих
        if request.fromUserId == currentUserId {
            print("⚠️ Получен запрос от самого себя, игнорируем")
            return
        }
        
        // Проверяем, что пользователь уже не в контактах
        guard !isContact(userId: request.fromUserId) else {
            print("⚠️ Пользователь уже в контактах")
            return
        }
        
        // Проверяем, не существует ли уже такого запроса
        let existingRequest = pendingRequests.first { $0.fromUserId == request.fromUserId && $0.status == "pending" }
        if existingRequest != nil {
            print("⚠️ Запрос уже существует")
            return
        }
        
        if saveContactRequestLocally(request) {
            loadPendingRequests()
            
            NotificationService.shared.showInfo(
                "Новый запрос на контакт от \(request.fromNickname)"
            )
        }
    }
    
    func handleContactRequestAccepted(_ contact: Contact) {
        print("✅ Запрос на контакт принят: \(contact.nickname)")
        
        if saveContactLocally(contact) {
            loadContacts()
            
            // Обновляем статус исходящего запроса
            if let request = pendingRequests.first(where: { $0.fromUserId == contact.userId }) {
                _ = updateContactRequestStatusLocally(request.id, status: "accepted")
                loadPendingRequests()
            }
            
            NotificationService.shared.showSuccess(
                "\(contact.nickname) принял(а) ваш запрос на контакт"
            )
        }
    }
    
    // MARK: - Search
    
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
}


