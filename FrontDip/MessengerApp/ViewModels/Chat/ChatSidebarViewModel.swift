import Foundation
import Combine

class ChatSidebarViewModel: ObservableObject {
    @Published var members: [ChatMemberDetailed] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private let keychainService = KeychainService.shared
    
    let chat: Chat
    
    init(chat: Chat) {
        self.chat = chat
    }
    
    func loadMembers() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let members = try await apiService.getChatMembers(chatId: chat.id)
                
                await MainActor.run {
                    self.members = members
                    self.isLoading = false
                    print("✅ Загружено участников чата: \(members.count)")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка загрузки участников: \(error.localizedDescription)"
                    self.isLoading = false
                    print("❌ Ошибка загрузки участников чата: \(error)")
                }
            }
        }
    }


    func addUserToChat(_ userId: UUID) async -> Bool {
        guard let deviceId = keychainService.loadDeviceId() else {
            print("❌ Device ID not found")
            return false
        }
        
        do {
            print("📤 Добавляем пользователя в чат \(chat.name)...")
            
            // Функция возвращает Bool напрямую
            let success = try await apiService.inviteUserToChat(
                chatId: chat.id,
                userId: userId,
                deviceId: deviceId
            )
            
            if success {
                print("✅ Пользователь успешно добавлен в чат")
                
                await MainActor.run {
                    // Обновляем список участников
                    loadMembers()
                }
                
                return true
            } else {
                print("❌ Не удалось добавить пользователя")
                return false
            }
            
        } catch {
            print("❌ Ошибка добавления пользователя в чат: \(error)")
            return false
        }
    }
    
    func isUserInChat(_ userId: UUID) -> Bool {
        return members.contains { $0.user_id == userId }
    }
}
