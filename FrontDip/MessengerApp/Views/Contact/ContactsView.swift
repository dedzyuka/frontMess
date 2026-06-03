import SwiftUI

struct ContactsView: View {
    @EnvironmentObject var contactService: ContactService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                if contactService.isLoading {
                    ProgressView()
                } else if contactService.contacts.isEmpty {
                    Spacer()
                    Text("Нет контактов")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(contactService.contacts) { contact in
                        ContactRow(contact: contact)
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await contactService.loadContacts()
                    }
                }
            }
            .navigationTitle("Контакты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .onAppear {
                contactService.loadContacts()
            }
            .onReceive(NotificationCenter.default.publisher(for: .statusUpdated)) { notification in
                guard let info = notification.object as? [String: Any],
                      let userId = info["userId"] as? UUID,
                      let isOnline = info["is_online"] as? Bool else { return }
                if let index = contactService.contacts.firstIndex(where: { $0.contactUserId == userId }) {
                    contactService.contacts[index].contactUser?.isOnline = isOnline
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
        NavigationLink(destination: UserProfileView(userId: contact.contactUserId)) {
            HStack {
                AvatarView(urlString: contact.contactUser?.avatarUrl, size: 40)
                
                VStack(alignment: .leading) {
                    Text(contact.contactUser?.nickName ?? "Неизвестный")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(contact.contactUser?.isOnline == true ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(contact.contactUser?.isOnline == true ? "онлайн" : "офлайн")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button {
                    showingActionSheet = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
            .swipeActions {
                Button(role: .destructive) {
                    ContactService.shared.removeContact(userId: contact.contactUserId)
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(
                    title: Text(contact.contactUser?.nickName ?? "Контакт"),
                    buttons: [
                        .default(Text("Добавить в чат")) { showingChatSelection = true },
                        .destructive(Text("Удалить контакт")) {
                            ContactService.shared.removeContact(userId: contact.contactUserId)
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showingChatSelection) {
                ChatSelectionView(contact: contact)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
