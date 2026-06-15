import SwiftUI

struct ContactsView: View {
    @EnvironmentObject var contactService: ContactService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if contactService.isLoading && contactService.contacts.isEmpty {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Загружаем контакты…")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if contactService.contacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("Контактов пока нет")
                            .font(.system(size: 18, weight: .semibold))

                        Text("Добавляй людей через поиск и открывай личные диалоги быстрее.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 26)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(contactService.contacts) { contact in
                                ContactRow(contact: contact)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 18)
                    }
                    .refreshable {
                        await MainActor.run {
                            contactService.loadContacts()
                        }
                    }
                }
            }
            .messengerBackground()
            .navigationTitle("Контакты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                contactService.loadContacts()
            }
            .onReceive(NotificationCenter.default.publisher(for: .statusUpdated)) { _ in
                contactService.loadContacts()
            }
        }
    }
}

struct ContactRow: View {
    let contact: Contact

    @State private var showingChatSelection = false
    @State private var showingRemoveAlert = false

    var body: some View {
        NavigationLink(destination: UserProfileView(userId: contact.contactUserId)) {
            HStack(spacing: 12) {
                AvatarView(urlString: contact.contactUser?.avatarUrl, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.contactUser?.nickName ?? "Unknown")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(contact.contactUser?.isOnline == true ? Color.green : Color.gray.opacity(0.7))
                            .frame(width: 7, height: 7)

                        Text(contact.contactUser?.isOnline == true ? "в сети" : "не в сети")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Menu {
                    Button("Добавить в чат") {
                        showingChatSelection = true
                    }

                    Button("Удалить из контактов", role: .destructive) {
                        showingRemoveAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MessengerTheme.accent)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(MessengerTheme.elevatedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MessengerTheme.divider, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingChatSelection) {
            ChatSelectionView(contact: contact)
        }
        .alert("Удалить контакт?", isPresented: $showingRemoveAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                ContactService.shared.removeContact(userId: contact.contactUserId)
            }
        } message: {
            Text(contact.contactUser?.nickName ?? "Контакт")
        }
    }
}

struct ChatSelectionView: View {
    let contact: Contact

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChatSelectionViewModel

    @State private var isLoadingAction = false
    @State private var contactsInChat: [UUID: Bool] = [:]

    init(contact: Contact) {
        self.contact = contact
        _viewModel = StateObject(wrappedValue: ChatSelectionViewModel(contact: contact))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Загружаем чаты…")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.chats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("Нет доступных чатов")
                            .font(.system(size: 18, weight: .semibold))

                        Text("Сначала создай чат, а затем добавь туда контакт.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 26)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.chats) { chat in
                                ChatSelectionRow(
                                    chat: chat,
                                    isContactInChat: contactsInChat[chat.id] ?? false,
                                    isLoading: isLoadingAction,
                                    onAdd: {
                                        addContactToChat(chat)
                                    }
                                )
                                .onAppear {
                                    checkIfContactInChat(chat)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 18)
                    }
                }
            }
            .messengerBackground()
            .navigationTitle("Добавить в чат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadChats()
            }
        }
    }

    private func checkIfContactInChat(_ chat: Chat) {
        guard contactsInChat[chat.id] == nil else { return }

        Task {
            let isInChat = await viewModel.isContactInChat(chat)
            await MainActor.run {
                contactsInChat[chat.id] = isInChat
            }
        }
    }

    private func addContactToChat(_ chat: Chat) {
        guard !isLoadingAction else { return }

        isLoadingAction = true

        Task {
            let success = await viewModel.addContactToChat(chat)

            await MainActor.run {
                isLoadingAction = false

                if success {
                    NotificationService.shared.showSuccess("\(contact.contactUser?.nickName ?? "Контакт") добавлен")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        dismiss()
                    }
                } else {
                    NotificationService.shared.showError("Не удалось добавить контакт")
                }
            }
        }
    }
}

struct ChatSelectionRow: View {
    let chat: Chat
    let isContactInChat: Bool
    let isLoading: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let avatarUrl = chat.avatarUrl, !avatarUrl.isEmpty {
                AvatarView(urlString: avatarUrl, size: 46)
            } else {
                Circle()
                    .fill(MessengerTheme.secondarySurface)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: chat.isGroup ? "person.2.fill" : "bubble.left.and.bubble.right.fill")
                            .foregroundStyle(chat.isGroup ? Color.teal : MessengerTheme.accent)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(chat.name ?? "Без названия")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("\(chat.membersCount) участников")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if isContactInChat {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Уже есть")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
            } else {
                Button {
                    onAdd()
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(MessengerTheme.accent)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(MessengerTheme.accent)
                        }
                    }
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
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
}
