// ./FrontDip/MessengerApp/Views/Chat/ChatListView.swift
import SwiftUI
import CryptoKit

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @EnvironmentObject var appState: AppState
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var contactService = ContactService.shared
    
    @State private var newChatName = ""
    @State private var isLoadingChat = false
    @State private var showInviteSheet = false
    @State private var inviteKey: String?
    
    // Для бокового меню
    @State private var showSideMenu = false
    @State private var showCreateChatAlert = false
    @State private var showJoinChatAlert = false
    @State private var joinChatKey = ""
    
    // Новые состояния для управления показами View
    @State private var showingSearchView = false
    @State private var showingContactsView = false
    @State private var showingNotificationsView = false
    
    @State private var notificationMessage: String?
    @State private var showingNotification = false
    @State private var notificationType: NotificationType = .info

    enum NotificationType {
        case success, error, info
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                Group {
                    if viewModel.isLoading && viewModel.chats.isEmpty {
                        LoadingView()
                    } else if viewModel.chats.isEmpty {
                        emptyStateView
                    } else {
                        List(viewModel.chats) { chat in
                            NavigationLink(destination: ChatView(chat: chat)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(chat.name)
                                        .font(.headline)
                                    
                                    Text("\(chat.memberCount) участников")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(formatDate(chat.createdAt))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                .navigationTitle("Чаты")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation(.spring()) {
                                showCreateChatAlert = true
                            }
                        }) {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            withAnimation(.spring()) {
                                showSideMenu = true
                            }
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Circle()
                                    .fill(Color.blue.opacity(0.8))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(authViewModel.currentUser?.nickname.prefix(1).uppercased() ?? "?")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                
                                // Бейдж с количеством уведомлений
                                if !contactService.pendingRequests.isEmpty {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 12, height: 12)
                                        .overlay(
                                            Text("\(contactService.pendingRequests.count)")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadChats()
                }
                .onAppear {
                    Task {
                        // Обновляем пользователя в viewModel
                        viewModel.currentUser = authViewModel.currentUser ?? appState.currentUser
                        await viewModel.loadChats()
                        
                        // Обновляем контакты
                        contactService.loadContacts()
                        contactService.loadPendingRequests()
                    }
                }
            }
            .blur(radius: showSideMenu ? 3 : 0)
            .disabled(showSideMenu)
            
            // Боковое меню
            SideMenuView(
                authViewModel: authViewModel,
                isShowing: $showSideMenu,
                showSearchView: $showingSearchView,
                showContactsView: $showingContactsView,
                showNotificationsView: $showingNotificationsView
            )
            .environmentObject(appState)
            .environmentObject(contactService)
        }.onAppear {
            // Подписываемся на уведомления
            NotificationCenter.default.addObserver(forName: .showNotification, object: nil, queue: .main) { notification in
                if let data = notification.object as? NotificationData {
                    notificationMessage = data.message
                    // Преобразуем тип уведомления
                    switch data.type {
                    case .success:
                        notificationType = .success
                    case .error:
                        notificationType = .error
                    case .info:
                        notificationType = .info
                    }
                    showingNotification = true
                } else if let message = notification.object as? String {
                    // Для обратной совместимости с старыми уведомлениями
                    notificationMessage = message
                    notificationType = .info
                    showingNotification = true
                }
            }
        }
        .alert(isPresented: $showingNotification) {
            Alert(
                title: Text(notificationType.title),
                message: Text(notificationMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
        // Sheet модификаторы для новых View
        .sheet(isPresented: $showingSearchView) {
            SearchView()
                .environmentObject(contactService)
        }
        .sheet(isPresented: $showingContactsView) {
            ContactsView()
                .environmentObject(contactService)
        }
        .sheet(isPresented: $showingNotificationsView) {
            NotificationsView()
                .environmentObject(contactService)
        }
        .alert("Создать чат", isPresented: $showCreateChatAlert) {
            TextField("Название чата", text: $newChatName)
            
            Button("Отмена", role: .cancel) {
                newChatName = ""
            }
            
            Button("Создать") {
                Task {
                    await createChat()
                }
            }
            .disabled(newChatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Введите название для нового чата")
        }
        .alert("Присоединиться к чату", isPresented: $showJoinChatAlert) {
            TextField("Ключ приглашения", text: $joinChatKey)
            
            Button("Отмена", role: .cancel) {
                joinChatKey = ""
            }
            
            Button("Присоединиться") {
                Task {
                    await joinChat()
                }
            }
            .disabled(joinChatKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Введите ключ приглашения для присоединения к чату")
        }
        .sheet(isPresented: $showInviteSheet) {
            if let inviteKey = inviteKey {
                InviteShareView(inviteKey: inviteKey)
            }
        }.alert(isPresented: $showingNotification) {
            Alert(
                title: Text(notificationType == .success ? "Успех" :
                           notificationType == .error ? "Ошибка" : "Информация"),
                message: Text(notificationMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func createChat() async {
        guard let userId = authViewModel.currentUser?.id ?? appState.currentUser?.id,
              let deviceId = KeychainService.shared.loadDeviceId() else {
            return
        }
        
        isLoadingChat = true
        
        do {
            let chat = try await APIService.shared.createChat(
                name: newChatName,
                creatorId: userId,
                deviceId: deviceId
            )
            
            // Генерируем и сохраняем ключ чата
            await saveChatKey(for: chat.id, userId: userId)
            
            await MainActor.run {
                inviteKey = chat.id.uuidString
                showInviteSheet = true
                newChatName = ""
                isLoadingChat = false
                
                // Обновляем список чатов
                viewModel.chats.insert(chat, at: 0)
            }
            
        } catch {
            await MainActor.run {
                viewModel.errorMessage = "Ошибка создания чата: \(error.localizedDescription)"
                isLoadingChat = false
            }
        }
    }
    
    private func saveChatKey(for chatId: UUID, userId: UUID) async {
        do {
            let cryptoService = CryptoService.shared
            let keychainService = KeychainService.shared
            
            let chatKey = cryptoService.generateSymmetricKey()
            
            guard let publicKeyData = keychainService.loadPublicKey(userId: userId) else {
                print("❌ Публичный ключ не найден")
                return
            }
            
            let publicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: publicKeyData)
            let encryptedChatKey = try cryptoService.encryptSymmetricKey(chatKey, with: publicKey)
            
            _ = keychainService.saveChatKey(encryptedChatKey, chatId: chatId)
            
            let chatKeyData = cryptoService.symmetricKeyToData(chatKey)
            ChatKeyManager.shared.saveChatKey(chatKeyData, for: chatId)
            
        } catch {
            print("❌ Ошибка сохранения ключа чата: \(error)")
        }
    }
    
    private func joinChat() {
        // TODO: Реализовать присоединение к чату
        print("Присоединяемся к чату с ключом: \(joinChatKey)")
        joinChatKey = ""
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("Нет чатов")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Создайте первый чат или присоединитесь к существующему")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    showCreateChatAlert = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Создать чат")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
                Button(action: {
                    showJoinChatAlert = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Присоединиться к чату")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}
