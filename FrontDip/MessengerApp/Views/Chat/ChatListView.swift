import SwiftUI

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @EnvironmentObject private var contactService: ContactService

    @State private var showMenu = false
    @State private var showCreateChat = false
    @State private var showJoinChat = false
    @State private var newChatName = ""
    @State private var isCreating = false

    @State private var selectedChat: Chat?
    @State private var showChat = false

    @State private var activeMenuDestination: SideMenuView.Destination?

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                mainContent
                    .navigationTitle("Чаты")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                                    showMenu.toggle()
                                    AppState.shared.isSidebarOpen = showMenu
                                }
                            } label: {
                                Image(systemName: "line.horizontal.3")
                                    .font(.title2)
                            }
                        }

                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Button("Создать чат") {
                                    showCreateChat = true
                                }

                                Button("Вступить по ссылке") {
                                    showJoinChat = true
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title3)
                            }
                        }
                    }
                    .navigationDestination(isPresented: $showChat) {
                        if let chat = selectedChat {
                            ChatView(chat: chat)
                        } else {
                            EmptyView()
                        }
                    }
            }
            .disabled(showMenu)
            .blur(radius: showMenu ? 4 : 0)

            if showMenu {
                SideMenuView(isShowing: $showMenu) { destination in
                    activeMenuDestination = destination
                }
                .environmentObject(viewModel)
                .transition(.move(edge: .leading))
                .zIndex(10)
            }
        }
        .sheet(item: $activeMenuDestination) { destination in
            menuSheet(for: destination)
        }
        .sheet(isPresented: $showJoinChat) {
            JoinChatView()
        }
        .alert("Новый чат", isPresented: $showCreateChat) {
            TextField("Название чата", text: $newChatName)

            Button("Отмена", role: .cancel) {
                newChatName = ""
                isCreating = false
            }

            Button("Создать") {
                createChat()
            }
            .disabled(newChatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
        } message: {
            Text("Введите название нового чата.")
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            Task {
                await viewModel.loadChats()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatCreated)) { _ in
            Task {
                await viewModel.loadChats()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatUpdated)) { _ in
            Task {
                await viewModel.loadChats()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openChat)) { notification in
            guard let chat = notification.object as? Chat else { return }
            openChat(chat)
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatDeleted)) { notification in
            guard let deletedChatId = notification.object as? UUID else { return }

            if selectedChat?.id == deletedChatId {
                selectedChat = nil
                showChat = false
            }

            Task {
                await viewModel.loadChats()
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading && viewModel.chats.isEmpty {
            LoadingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.chats.isEmpty {
            VStack(spacing: 24) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)

                Text("Пока нет чатов")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Создай новый чат или вступи по ссылке, чтобы начать общение.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Button("Создать чат") {
                    showCreateChat = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            List(viewModel.chats) { chat in
                ChatRow(
                    chat: chat,
                    currentUserId: AppState.shared.currentUser?.userId
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    openChat(chat)
                }
                .id(chat.id)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.loadChats()
            }
        }
    }

    @ViewBuilder
    private func menuSheet(for destination: SideMenuView.Destination) -> some View {
        switch destination {
        case .profile:
            NavigationStack {
                ProfileView()
            }

        case .contacts:
            ContactsView()
                .environmentObject(contactService)

        case .search:
            SearchView()
                .environmentObject(contactService)

        case .notifications:
            NotificationsView()
                .environmentObject(contactService)

        case .privacy:
            NavigationStack {
                PrivacySettingsView()
            }

        case .sessions:
            NavigationStack {
                SessionsView()
            }
        }
    }

    private func createChat() {
        let trimmedName = newChatName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !isCreating else { return }

        isCreating = true

        Task {
            await viewModel.createChat(name: trimmedName)

            await MainActor.run {
                isCreating = false
                showCreateChat = false
                newChatName = ""
            }
        }
    }

    private func openChat(_ chat: Chat) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            showMenu = false
            AppState.shared.isSidebarOpen = false
        }

        if !viewModel.chats.contains(where: { $0.id == chat.id }) {
            viewModel.addChat(chat)
        }

        NotificationCenter.default.post(name: .chatOpened, object: chat.id)

        selectedChat = chat
        showChat = true
    }
}

struct ChatRow: View {
    let chat: Chat
    let currentUserId: UUID?

    private var isPrivateChat: Bool {
        chat.isPrivate
    }

    private var isGroupChat: Bool {
        let type = chat.chatType.lowercased()
        return type == "group" || type == "2"
    }

    private var titleText: String {
        if isPrivateChat {
            return chat.otherUserNickname ?? chat.name ?? "Личный чат"
        }
        return chat.name ?? "Без названия"
    }

    private var previewText: String {
        guard let preview = chat.lastMessagePreview else {
            return "Сообщений пока нет"
        }

        if preview.type.lowercased() != "text" && (preview.textPreview?.isEmpty ?? true) {
            return messageTypeTitle(preview.type)
        }

        return preview.textPreview ?? "Сообщение"
    }

    private var shouldShowUnreadBadge: Bool {
        guard chat.unreadCount > 0 else { return false }
        guard let preview = chat.lastMessagePreview else { return false }
        guard let currentUserId else { return false }
        return preview.senderId != currentUserId
    }

    var body: some View {
        HStack(spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if isPrivateChat && chat.isTyping {
                    Text("печатает...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(1)
                } else {
                    HStack(spacing: 4) {
                        if let preview = chat.lastMessagePreview {
                            if !isPrivateChat,
                               let currentUserId,
                               preview.senderId != currentUserId {
                                Text(preview.senderNickname ?? "Неизвестно")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)

                                Text("·")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text(previewText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            if let currentUserId,
                               preview.senderId == currentUserId,
                               let status = chat.lastMessageStatus {
                                Spacer(minLength: 4)

                                MessageStatusIcon(status: status)
                                    .font(.caption2)
                            }
                        } else {
                            Text("Сообщений пока нет")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if let preview = chat.lastMessagePreview {
                    Text(formatDate(preview.createdAt))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                if shouldShowUnreadBadge {
                    Text("\(chat.unreadCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private var avatarView: some View {
        if isPrivateChat {
            AvatarView(urlString: chat.otherUserAvatarUrl, size: 50)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(chat.otherUserIsOnline ? Color.green : Color.gray.opacity(0.6))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                }
        } else if let avatarUrl = chat.avatarUrl, !avatarUrl.isEmpty {
            AvatarView(urlString: avatarUrl, size: 50)
        } else {
            Circle()
                .fill(isGroupChat ? Color.blue.opacity(0.18) : Color.purple.opacity(0.18))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: isGroupChat ? "person.2.fill" : "megaphone.fill")
                        .foregroundColor(isGroupChat ? .blue : .purple)
                }
        }
    }

    private func messageTypeTitle(_ type: String) -> String {
        switch type.lowercased() {
        case "image":
            return "Изображение"
        case "video":
            return "Видео"
        case "audio", "voice":
            return "Аудио"
        case "file", "document":
            return "Файл"
        default:
            return "Сообщение"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }

        if calendar.isDateInYesterday(date) {
            return "Вчера"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")

        if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "d MMM"
        } else {
            formatter.dateFormat = "dd.MM.yy"
        }

        return formatter.string(from: date)
    }
}

struct MessageStatusIcon: View {
    let status: MessageStatusType

    var body: some View {
        switch status {
        case .sending:
            Image(systemName: "clock")
                .foregroundColor(.gray)

        case .delivered:
            HStack(spacing: 2) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .foregroundColor(.gray)

        case .read:
            HStack(spacing: 2) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .foregroundColor(.blue)
        }
    }
}
