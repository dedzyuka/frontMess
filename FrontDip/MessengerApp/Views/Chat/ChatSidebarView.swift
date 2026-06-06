//
//  ChatSidebarView.swift
//  FrontDip
//

import SwiftUI

// MARK: - ChatSidebarView
struct ChatSidebarView: View {
    let chat: Chat
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ChatSidebarViewModel
    
    init(chat: Chat) {
        self.chat = chat
        _viewModel = StateObject(wrappedValue: ChatSidebarViewModel(chat: chat))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if chat.isPrivate {
                    privateChatContent
                } else if chat.isGroup {
                    groupChatContent
                } else {
                    channelContent
                }
            }
            .navigationTitle(chat.isPrivate ? "Информация" : (chat.name ?? "Чат"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
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
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Личный чат
    private var privateChatContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let otherUser = viewModel.otherUser {
                    AvatarView(urlString: otherUser.avatarUrl, size: 100)
                        .padding(.top, 20)
                    
                    Text(otherUser.nickName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let bio = otherUser.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    HStack {
                        Circle()
                            .fill(otherUser.isOnline == true ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        Text(otherUser.isOnline == true ? "онлайн" : "офлайн")
                            .font(.subheadline)
                    }
                    
                    if let lastSeen = otherUser.lastSeen {
                        Text("Был(а) \(relativeDate(lastSeen))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Написать") {
                        dismiss()
                        NotificationCenter.default.post(name: .openChat, object: chat)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if viewModel.isContact {
                        Button("Удалить из контактов", role: .destructive) {
                            Task {
                                do {
                                    try await ContactService.shared.removeContact(userId: otherUser.userId.uuidString)
                                    viewModel.isContact = false
                                    NotificationService.shared.showInfo("Контакт удалён")
                                } catch {
                                    NotificationService.shared.showError(error.localizedDescription)
                                }
                            }
                        }
                    } else {
                        Button("Добавить в контакты") {
                            Task {
                                do {
                                    _ = try await ContactService.shared.sendContactRequest(to: otherUser.userId.uuidString)
                                    viewModel.isContact = true
                                    NotificationService.shared.showSuccess("Запрос отправлен")
                                } catch {
                                    NotificationService.shared.showError(error.localizedDescription)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Группа (и канал – общий UI)
    private var groupChatContent: some View {
        VStack {
            // Аватар и название
            if let avatarUrl = chat.avatarUrl, !avatarUrl.isEmpty {
                AvatarView(urlString: avatarUrl, size: 100)
                    .padding(.top, 20)
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    )
                    .padding(.top, 20)
            }
            
            Text(chat.name ?? "Группа")
                .font(.title2)
                .fontWeight(.bold)
            
            if let description = chat.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Кнопки управления
            HStack {
                if viewModel.currentUserRole == "owner" || viewModel.currentUserRole == "admin" {
                    Button("Редактировать") {
                        let editView = EditChatView(chat: chat)
                        present(editView)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Пригласить") {
                        Task {
                            if let link = await viewModel.generateInviteLink() {
                                shareLink(link)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
            .padding(.horizontal)
            
            // Список участников с секциями
            List {
                if !viewModel.activeMembers.isEmpty {
                    Section(header: Text("Участники (\(viewModel.activeMembers.count))")) {
                        ForEach(viewModel.activeMembers) { member in
                            MemberRow(
                                member: member,
                                currentUserRole: viewModel.currentUserRole,
                                onRoleChange: { userId, newRole in
                                    Task { await viewModel.updateMemberRole(userId: userId, role: newRole) }
                                },
                                onKick: { userId in
                                    Task { await viewModel.kickMember(userId: userId) }
                                },
                                onBan: { userId, until in
                                    Task { await viewModel.banMember(userId: userId, until: until) }
                                },
                                onUnban: { userId in
                                    Task { await viewModel.unbanMember(userId: userId) }
                                }
                            )
                        }
                    }
                }
                
                if !viewModel.bannedMembers.isEmpty {
                    Section(header: Text("Забаненные (\(viewModel.bannedMembers.count))")) {
                        ForEach(viewModel.bannedMembers) { member in
                            MemberRow(
                                member: member,
                                currentUserRole: viewModel.currentUserRole,
                                onRoleChange: { userId, newRole in
                                    Task { await viewModel.updateMemberRole(userId: userId, role: newRole) }
                                },
                                onKick: { userId in
                                    Task { await viewModel.kickMember(userId: userId) }
                                },
                                onBan: { userId, until in
                                    Task { await viewModel.banMember(userId: userId, until: until) }
                                },
                                onUnban: { userId in
                                    Task { await viewModel.unbanMember(userId: userId) }
                                }
                            )
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            // Кнопки выхода/удаления
            VStack(spacing: 12) {
                if viewModel.currentUserRole == "owner" {
                    Button("Удалить чат", role: .destructive) {
                        confirmDelete()
                    }
                } else {
                    Button("Выйти из группы", role: .destructive) {
                        confirmLeave()
                    }
                }
            }
            .padding()
        }
    }
    
    private var channelContent: some View {
        groupChatContent
    }
    
    // MARK: - Вспомогательные функции
    private func present(_ view: some View) {
        let vc = UIHostingController(rootView: view)
        UIApplication.shared.windows.first?.rootViewController?.present(vc, animated: true)
    }
    
    private func shareLink(_ link: String) {
        let fullLink = "https://yourapp.com/join/\(link)"
        let av = UIActivityViewController(activityItems: [fullLink], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
    }
    
    private func confirmDelete() {
        let alert = UIAlertController(title: "Удалить чат", message: "Чат будет удалён для всех участников. Отменить нельзя.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { _ in
            Task {
                await MainActor.run { self.dismiss() }
                if await self.viewModel.deleteChat() {
                    NotificationCenter.default.post(name: .chatDeleted, object: self.chat.id)
                }
            }
        })
        UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
    }
    
    private func confirmLeave() {
        let alert = UIAlertController(title: "Выйти из чата", message: "Вы покинете чат и не сможете писать в него.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Выйти", style: .destructive) { _ in
            Task {
                if await self.viewModel.leaveChat() {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .chatDeleted, object: self.chat.id)
                        self.dismiss()
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

// MARK: - MemberRow (компонент строки участника)
struct MemberRow: View {
    let member: ChatMemberItem
    let currentUserRole: String   // "owner", "admin", "member"
    let onRoleChange: (UUID, String) -> Void
    let onKick: (UUID) -> Void
    let onBan: (UUID, Date?) -> Void
    let onUnban: (UUID) -> Void

    var body: some View {
        HStack {
            AvatarView(urlString: member.avatarUrl, size: 40)
            VStack(alignment: .leading) {
                Text(member.nickName)
                    .font(.headline)
                Text({
                    switch member.role ?? "member" {
                    case "owner": return "Владелец"
                    case "admin": return "Администратор"
                    default: return "Участник"
                    }
                }())
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()

            if member.status == "banned" {
                Text("Забанен")
                    .font(.caption)
                    .foregroundColor(.red)
                // Разбанить могут только owner/admin
                if currentUserRole == "owner" || currentUserRole == "admin" {
                    Button("Разбанить") {
                        onUnban(member.userId)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                // Активный участник
                if currentUserRole == "owner" || (currentUserRole == "admin" && member.role != "owner") {
                    Menu {
                        if currentUserRole == "owner" && member.role != "owner" {
                            let newRole = (member.role == "admin") ? "member" : "admin"
                            Button(newRole == "admin" ? "Назначить админом" : "Снять админа") {
                                onRoleChange(member.userId, newRole)
                            }
                        }
                        if currentUserRole == "owner" || currentUserRole == "admin" {
                            if member.role != "owner" {
                                Button("Исключить", role: .destructive) { onKick(member.userId) }
                                Button("Забанить", role: .destructive) { onBan(member.userId, nil) }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Расширение уведомлений
extension Notification.Name {
    static let chatDeleted = Notification.Name("chatDeleted")
}
extension ChatMemberItem {
    var roleDisplay: String {
        switch role {
        case "owner": return "Владелец"
        case "admin": return "Администратор"
        default: return "Участник"
        }
    }
}
