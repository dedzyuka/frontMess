import Foundation
import Combine

class ChatSelectionViewModel: ObservableObject {
    @Published var chats: [ChatWithContactInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private let contactService = ContactService.shared
    
    let contact: Contact
    private var chatListViewModel = ChatListViewModel()
    
    init(contact: Contact) {
        self.contact = contact
    }
    
    func loadChats() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            guard let currentUser = AppState.shared.currentUser,
                  let deviceId = KeychainService.shared.loadDeviceId() else {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Не удалось получить информацию о пользователе"
                }
                return
            }
            
            do {
                // Загружаем чаты пользователя
                let userChats = try await apiService.getUserChats(
                    userId: currentUser.id,
                    deviceId: deviceId
                )
                
                // Для каждого чата проверяем, есть ли в нем контакт
                var chatsWithInfo: [ChatWithContactInfo] = []
                
                for chat in userChats {
                    let isContactInChat = await checkIfContactInChat(chatId: chat.id)
                    let chatInfo = ChatWithContactInfo(
                        chat: chat,
                        isContactInChat: isContactInChat
                    )
                    chatsWithInfo.append(chatInfo)
                }
                
                await MainActor.run {
                    self.chats = chatsWithInfo
                    self.isLoading = false
                    print("✅ Загружено чатов: \(chatsWithInfo.count)")
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка загрузки чатов: \(error.localizedDescription)"
                    self.isLoading = false
                    print("❌ Ошибка загрузки чатов: \(error)")
                }
            }
        }
    }
    
    private func checkIfContactInChat(chatId: UUID) async -> Bool {
        do {
            let members = try await apiService.getChatMembers(chatId: chatId)
            return members.contains { $0.user_id == contact.userId }
        } catch {
            print("❌ Ошибка проверки участников чата: \(error)")
            return false
        }
    }
    
    // Обновляем метод addContactToChat:
    
    func addContactToChat(_ chat: Chat) async -> Bool {
        guard let deviceId = KeychainService.shared.loadDeviceId() else {
            print("❌ Device ID not found")
            return false
        }
        
        do {
            print("📤 Приглашаем пользователя \(contact.nickname) в чат \(chat.name)...")
            
            // Функция возвращает Bool напрямую
            let success = try await apiService.inviteUserToChat(
                chatId: chat.id,
                userId: contact.userId,
                deviceId: deviceId
            )
            
            if success {
                print("✅ Пользователь успешно приглашен в чат")
                
                await MainActor.run {
                    // Обновляем список чатов
                    loadChats()
                }
                
                return true
            } else {
                print("❌ Не удалось пригласить пользователя")
                return false
            }
            
        } catch {
            print("❌ Ошибка приглашения пользователя в чат: \(error)")
            return false
        }
    }
}
