import SwiftUI
import UIKit

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    let senderUser: User?

    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var translationController: ChatMessageTranslationController

    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onReply: (() -> Void)?
    let onReplyTap: ((Int64) -> Void)?
    let onForward: (() -> Void)?
    let isPrivateChat: Bool

    @State private var showReactionPicker = false
    @State private var showCopiedToast = false

    private let emojis = ["👍", "❤️", "🔥", "😂", "😮", "😢"]

    private var messageAttachments: [Attachment] {
        message.attachments ?? []
    }

    private var currentUserReactionEmoji: String? {
        guard let currentUserId = AppState.shared.currentUser?.userId else { return nil }
        return viewModel
            .reactionsForMessage(message.messageId)
            .first(where: { $0.userId == currentUserId })?
            .emoji
    }

    private var displayedText: String {
        translationController.displayText(for: message)
    }

    private var originalText: String {
        message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hasDisplayedText: Bool {
        !displayedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasOriginalText: Bool {
        !originalText.isEmpty
    }

    private var canTranslate: Bool {
        hasOriginalText && !translationController.availableTargets(for: message).isEmpty
    }

    private var canCopyText: Bool {
        hasDisplayedText
    }

    private var bubbleFill: LinearGradient {
        if isCurrentUser {
            return LinearGradient(
                colors: [
                    Color(red: 44 / 255, green: 110 / 255, blue: 110 / 255),
                    Color(red: 30 / 255, green: 74 / 255, blue: 74 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(.systemGray6).opacity(0.92),
                    Color(.systemGray5).opacity(0.84)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCurrentUser {
                if !isPrivateChat {
                    NavigationLink(destination: UserProfileView(userId: message.senderId)) {
                        AvatarView(urlString: senderUser?.avatarUrl, size: 32)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if !isPrivateChat, let nickname = senderUser?.nickName, !nickname.isEmpty {
                        Text(nickname)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                    }

                    bubbleBlock(alignment: .leading)

                    if !viewModel.reactionsForMessage(message.messageId).isEmpty {
                        reactionRow
                    }

                    footerRow
                }

                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)

                VStack(alignment: .trailing, spacing: 4) {
                    bubbleBlock(alignment: .trailing)

                    if !viewModel.reactionsForMessage(message.messageId).isEmpty {
                        reactionRow
                    }

                    footerRow
                }
            }
        }
        .sheet(isPresented: $showReactionPicker) {
            ReactionPickerView(
                emojis: emojis,
                currentReaction: currentUserReactionEmoji
            ) { emoji in
                Task {
                    await toggleReaction(emoji: emoji)
                }
            }
            .presentationDetents([PresentationDetent.height(120)])
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                Text("Скопировано")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.82))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, -8)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showCopiedToast)
    }

    @ViewBuilder
    private func bubbleBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            messageContentView
                .contentShape(Rectangle())
                .contextMenu {
                    messageContextMenu
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width > 50, value.startLocation.x < 50 {
                                onReply?()
                            }
                        }
                )
                .onAppear {
                    if !isCurrentUser {
                        viewModel.markMessageAsReadIfNeeded(messageId: message.messageId)
                    }
                }
        }
    }

    @ViewBuilder
    private var messageContextMenu: some View {
        if canCopyText {
            Button(action: copyCurrentText) {
                Label("Копировать", systemImage: "doc.on.doc")
            }
        }

        if canTranslate {
            ForEach(translationController.availableTargets(for: message), id: \.self) { target in
                Button {
                    Task {
                        await translationController.translate(message: message, targetLanguage: target)
                    }
                } label: {
                    Label(target.menuTitle, systemImage: "translate")
                }
            }
        }

        if translationController.isTranslated(message.messageId) {
            Button {
                translationController.reset(message.messageId)
            } label: {
                Label("Показать оригинал", systemImage: "arrow.uturn.backward")
            }
        }

        if let onReply {
            Button(action: onReply) {
                Label("Ответить", systemImage: "arrowshape.turn.up.left")
            }
        }

        if let onForward {
            Button(action: onForward) {
                Label("Переслать", systemImage: "arrowshape.turn.up.right")
            }
        }

        Button {
            showReactionPicker = true
        } label: {
            Label("Реакция", systemImage: "face.smiling")
        }

        if isCurrentUser, let onEdit, hasOriginalText {
            Button(action: onEdit) {
                Label("Изменить", systemImage: "pencil")
            }
        }

        if isCurrentUser || viewModel.myRole == "owner" || viewModel.myRole == "admin" {
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var messageContentView: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
            if let forwardUserId = message.forwardedFromUserId,
               let forwardNick = message.forwardedFromNickname,
               !forwardNick.isEmpty {
                Button {
                    let profileView = UserProfileView(userId: forwardUserId)
                    let hosting = UIHostingController(rootView: profileView)
                    UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap { $0.windows }
                        .first?
                        .rootViewController?
                        .present(hosting, animated: true)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.right.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("Переслано от \(forwardNick)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }

            if let replyContent = message.replyToContent, !replyContent.isEmpty {
                Button {
                    if let replyId = message.replyToId {
                        onReplyTap?(replyId)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(replyContent)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isCurrentUser ? Color.white.opacity(0.18) : Color(.systemGray5))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
            }

            if hasDisplayedText {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayedText)
                        .font(.subheadline)
                        .foregroundColor(isCurrentUser ? .white : .primary)
                        .multilineTextAlignment(.leading)

                    if let caption = translationController.caption(for: message.messageId),
                       translationController.isTranslated(message.messageId) {
                        Text(caption)
                            .font(.caption2)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.82) : .secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleFill)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            if !messageAttachments.isEmpty {
                attachmentsContent
            }

            if translationController.isLoading(message.messageId) {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(isCurrentUser ? .white : .blue)

                    Text("Перевод…")
                        .font(.caption)
                        .foregroundStyle(isCurrentUser ? .white.opacity(0.92) : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleFill)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var attachmentsContent: some View {
        ForEach(messageAttachments.indices, id: \.self) { index in
            let attachment = messageAttachments[index]

            Group {
                if attachment.mimeType?.hasPrefix("video") == true {
                    if attachment.isCircular == true {
                        CircularVideoView(attachment: attachment)
                    } else {
                        AttachmentView(attachment: attachment, isCurrentUser: isCurrentUser)
                    }
                } else if attachment.mimeType?.hasPrefix("audio") == true {
                    VoiceMessageBubble(attachment: attachment, isCurrentUser: isCurrentUser)
                } else {
                    AttachmentView(attachment: attachment, isCurrentUser: isCurrentUser)
                }
            }
        }
    }

    private var reactionRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(Set(viewModel.reactionsForMessage(message.messageId).map(\.emoji))).sorted(), id: \.self) { emoji in
                let reactions = (viewModel.reactionsDict[message.messageId] ?? []).filter { $0.emoji == emoji }
                let count = reactions.count
                let isCurrentUserReaction = reactions.contains { $0.userId == AppState.shared.currentUser?.userId }

                HStack(spacing: 2) {
                    Text(emoji)
                        .font(.caption)

                    Text("\(count)")
                        .font(.caption2)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isCurrentUserReaction ? Color.blue.opacity(0.18) : Color(.systemGray5))
                .cornerRadius(12)
                .onTapGesture {
                    Task {
                        await toggleReaction(emoji: emoji)
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private var footerRow: some View {
        HStack(spacing: 4) {
            Text(formatTime(message.createdAt))
                .font(.caption2)
                .foregroundStyle(.secondary)

            if message.isEdited {
                Text("изменено")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isCurrentUser {
                if message.readAt != nil {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                        Image(systemName: "checkmark")
                    }
                    .font(.caption2)
                    .foregroundStyle(.blue)
                } else if message.deliveredAt != nil {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                        Image(systemName: "checkmark")
                    }
                    .font(.caption2)
                    .foregroundStyle(.gray)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func copyCurrentText() {
        UIPasteboard.general.string = displayedText
        showTemporaryCopiedToast()
    }

    private func showTemporaryCopiedToast() {
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            showCopiedToast = false
        }
    }

    private func toggleReaction(emoji: String) async {
        if let existingEmoji = currentUserReactionEmoji, existingEmoji == emoji {
            await viewModel.removeReaction(from: message.messageId, emoji: emoji)
        } else if let existingEmoji = currentUserReactionEmoji {
            await viewModel.removeReaction(from: message.messageId, emoji: existingEmoji)
            await viewModel.addReaction(to: message.messageId, emoji: emoji)
        } else {
            await viewModel.addReaction(to: message.messageId, emoji: emoji)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

import SwiftUI

struct ReactionPickerView: View {
    let emojis: [String]
    let currentReaction: String?
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            onSelect(emoji)
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 40))
                                .padding(10)
                                .background(
                                    currentReaction == emoji
                                    ? Color.blue.opacity(0.2)
                                    : Color(.systemGray6)
                                )
                                .cornerRadius(30)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            currentReaction == emoji ? Color.blue : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Реакция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}
