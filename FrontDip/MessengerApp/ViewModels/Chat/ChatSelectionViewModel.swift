import Foundation
import Combine

class ChatSelectionViewModel: ObservableObject {
    @Published var chats: [ChatWithContactInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let graphQL = GraphQLClient.shared
    let contact: Contact
    
    init(contact: Contact) {
        self.contact = contact
    }
    
    func loadChats() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            guard let currentUser = AppState.shared.currentUser else {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Не удалось получить информацию о пользователе"
                }
                return
            }
            
            do {
                let variables: [String: Any] = ["userId": currentUser.id.uuidString]
                let response: ListChatsResponse = try await graphQL.perform(
                    query: GraphQLQueries.listChats,
                    variables: variables,
                    responseType: ListChatsResponse.self
                )
                
                let userChats = response.listChats.chats.map { chatResponse in
                    Chat(
                        id: chatResponse.chatId,
                        chatType: "group",
                        name: chatResponse.name ?? "Chat",
                        description: nil,
                        avatarUrl: nil,
                        creatorId: nil,
                        isPublic: false,
                        membersCount: chatResponse.membersCount,
                        createdAt: chatResponse.createdAt,
                        updatedAt: chatResponse.createdAt,
                        lastMessagePreview: nil
                    )
                }
                
                var chatsWithInfo: [ChatWithContactInfo] = []
                for chat in userChats {
                    let isContactInChat = await checkIfContactInChat(chatId: chat.id)
                    chatsWithInfo.append(ChatWithContactInfo(chat: chat, isContactInChat: isContactInChat))
                }
                
                await MainActor.run {
                    self.chats = chatsWithInfo
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка загрузки чатов: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func checkIfContactInChat(chatId: UUID) async -> Bool {
        do {
            let variables: [String: Any] = ["chatId": chatId.uuidString]
            let response: ChatMembersListResponse = try await graphQL.perform(
                query: GraphQLQueries.getChatMembers,
                variables: variables,
                responseType: ChatMembersListResponse.self
            )
            return response.listChatMembers.members.contains { $0.userId == contact.userId }
        } catch {
            return false
        }
    }
    
    func addContactToChat(_ chat: Chat) async -> Bool {
        let variables: [String: Any] = [
            "chatId": chat.id.uuidString,
            "userId": contact.userId.uuidString
        ]
        do {
            let _: AddChatMemberResponse = try await graphQL.perform(
                query: GraphQLQueries.addChatMember,
                variables: variables,
                responseType: AddChatMemberResponse.self
            )
            await MainActor.run { loadChats() }
            return true
        } catch {
            return false
        }
    }
}
