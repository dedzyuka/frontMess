//
//  ChatListView.swift
//  FrontDip
//

import SwiftUI

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @State private var showMenu = false
    @State private var showCreateChat = false
    @State private var newChatName = ""
    @State private var isCreating = false
    @State private var selectedChat: Chat?
    @State private var showChat = false

    var body: some View {
        ZStack {
            NavigationView {
                mainContent
                    .navigationTitle("Чаты")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                withAnimation(.spring()) { showMenu.toggle() }
                            } label: {
                                Image(systemName: "line.horizontal.3")
                                    .font(.title2)
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showCreateChat = true
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }
                        }
                    }
                    .background(
                        NavigationLink(destination: selectedChat.map { ChatView(chat: $0) }, isActive: $showChat) {
                            EmptyView()
                        }
                    )
            }
            .disabled(showMenu)
            .blur(radius: showMenu ? 5 : 0)
            .onReceive(NotificationCenter.default.publisher(for: .chatCreated)) { notification in
                if let newChat = notification.object as? Chat {
                    viewModel.addChat(newChat)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openChat)) { notification in
                if let chat = notification.object as? Chat {
                    selectedChat = chat
                    showChat = true
                    if !viewModel.chats.contains(where: { $0.id == chat.id }) {
                        viewModel.addChat(chat)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .newMessageReceived)) { _ in
                if self.selectedChat == nil {
                    Task { await viewModel.loadChats() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .messageUpdated)) { _ in
                Task { await viewModel.loadChats() }
            }
            

            SideMenuView(isShowing: $showMenu)
                .environmentObject(viewModel)
        }
        .onAppear {
            Task { await viewModel.loadChats() }
        }
        .alert("Новый чат", isPresented: $showCreateChat) {
            TextField("Название", text: $newChatName)
            Button("Отмена", role: .cancel) {
                newChatName = ""
                isCreating = false
            }
            Button("Создать") {
                isCreating = true
                Task {
                    await viewModel.createChat(name: newChatName)
                    isCreating = false
                    showCreateChat = false
                }
            }
            .disabled(newChatName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
        } message: {
            Text("Введите название группового чата")
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading && viewModel.chats.isEmpty {
            LoadingView()
        } else if viewModel.chats.isEmpty {
            VStack(spacing: 24) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("Нет чатов")
                    .font(.title2)
                Text("Создайте первый чат или присоединитесь по приглашению")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                Button("Создать чат") {
                    showCreateChat = true
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            List(viewModel.chats) { chat in
                NavigationLink(destination: ChatView(chat: chat)) {
                    ChatRow(chat: chat, currentUserId: AppState.shared.currentUser?.userId)
                }
                .id(chat.id)
            }
            .listStyle(PlainListStyle())
            .refreshable {
                await viewModel.loadChats()
            }
        }
    }
}

// MARK: - ChatRow
struct ChatRow: View {
    let chat: Chat
    let currentUserId: UUID?
    
    // Вычисляемое свойство для проверки приватного чата
    private var isPrivateChat: Bool {
        chat.chatType == "1" || chat.chatType.lowercased() == "private"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Аватар для приватного чата
            if isPrivateChat {
                AvatarView(urlString: chat.otherUserAvatarUrl, size: 50)
                    .overlay(
                        Circle()
                            .fill(chat.otherUserIsOnline ? Color.green : Color.gray)
                            .frame(width: 12, height: 12)
                            .offset(x: 18, y: 18)
                    )
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text((chat.name?.prefix(1).uppercased() ?? "?"))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Имя собеседника или название группы
                if isPrivateChat {
                    Text(chat.otherUserNickname ?? "Загрузка...")
                        .font(.headline)
                } else {
                    Text(chat.name ?? "Чат")
                        .font(.headline)
                }
                
                // Статус печати или последнее сообщение
                if isPrivateChat && chat.isTyping {
                    Text("печатает...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else if let preview = chat.lastMessagePreview {
                    HStack(spacing: 4) {
                        if !isPrivateChat && preview.senderId != currentUserId {
                            (Text(preview.senderNickname ?? "Кто-то")
                                .font(.caption)
                                .foregroundColor(.secondary) +
                             Text(": ")
                                .font(.caption)
                                .foregroundColor(.secondary) +
                             Text(preview.textPreview ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary))
                        } else {
                            Text(preview.textPreview ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if preview.senderId == currentUserId, let status = chat.lastMessageStatus {
                            Spacer().frame(width: 4)
                            MessageStatusIcon(status: status)
                                .font(.caption2)
                        }
                    }
                    .lineLimit(1)
                } else {
                    Text("Нет сообщений")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let preview = chat.lastMessagePreview {
                    Text(formatDate(preview.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if chat.unreadCount > 0 && (chat.lastMessagePreview?.senderId != currentUserId) {
                    Text("\(chat.unreadCount)")
                        .font(.caption2)
                        .padding(6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct MessageStatusIcon: View {
    let status: MessageStatusType
    var body: some View {
        switch status {
        case .sending: Image(systemName: "clock").foregroundColor(.gray)
        case .delivered: Image(systemName: "checkmark").foregroundColor(.gray)
        case .read: HStack(spacing: 2) {
            Image(systemName: "checkmark")
            Image(systemName: "checkmark")
        }
        .foregroundColor(.blue)
        }
    }
}
