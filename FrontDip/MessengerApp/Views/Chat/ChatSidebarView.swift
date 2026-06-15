import SwiftUI

struct ChatSidebarView: View {
    let chat: Chat
    @ObservedObject var chatViewModel: ChatViewModel

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChatSidebarViewModel

    init(chat: Chat, chatViewModel: ChatViewModel) {
        self.chat = chat
        self.chatViewModel = chatViewModel
        _viewModel = StateObject(wrappedValue: ChatSidebarViewModel(chat: chat))
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            Group {
                if !chatViewModel.searchQuery.isEmpty {
                    searchContent
                } else if chat.isPrivate {
                    privateChatContent
                } else if chat.isGroup {
                    groupChatContent
                } else {
                    channelContent
                }
            }
        }
        .messengerBackground()
        .navigationTitle(chatTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Закрыть") {
                    dismiss()
                }
            }
        }
        .onAppear {
            AppState.shared.isSidebarOpen = true
            viewModel.loadMembers()
        }
        .onDisappear {
            AppState.shared.isSidebarOpen = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatUpdated)) { notification in
            if let updatedChat = notification.object as? Chat, updatedChat.id == chat.id {
                viewModel.loadMembers()
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var chatTitle: String {
        if chat.isPrivate {
            return chat.name ?? "Профиль"
        }
        return chat.name ?? "Чат"
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Поиск по сообщениям", text: $chatViewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    chatViewModel.searchMessages()
                }

            if !chatViewModel.searchQuery.isEmpty {
                Button {
                    chatViewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(MessengerTheme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MessengerTheme.divider, lineWidth: 0.8)
        )
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var searchContent: some View {
        if chatViewModel.isSearching {
            VStack(spacing: 14) {
                ProgressView()
                Text("Ищем сообщения…")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if chatViewModel.searchResults.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("Ничего не найдено")
                    .font(.system(size: 17, weight: .semibold))

                Text("Попробуй изменить запрос или сократить его.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(chatViewModel.searchResults) { message in
                        SearchMessResultRow(
                            message: message,
                            chatViewModel: chatViewModel,
                            onDismiss: {
                                dismiss()
                            }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
            }
        }
    }

    private var privateChatContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                if let otherUser = viewModel.otherUser {
                    profileHeader(
                        avatarUrl: otherUser.avatarUrl,
                        title: otherUser.nickName,
                        subtitle: otherUser.bio
                    )

                    statusCard(
                        isOnline: otherUser.isOnline == true,
                        lastSeen: otherUser.lastSeen
                    )

                    VStack(spacing: 12) {
                        Button {
                            dismiss()
                            NotificationCenter.default.post(name: .openChat, object: chat)
                        } label: {
                            Text("Открыть диалог")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(MessengerTheme.selfBubbleGradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        if viewModel.isContact {
                            Button(role: .destructive) {
                                Task {
                                    do {
                                        try await ContactService.shared.removeContact(userId: otherUser.userId.uuidString)
                                        await MainActor.run {
                                            viewModel.isContact = false
                                        }
                                        NotificationService.shared.showInfo("Контакт удалён")
                                    } catch {
                                        NotificationService.shared.showError(error.localizedDescription)
                                    }
                                }
                            } label: {
                                Text("Удалить из контактов")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.red.opacity(0.10))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                Task {
                                    do {
                                        try await ContactService.shared.sendContactRequest(to: otherUser.userId.uuidString)
                                        await MainActor.run {
                                            viewModel.isContact = true
                                        }
                                        NotificationService.shared.showSuccess("Запрос отправлен")
                                    } catch {
                                        NotificationService.shared.showError(error.localizedDescription)
                                    }
                                }
                            } label: {
                                Text("Добавить в контакты")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(MessengerTheme.elevatedBackground)
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(MessengerTheme.divider, lineWidth: 0.8)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var groupChatContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                profileHeader(
                    avatarUrl: chat.avatarUrl,
                    title: chat.name ?? "Групповой чат",
                    subtitle: chat.description
                )

                groupActions

                if !viewModel.activeMembers.isEmpty {
                    membersSection(
                        title: "Участники",
                        members: viewModel.activeMembers
                    )
                }

                if !viewModel.bannedMembers.isEmpty {
                    membersSection(
                        title: "Заблокированные",
                        members: viewModel.bannedMembers
                    )
                }

                bottomDangerZone
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 26)
        }
    }

    private var channelContent: some View {
        groupChatContent
    }

    private func profileHeader(
        avatarUrl: String?,
        title: String,
        subtitle: String?
    ) -> some View {
        VStack(spacing: 14) {
            if let avatarUrl, !avatarUrl.isEmpty {
                AvatarView(urlString: avatarUrl, size: 108)
                    .padding(.top, 12)
            } else {
                Circle()
                    .fill(MessengerTheme.secondarySurface)
                    .frame(width: 108, height: 108)
                    .overlay {
                        Image(systemName: chat.isGroup ? "person.2.fill" : "megaphone.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(chat.isGroup ? Color.teal : MessengerTheme.accent)
                    }
                    .padding(.top, 12)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .multilineTextAlignment(.center)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func statusCard(isOnline: Bool, lastSeen: Date?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isOnline ? Color.green : Color.gray.opacity(0.7))
                    .frame(width: 10, height: 10)

                Text(isOnline ? "Сейчас в сети" : "Не в сети")
                    .font(.system(size: 15, weight: .semibold))
            }

            if let lastSeen {
                Text("Последний визит: \(relativeDate(lastSeen))")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(MessengerTheme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MessengerTheme.divider, lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
    }

    private var groupActions: some View {
        VStack(spacing: 12) {
            if viewModel.currentUserRole == "owner" || viewModel.currentUserRole == "admin" {
                Button {
                    let editView = EditChatView(chat: chat)
                    present(editView)
                } label: {
                    actionRow(
                        icon: "pencil",
                        title: "Редактировать чат",
                        tint: .primary
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        if let link = await viewModel.generateInviteLink() {
                            shareLink(link)
                        }
                    }
                } label: {
                    actionRow(
                        icon: "link",
                        title: "Поделиться invite-link",
                        tint: MessengerTheme.accent
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func actionRow(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(MessengerTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(14)
        .background(MessengerTheme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MessengerTheme.divider, lineWidth: 0.8)
        )
    }

    private func membersSection(title: String, members: [ChatMemberItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 16)

            LazyVStack(spacing: 10) {
                ForEach(members) { member in
                    MemberRow(
                        member: member,
                        currentUserRole: viewModel.currentUserRole,
                        onRoleChange: { userId, newRole in
                            Task {
                                await viewModel.updateMemberRole(userId: userId, role: newRole)
                            }
                        },
                        onKick: { userId in
                            Task {
                                await viewModel.kickMember(userId: userId)
                            }
                        },
                        onBan: { userId, until in
                            Task {
                                await viewModel.banMember(userId: userId, until: until)
                            }
                        },
                        onUnban: { userId in
                            Task {
                                await viewModel.unbanMember(userId: userId)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var bottomDangerZone: some View {
        VStack(spacing: 12) {
            if viewModel.currentUserRole == "owner" {
                Button(role: .destructive) {
                    confirmDelete()
                } label: {
                    Text("Удалить чат")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button(role: .destructive) {
                    confirmLeave()
                } label: {
                    Text("Покинуть чат")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func present<V: View>(_ view: V) {
        let vc = UIHostingController(rootView: view)
        UIApplication.shared.windows.first?.rootViewController?.present(vc, animated: true)
    }

    private func shareLink(_ link: String) {
        let fullLink = "https://yourapp.com/join/\(link)"
        let av = UIActivityViewController(activityItems: [fullLink], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
    }

    private func confirmDelete() {
        let alert = UIAlertController(
            title: "Удалить чат?",
            message: "Это действие нельзя отменить.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { _ in
            Task {
                await MainActor.run {
                    dismiss()
                }

                if await viewModel.deleteChat() {
                    NotificationCenter.default.post(name: .chatDeleted, object: chat.id)
                }
            }
        })

        UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
    }

    private func confirmLeave() {
        let alert = UIAlertController(
            title: "Покинуть чат?",
            message: "Ты перестанешь видеть новые сообщения этого чата.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Покинуть", style: .destructive) { _ in
            Task {
                if await viewModel.leaveChat() {
                    await MainActor.run {
                        NotificationCenter.default.post(name: .chatDeleted, object: chat.id)
                        dismiss()
                    }
                }
            }
        })

        UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct MemberRow: View {
    let member: ChatMemberItem
    let currentUserRole: String
    let onRoleChange: (UUID, String) -> Void
    let onKick: (UUID) -> Void
    let onBan: (UUID, Date?) -> Void
    let onUnban: (UUID) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                let profileView = UserProfileView(userId: member.userId)
                let hosting = UIHostingController(rootView: profileView)
                UIApplication.shared.windows.first?.rootViewController?.present(hosting, animated: true)
            } label: {
                HStack(spacing: 12) {
                    AvatarView(urlString: member.avatarUrl, size: 42)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.nickName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(roleText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            if member.status == "banned" {
                Text("BANNED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)

                if currentUserRole == "owner" || currentUserRole == "admin" {
                    Button {
                        onUnban(member.userId)
                    } label: {
                        Text("Разбанить")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(MessengerTheme.elevatedBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else if currentUserRole == "owner" || currentUserRole == "admin", member.role != "owner" {
                Menu {
                    if currentUserRole == "owner" {
                        let newRole = member.role == "admin" ? "member" : "admin"
                        Button(newRole == "admin" ? "Сделать админом" : "Сделать участником") {
                            onRoleChange(member.userId, newRole)
                        }
                    }

                    Button("Исключить", role: .destructive) {
                        onKick(member.userId)
                    }

                    Button("Забанить", role: .destructive) {
                        onBan(member.userId, nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(MessengerTheme.accent)
                        .frame(width: 34, height: 34)
                }
            }
        }
        .padding(14)
        .background(MessengerTheme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MessengerTheme.divider, lineWidth: 0.8)
        )
    }

    private var roleText: String {
        switch member.role ?? "member" {
        case "owner":
            return "owner"
        case "admin":
            return "admin"
        default:
            return "member"
        }
    }
}

struct SearchMessResultRow: View {
    let message: Message
    let chatViewModel: ChatViewModel
    let onDismiss: () -> Void

    var body: some View {
        Button {
            onDismiss()
            AppState.shared.isSidebarOpen = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                AppState.shared.pendingScrollToMessageId = message.messageId
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(chatViewModel.getUserNickname(for: message.senderId))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(message.content ?? "Вложение")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(formatDate(message.createdAt))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(MessengerTheme.elevatedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MessengerTheme.divider, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy HH:mm"
        return formatter.string(from: date)
    }
}

extension Notification.Name {
    static let chatDeleted = Notification.Name("chatDeleted")
}
