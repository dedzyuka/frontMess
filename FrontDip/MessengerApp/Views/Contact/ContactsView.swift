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
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("Нет контактов")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Добавляйте контакты через поиск")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(contactService.contacts) { contact in
                        ContactRow(contact: contact)
                    }
                    .listStyle(PlainListStyle())
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
            .onAppear {
                contactService.loadContacts()
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
                    Text(contact.nickname.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading) {
                Text(contact.nickname)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Добавлен: \(formatDate(contact.addedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                title: Text(contact.nickname),
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
