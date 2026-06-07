//
//  MessageBubbleView.swift
//  MessengerApp
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    let senderUser: User?
    @ObservedObject var viewModel: ChatViewModel
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onReply: (() -> Void)?
    let onReplyTap: ((Int64) -> Void)?
    let onForward: (() -> Void)?
    let isPrivateChat: Bool
    
    @State private var showMenu = false
    @State private var showReactionPicker = false
    
    private let emojis = ["👍", "❤️", "😂", "😮", "😢", "🙏"]
    
    private var currentUserReactionEmoji: String? {
        viewModel.reactionsForMessage(message.messageId)
            .first(where: { $0.userId == AppState.shared.currentUser?.userId })?.emoji
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCurrentUser {
                // Аватар показываем только в групповых чатах/каналах
                if !isPrivateChat {
                    NavigationLink(destination: UserProfileView(userId: message.senderId)) {
                        AvatarView(urlString: senderUser?.avatarUrl, size: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Имя отправителя тоже показываем только в не-приватных чатах
                    if !isPrivateChat, let nickname = senderUser?.nickName, !nickname.isEmpty {
                        Text(nickname)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                    }
                    
                    
                    messageContentView
                        .onLongPressGesture(minimumDuration: 0.5) {
                            showMenu = true
                        }
                    
                    if !viewModel.reactionsForMessage(message.messageId).isEmpty {
                        reactionRow
                    }
                    
                    HStack(spacing: 4) {
                        Text(formatTime(message.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if message.isEdited {
                            Text("(ред.)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            } else {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    messageContentView
                        .onLongPressGesture(minimumDuration: 0.5) {
                            showMenu = true
                        }
                    
                    if !viewModel.reactionsForMessage(message.messageId).isEmpty {
                        reactionRow
                    }
                    
                    HStack(spacing: 4) {
                        Text(formatTime(message.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if message.isEdited {
                            Text("(ред.)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if let readAt = message.readAt {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark")
                                Image(systemName: "checkmark")
                            }
                            .font(.caption2)
                            .foregroundColor(.blue)
                        } else if let deliveredAt = message.deliveredAt {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .onAppear {
            if !isCurrentUser {
                viewModel.markMessageAsReadIfNeeded(messageId: message.messageId)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width > 50 && value.startLocation.x < 50 {
                        onReply?()
                    }
                }
        )
        .confirmationDialog("Действия с сообщением", isPresented: $showMenu, titleVisibility: .visible) {
            if isCurrentUser {
                Button("Редактировать") { onEdit?() }
                Button("Удалить", role: .destructive) { onDelete?() }
            }
            Button("Ответить") { onReply?() }
            Button("Переслать") { onForward?() }
            Button("Добавить реакцию") { showReactionPicker = true }
            Button("Отмена", role: .cancel) { }
        }
        .sheet(isPresented: $showReactionPicker) {
            ReactionPickerView(emojis: emojis, currentReaction: currentUserReactionEmoji) { emoji in
                toggleReaction(emoji: emoji)
            }
        }
    }
    
    @ViewBuilder
    private var messageContentView: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
            // === Блок "От: ..." для пересланного сообщения (кликабельный) ===
            // В messageContentView
            if let forwardUserId = message.forwardedFromUserId, let forwardNick = message.forwardedFromNickname, !forwardNick.isEmpty {
                Button {
                    let profileView = UserProfileView(userId: forwardUserId)
                    let hosting = UIHostingController(rootView: profileView)
                    UIApplication.shared.windows.first?.rootViewController?.present(hosting, animated: true)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.right.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("От: \(forwardNick)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .underline()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }
            
            // Цитата родительского сообщения
            if let replyContent = message.replyToContent, !replyContent.isEmpty {
                Button {
                    if let replyId = message.replyToId {
                        onReplyTap?(replyId)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(replyContent)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isCurrentUser ? Color.blue.opacity(0.2) : Color(.systemGray5))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .fixedSize(horizontal: true, vertical: false)
                .padding(.bottom, 2)
            }
            
            // Вложения и текст
            if let attachments = message.attachments, !attachments.isEmpty {
                ForEach(attachments, id: \.attachmentId) { attachment in
                    if message.type == "voice" || attachment.mimeType?.hasPrefix("audio/") == true {
                        VoiceMessageBubble(attachment: attachment, isCurrentUser: isCurrentUser)
                    } else if attachment.mimeType?.hasPrefix("video/") == true {
                        // Если видео короткое (≤60 сек) – показываем как кружок, иначе как обычный файл
                        let isShortVideo = (attachment.duration ?? 0) <= 60
                        if isShortVideo {
                            CircularVideoView(attachment: attachment)
                        } else {
                            AttachmentView(attachment: attachment, isCurrentUser: isCurrentUser)
                        }
                    } else {
                        AttachmentView(attachment: attachment, isCurrentUser: isCurrentUser)
                    }
                }
            }
            
            if let content = message.content, !content.isEmpty {
                Text(content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(18)
            }
        }
    }
    
    private var reactionRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(Set(viewModel.reactionsForMessage(message.messageId).map { $0.emoji })), id: \.self) { emoji in
                let reactions = viewModel.reactionsDict[message.messageId] ?? [].filter { $0.emoji == emoji }
                let count = reactions.count
                let isCurrentUserReaction = reactions.contains(where: { $0.userId == AppState.shared.currentUser?.userId })
                HStack(spacing: 2) {
                    Text(emoji)
                        .font(.caption)
                    Text("\(count)")
                        .font(.caption2)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isCurrentUserReaction ? Color.blue.opacity(0.2) : Color(.systemGray5))
                .cornerRadius(12)
                .onTapGesture {
                    toggleReaction(emoji: emoji)
                }
            }
        }
        .padding(.top, 2)
    }
    
    private func toggleReaction(emoji: String) {
        Task {
            if let existingEmoji = currentUserReactionEmoji, existingEmoji == emoji {
                await viewModel.removeReaction(from: message.messageId, emoji: emoji)
            } else {
                if let existingEmoji = currentUserReactionEmoji {
                    await viewModel.removeReaction(from: message.messageId, emoji: existingEmoji)
                }
                await viewModel.addReaction(to: message.messageId, emoji: emoji)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct ReactionPickerView: View {
    let emojis: [String]
    let currentReaction: String?
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(action: {
                            onSelect(emoji)
                            dismiss()
                        }) {
                            Text(emoji)
                                .font(.system(size: 40))
                                .padding()
                                .background(currentReaction == emoji ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(30)
                                .overlay(
                                    Circle()
                                        .stroke(currentReaction == emoji ? Color.blue : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Выберите реакцию")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(120)])
    }
}
