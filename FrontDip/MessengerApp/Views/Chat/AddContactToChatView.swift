import SwiftUI

struct AddContactToChatView: View {
    let chat: Chat
    @ObservedObject var viewModel: ChatSidebarViewModel

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var contactService: ContactService

    @State private var selectedContacts: Set<String> = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            Group {
                if contactService.contacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("Контакты не найдены")
                            .font(.system(size: 18, weight: .semibold))

                        Text("Сначала добавь пользователей в контакты, а затем пригласи их в чат.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 26)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(contactService.contacts) { contact in
                                ContactSelectionRow(
                                    contact: contact,
                                    isSelected: selectedContacts.contains(contact.id),
                                    isAlreadyInChat: viewModel.isUserInChat(contact.contactUserId),
                                    onToggle: {
                                        toggleContactSelection(contact.id)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 18)
                    }
                }
            }
            .messengerBackground()
            .navigationTitle("Добавить участников")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addSelectedContacts()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Добавить")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .disabled(selectedContacts.isEmpty || isLoading)
                }
            }
            .onAppear {
                contactService.loadContacts()
            }
        }
    }

    private func toggleContactSelection(_ contactId: String) {
        if selectedContacts.contains(contactId) {
            selectedContacts.remove(contactId)
        } else {
            selectedContacts.insert(contactId)
        }
    }

    private func addSelectedContacts() {
        guard !isLoading else { return }

        isLoading = true

        let selectedContactItems = contactService.contacts.filter { selectedContacts.contains($0.id) }

        Task {
            var addedCount = 0
            var failedCount = 0

            for contact in selectedContactItems {
                let success = await viewModel.addUserToChat(contact.contactUserId)
                if success {
                    addedCount += 1
                } else {
                    failedCount += 1
                }
            }

            await MainActor.run {
                isLoading = false
                dismiss()

                if addedCount > 0 {
                    NotificationService.shared.showSuccess("Добавлено: \(addedCount), ошибок: \(failedCount)")
                } else {
                    NotificationService.shared.showError("Не удалось добавить участников")
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
        HStack(spacing: 12) {
            AvatarView(urlString: contact.contactUser?.avatarUrl, size: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.contactUser?.nickName ?? "Unknown")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                if isAlreadyInChat {
                    Text("Уже в чате")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                } else {
                    Text(contact.contactUser?.isOnline == true ? "в сети" : "не в сети")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if isAlreadyInChat {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green)
            } else {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? MessengerTheme.accent : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(MessengerTheme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MessengerTheme.divider, lineWidth: 0.8)
        )
        .opacity(isAlreadyInChat ? 0.72 : 1.0)
    }
}
