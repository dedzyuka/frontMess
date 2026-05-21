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
    
    @State private var showSideMenu = false
    @State private var showCreateChatAlert = false
    @State private var showJoinChatAlert = false
    @State private var joinChatKey = ""
    
    @State private var showingSearchView = false
    @State private var showingContactsView = false
    @State private var showingNotificationsView = false
    @State private var notificationData: NotificationData?
    
    var body: some View {
        ZStack {
            NavigationView {
                chatListContent
            }
            .blur(radius: showSideMenu ? 3 : 0)
            .disabled(showSideMenu)
            
            SideMenuView(
                authViewModel: authViewModel,
                isShowing: $showSideMenu,
                showSearchView: $showingSearchView,
                showContactsView: $showingContactsView,
                showNotificationsView: $showingNotificationsView
            )
            .environmentObject(appState)
            .environmentObject(contactService)
        }
        .onAppear {
            setupNotificationObserver()
            Task {
                await viewModel.loadChats()
                contactService.loadContacts()
                contactService.loadPendingRequests()
            }
        }
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
        .notificationAlert(notificationData: $notificationData)
        .createChatAlert(
            showCreateChatAlert: $showCreateChatAlert,
            newChatName: $newChatName,
            createChat: createChat
        )
        .joinChatAlert(
            showJoinChatAlert: $showJoinChatAlert,
            joinChatKey: $joinChatKey,
            joinChat: joinChat
        )
        .inviteSheet(showInviteSheet: $showInviteSheet, inviteKey: inviteKey)
    }
    
    private var chatListContent: some View {
        Group {
            if viewModel.isLoading && viewModel.chats.isEmpty {
                LoadingView()
            } else if viewModel.chats.isEmpty {
                emptyStateView
            } else {
                List(viewModel.chats) { chat in
                    NavigationLink(destination: ChatView(chat: chat)) {
                        ChatRow(chat: chat)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Чаты")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showCreateChatAlert = true }) {
                    Image(systemName: "square.and.pencil")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { withAnimation(.spring()) { showSideMenu = true } }) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(authViewModel.currentUser?.nick_name.prefix(1).uppercased() ?? "?")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
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
    }
    
    private struct ChatRow: View {
        let chat: Chat
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.name ?? "Без названия")
                    .font(.headline)
                Text("\(chat.members_count) участников")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatDate(chat.created_at))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        
        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "ru_RU")
            return formatter.string(from: date)
        }
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
                Button(action: { showCreateChatAlert = true }) {
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
                Button(action: { showJoinChatAlert = true }) {
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
    
    private func createChat() async {
        guard let currentUser = appState.currentUser ?? authViewModel.currentUser else {
            viewModel.errorMessage = "Пользователь не авторизован"
            return
        }
        let chatNameTrimmed = newChatName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chatNameTrimmed.isEmpty else { return }
        
        isLoadingChat = true
        
        let variables: [String: Any] = [
            "chatType": "group",
            "name": chatNameTrimmed,
            "memberIds": [currentUser.id.uuidString],
            "isPublic": false
        ]
        
        do {
            let response: CreateChatResponse = try await GraphQLClient.shared.perform(
                query: GraphQLQueries.createChat,
                variables: variables,
                responseType: CreateChatResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            let newChat = response.chat.create
            
            // Генерация ключа чата (опционально)
            let cryptoService = CryptoService.shared
            let keychainService = KeychainService.shared
            let chatKey = cryptoService.generateSymmetricKey()
            if let publicKeyData = keychainService.loadPublicKey(userId: currentUser.id) {
                let publicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: publicKeyData)
                let encryptedChatKey = try cryptoService.encryptSymmetricKey(chatKey, with: publicKey)
                _ = keychainService.saveChatKey(encryptedChatKey, chatId: newChat.chat_id)
                let chatKeyData = cryptoService.symmetricKeyToData(chatKey)
                ChatKeyManager.shared.saveChatKey(chatKeyData, for: newChat.chat_id)
            }
            
            await MainActor.run {
                isLoadingChat = false
                inviteKey = newChat.chat_id.uuidString
                showInviteSheet = true
                newChatName = ""
                Task { await viewModel.loadChats() }
            }
        } catch {
            await MainActor.run {
                isLoadingChat = false
                viewModel.errorMessage = "Ошибка создания чата: \(error.localizedDescription)"
            }
        }
    }
    
    private func joinChat() {
        // TODO: реализовать присоединение по inviteKey
        print("Присоединяемся к чату с ключом: \(joinChatKey)")
        joinChatKey = ""
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .showNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let data = notification.object as? NotificationData {
                notificationData = data
            }
        }
    }
}

// MARK: - View Modifiers (оставляем как есть)
extension View {
    func notificationAlert(notificationData: Binding<NotificationData?>) -> some View {
        self.alert(
            notificationData.wrappedValue?.type.title ?? "Уведомление",
            isPresented: .constant(notificationData.wrappedValue != nil)
        ) {
            Button("OK") { notificationData.wrappedValue = nil }
        } message: {
            if let message = notificationData.wrappedValue?.message {
                Text(message)
            }
        }
    }
    
    func createChatAlert(
        showCreateChatAlert: Binding<Bool>,
        newChatName: Binding<String>,
        createChat: @escaping () async -> Void
    ) -> some View {
        self.alert("Создать чат", isPresented: showCreateChatAlert) {
            TextField("Название чата", text: newChatName)
            Button("Отмена", role: .cancel) { newChatName.wrappedValue = "" }
            Button("Создать") {
                Task { await createChat() }
            }
            .disabled(newChatName.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Введите название для нового чата")
        }
    }
    
    func joinChatAlert(
        showJoinChatAlert: Binding<Bool>,
        joinChatKey: Binding<String>,
        joinChat: @escaping () -> Void
    ) -> some View {
        self.alert("Присоединиться к чату", isPresented: showJoinChatAlert) {
            TextField("Ключ приглашения", text: joinChatKey)
            Button("Отмена", role: .cancel) { joinChatKey.wrappedValue = "" }
            Button("Присоединиться") { joinChat() }
                .disabled(joinChatKey.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Введите ключ приглашения для присоединения к чату")
        }
    }
    
    func inviteSheet(showInviteSheet: Binding<Bool>, inviteKey: String?) -> some View {
        self.sheet(isPresented: showInviteSheet) {
            if let inviteKey = inviteKey {
                InviteShareView(inviteKey: inviteKey)
            }
        }
    }
}
