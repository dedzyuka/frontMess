import SwiftUI

struct ChatSelectionForForwardView: View {
    let onSelect: (Chat) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ChatListViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                List(viewModel.chats) { chat in
                    Button {
                        onSelect(chat)
                        dismiss()
                    } label: {
                        ForwardChatRow(
                            chat: chat,
                            currentUserId: AppState.shared.currentUser?.userId
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.visible)
                }
                .listStyle(.plain)

                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("Переслать в чат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadChats()
                }
            }
        }
    }
}

private struct ForwardChatRow: View {
    let chat: Chat
    let currentUserId: UUID?

    private var isPrivateChat: Bool {
        chat.isPrivate
    }

    var body: some View {
        HStack(spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let preview = chat.lastMessagePreview {
                Text(formatDate(preview.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var avatarView: some View {
        if isPrivateChat {
            AvatarView(urlString: chat.otherUserAvatarUrl, size: 48)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(chat.otherUserIsOnline ? Color.green : Color.gray)
                        .frame(width: 11, height: 11)
                }
        } else if let avatarUrl = chat.avatarUrl, !avatarUrl.isEmpty {
            AvatarView(urlString: avatarUrl, size: 48)
        } else {
            Circle()
                .fill(chat.isGroup ? Color.blue.opacity(0.18) : Color.purple.opacity(0.18))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: chat.isGroup ? "person.2.fill" : "megaphone.fill")
                        .foregroundColor(chat.isGroup ? .blue : .purple)
                )
        }
    }

    private var titleText: String {
        if isPrivateChat {
            return chat.otherUserNickname ?? "Личный чат"
        } else {
            return chat.name ?? "Без названия"
        }
    }

    private var subtitleText: String {
        if chat.isTyping {
            return "печатает..."
        }

        guard let preview = chat.lastMessagePreview else {
            return isPrivateChat ? "Нет сообщений" : (chat.isGroup ? "Группа" : "Канал")
        }

        if !isPrivateChat, preview.senderId != currentUserId {
            let sender = preview.senderNickname ?? "Пользователь"
            let text = preview.textPreview ?? "Сообщение"
            return "\(sender): \(text)"
        }

        return preview.textPreview ?? "Сообщение"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
