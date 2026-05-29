//
//  MessageBubbleView.swift
//  FrontDip
//
//  Created by Bogdan Sakhno on 21.05.26.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    let senderUser: User?
    let viewModel: ChatViewModel
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
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
                // Аватар отправителя (только для чужих сообщений)
                NavigationLink(destination: UserProfileView(userId: message.senderId)) {
                    AvatarView(urlString: senderUser?.avatarUrl, size: 32)
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    if let nickname = senderUser?.nickName, !nickname.isEmpty {
                        Text(nickname)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                    }
                    
                    Text(message.content ?? "")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(18)
                        .onLongPressGesture(minimumDuration: 0.5) {
                            showMenu = true
                        }
                    
                    // Реакции
                    if !viewModel.reactionsForMessage(message.messageId).isEmpty {
                        reactionRow
                    }
                    
                    // Время и статус (только время для чужих)
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
                
                Spacer() // Прижимает блок к левому краю
            } else {
                // Свои сообщения – справа
                Spacer() // Прижимает блок к правому краю
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content ?? "")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .onLongPressGesture(minimumDuration: 0.5) {
                            showMenu = true
                        }
                    
                    // Реакции (если есть)
                    if !viewModel.reactionsForMessage(message.messageId).isEmpty {
                        reactionRow
                    }
                    
                    // Время и статусы доставки/прочтения
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
                            // Две галочки синие – прочитано
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark")
                                Image(systemName: "checkmark")
                            }
                            .font(.caption2)
                            .foregroundColor(.blue)
                        } else if let deliveredAt = message.deliveredAt {
                            // Одна галочка серая – доставлено
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        } else {
                            // Одна галочка – отправлено
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                // Аватар для своих не показываем (можно добавить иконку статуса при желании)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .onAppear {
            if !isCurrentUser {
                viewModel.markAsRead(messageId: message.messageId)
            }
        }
        .confirmationDialog("Действия с сообщением", isPresented: $showMenu, titleVisibility: .visible) {
            if isCurrentUser {
                Button("Редактировать") { onEdit?() }
                Button("Удалить", role: .destructive) { onDelete?() }
            }
            Button("Добавить реакцию") { showReactionPicker = true }
            Button("Отмена", role: .cancel) { }
        }
        .sheet(isPresented: $showReactionPicker) {
            ReactionPickerView(emojis: emojis, currentReaction: currentUserReactionEmoji) { emoji in
                toggleReaction(emoji: emoji)
            }
        }
    }
    
    // MARK: - Реакции (общий вид для своих и чужих)
    private var reactionRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(Set(viewModel.reactionsForMessage(message.messageId).map { $0.emoji })), id: \.self) { emoji in
                let count = viewModel.reactionsForMessage(message.messageId).filter { $0.emoji == emoji }.count
                let isCurrentUserReaction = currentUserReactionEmoji == emoji
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

// MARK: - Пикер реакций
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
