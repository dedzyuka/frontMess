// ./FrontDip/MessengerApp/Views/Contact/ContactsView.swift
import SwiftUI

struct ContactsView: View {
    @EnvironmentObject var contactService: ContactService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if contactService.contacts.isEmpty {
                    Spacer()
                    Text("Нет контактов")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(contactService.contacts) { contact in
                        ContactRow(contact: contact)
                    }
                }
            }
            .navigationTitle("Контакты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ContactRow: View {
    let contact: Contact
    @State private var showingActionSheet = false
    @State private var showingChatSelection = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(contact.contactUser?.nickName.prefix(1).uppercased() ?? "?")
                        .font(.headline)
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading) {
                Text(contact.contactUser?.nickName ?? "Неизвестный")
                    .font(.headline)
                Text("Добавлен: \(formatDate(contact.createdAt))")
                    .font(.caption)
            }
            
            
            Spacer()
            
            Button(action: {
                showingActionSheet = true
            }) {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text(contact.contactUser?.avatarUrl ?? "Неизвестный"),
                buttons: [
                    .default(Text("Добавить в чат")) {
                        showingChatSelection = true
                    },
                    .destructive(Text("Удалить контакт")) {
                        ContactService.shared.removeContact(userId: contact.userId)
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingChatSelection) {
            ChatSelectionView(contact: contact)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}
