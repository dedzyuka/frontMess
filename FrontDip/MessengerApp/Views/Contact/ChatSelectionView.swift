// ./FrontDip/MessengerApp/Views/Contact/ChatSelectionView.swift
import SwiftUI

struct ChatSelectionView: View {
    let contact: Contact
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ChatSelectionViewModel
    @State private var isLoadingAction = false
    
    init(contact: Contact) {
        self.contact = contact
        _viewModel = StateObject(wrappedValue: ChatSelectionViewModel(contact: contact))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.chats.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("Нет чатов")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Создайте чат, чтобы добавить в него контакты")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(viewModel.chats) { chatInfo in
                        ChatSelectionRow(
                            chatInfo: chatInfo,
                            isLoading: isLoadingAction,
                            onAdd: {
                                addContactToChat(chatInfo.chat)
                            }
                        )
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Добавить в чат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadChats()
            }
        }
    }
    
    private func addContactToChat(_ chat: Chat) {
        isLoadingAction = true
        
        Task {
            let success = await viewModel.addContactToChat(chat)
            
            await MainActor.run {
                isLoadingAction = false
                
                if success {
                    // Используем NotificationService
                    NotificationService.shared.showSuccess("\(contact.nickname) добавлен в чат \(chat.name)")
                    
                    // Закрываем через 1 секунду
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        dismiss()
                    }
                } else {
                    // Используем NotificationService
                    NotificationService.shared.showError("Не удалось добавить \(contact.nickname) в чат")
                }
            }
        }
    }
}

struct ChatSelectionRow: View {
    let chatInfo: ChatWithContactInfo
    let isLoading: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chatInfo.chat.name)
                    .font(.headline)
                
                Text("\(chatInfo.chat.memberCount) участников")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if chatInfo.isContactInChat {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Уже в чате")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                Button(action: onAdd) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading)
            }
        }
        .padding(.vertical, 8)
        .opacity(chatInfo.isContactInChat ? 0.6 : 1.0)
    }
}
