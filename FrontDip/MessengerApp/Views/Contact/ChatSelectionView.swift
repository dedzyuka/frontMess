import SwiftUI

struct ChatSelectionView: View {
    let contact: Contact
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ChatSelectionViewModel
    @State private var isLoadingAction = false
    @State private var contactsInChat: [UUID: Bool] = [:]  // кэш: чат -> есть ли контакт
    
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
                    List {
                        ForEach(viewModel.chats) { chat in
                            ChatSelectionRow(
                                chat: chat,
                                isContactInChat: contactsInChat[chat.id] ?? false,
                                isLoading: isLoadingAction,
                                onAdd: { addContactToChat(chat) }
                            )
                            .onAppear {
                                checkIfContactInChat(chat)
                            }
                        }
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
    
    private func checkIfContactInChat(_ chat: Chat) {
        // Проверяем, если уже закэшировано – не делаем повторный запрос
        guard contactsInChat[chat.id] == nil else { return }
        
        Task {
            let isInChat = await viewModel.isContactInChat(chat)
            await MainActor.run {
                contactsInChat[chat.id] = isInChat
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
                    NotificationService.shared.showSuccess("\(contact.contact_user?.nick_name ?? "Контакт") добавлен в чат \(chat.name ?? "Неизвестное")")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        dismiss()
                    }
                } else {
                    NotificationService.shared.showError("Не удалось добавить \(contact.contact_user?.nick_name ?? "Контакт") в чат")
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.name ?? "Неизвестное")
                    .font(.headline)
                
                Text("\(chat.members_count) участников")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isContactInChat {
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
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
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
        .opacity(isContactInChat ? 0.6 : 1.0)
    }
}
