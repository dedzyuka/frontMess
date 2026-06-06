//
//  ChatListView.swift
//  FrontDip
//

import SwiftUI

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @State private var showMenu = false
    @State private var showCreateChat = false
    @State private var showJoinChat = false
    @State private var newChatName = ""
    @State private var isCreating = false
    @State private var selectedChat: Chat?
    @State private var showChat = false

    var body: some View {
        NavigationStack {
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
                        Menu {
                            Button("Новый чат") { showCreateChat = true }
                            Button("Присоединиться") { showJoinChat = true }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .navigationDestination(isPresented: $showChat) {
                    if let chat = selectedChat {
                        ChatView(chat: chat)
                    }
                }
        }
        .disabled(showMenu)
        .blur(radius: showMenu ? 5 : 0)
        .onReceive(NotificationCenter.default.publisher(for: .chatCreated)) { _ in
            Task { await viewModel.loadChats() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatUpdated)) { _ in
            Task { await viewModel.loadChats() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openChat)) { notification in
            // Открываем чат только если сайдбар закрыт
            guard !AppState.shared.isSidebarOpen else { return }
            if let chat = notification.object as? Chat {
                selectedChat = chat
                showChat = true
                if !viewModel.chats.contains(where: { $0.id == chat.id }) {
                    viewModel.addChat(chat)
                }
            }
        }
        .sheet(isPresented: $showJoinChat) {
            JoinChatView()
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
        .onAppear {
            Task { await viewModel.loadChats() }
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
                ChatRow(chat: chat, currentUserId: AppState.shared.currentUser?.userId)
                    .onTapGesture {
                        // Открываем чат только если сайдбар закрыт
                        guard !AppState.shared.isSidebarOpen else { return }
                        selectedChat = chat
                        showChat = true
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

// MARK: - ChatRow (без изменений)
struct ChatRow: View {
    let chat: Chat
    let currentUserId: UUID?
    
    private var isPrivateChat: Bool { chat.isPrivate }
    
    var body: some View {
        HStack(spacing: 12) {
            if isPrivateChat {
                AvatarView(urlString: chat.otherUserAvatarUrl, size: 50)
                    .overlay(
                        Circle()
                            .fill(chat.otherUserIsOnline ? Color.green : Color.gray)
                            .frame(width: 12, height: 12)
                            .offset(x: 18, y: 18)
                    )
            } else {
                if let avatarUrl = chat.avatarUrl, !avatarUrl.isEmpty {
                    AvatarView(urlString: avatarUrl, size: 50)
                } else {
                    Circle()
                        .fill(chat.isGroup ? Color.blue.opacity(0.2) : Color.purple.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: chat.isGroup ? "person.2.fill" : "megaphone.fill")
                                .foregroundColor(chat.isGroup ? .blue : .purple)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if isPrivateChat {
                    Text(chat.otherUserNickname ?? "Загрузка...")
                        .font(.headline)
                } else {
                    Text(chat.name ?? "Чат")
                        .font(.headline)
                }
                
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

