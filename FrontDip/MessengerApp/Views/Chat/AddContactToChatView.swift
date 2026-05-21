import SwiftUI

struct AddContactToChatView: View {
    let chat: Chat
    @ObservedObject var viewModel: ChatSidebarViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var contactService: ContactService
    
    @State private var selectedContacts: Set<UUID> = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if contactService.contacts.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("Нет контактов")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Добавьте контакты через поиск")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(contactService.contacts) { contact in
                            ContactSelectionRow(
                                contact: contact,
                                isSelected: selectedContacts.contains(contact.id),
                                isAlreadyInChat: viewModel.isUserInChat(contact.contactUserId),
                                onToggle: { toggleContactSelection(contact.id) }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Добавить в чат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Добавить") { addSelectedContacts() }
                        .disabled(selectedContacts.isEmpty || isLoading)
                }
            }
            .onAppear {
                contactService.loadContacts()
            }
        }
    }
    
    private func toggleContactSelection(_ userId: UUID) {
        if selectedContacts.contains(userId) {
            selectedContacts.remove(userId)
        } else {
            selectedContacts.insert(userId)
        }
    }
    
    private func addSelectedContacts() {
        isLoading = true
        
        Task {
            var addedCount = 0
            var failedCount = 0
            
            for userId in selectedContacts {
                let success = await viewModel.addUserToChat(userId)
                if success { addedCount += 1 } else { failedCount += 1 }
            }
            
            await MainActor.run {
                isLoading = false
                dismiss()
                let message = "Добавлено: \(addedCount), не удалось: \(failedCount)"
                if addedCount > 0 {
                    NotificationService.shared.showSuccess(message)
                } else {
                    NotificationService.shared.showError(message)
                }
            }
        }
    }
}

struct ContactSelectionRow: View {
    let contact: Contact
    let isSelected: Bool
    let isAlreadyInChat: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text((contact.contactUser?.nickName ?? "?").prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading) {
                Text(contact.contactUser?.nickName ?? "Неизвестный")
                    .font(.headline)
                if isAlreadyInChat {
                    Text("Уже в чате")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            if isAlreadyInChat {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .opacity(isAlreadyInChat ? 0.6 : 1.0)
        .disabled(isAlreadyInChat)
    }
}
