import SwiftUI

struct UserProfileView: View {
    let userId: UUID

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: UserProfileViewModel

    init(userId: UUID) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(userId: userId))
    }

    private var isCurrentUserProfile: Bool {
        AppState.shared.currentUser?.userId == userId
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadUser()
            }
            .alert("Ошибка", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.errorMessage = nil
                    }
                }
            )) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let user = viewModel.user {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header(user: user)
                    infoCard(user: user)

                    if isCurrentUserProfile {
                        selfProfileCard
                    } else {
                        actionsCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        } else if viewModel.isLoading {
            ProgressView()
        } else {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text("Не удалось загрузить профиль")
                    .font(.headline)

                Button("Закрыть") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private func header(user: User) -> some View {
        VStack(spacing: 14) {
            AvatarView(urlString: user.avatarUrl, size: 108)
                .overlay {
                    Circle()
                        .stroke(
                            Color(red: 217 / 255, green: 122 / 255, blue: 92 / 255).opacity(0.45),
                            lineWidth: 1.2
                        )
                }
                .padding(.top, 10)

            VStack(spacing: 6) {
                Text(user.nickName)
                    .font(.system(size: 24, weight: .semibold))
                    .multilineTextAlignment(.center)

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(user.isOnline == true ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    if user.isOnline == true {
                        Text("в сети")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let lastSeen = user.lastSeen {
                        Text("был(а) \(formatRelativeDate(lastSeen))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("не в сети")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func infoCard(user: User) -> some View {
        VStack(spacing: 12) {
            infoRow(icon: "at", title: "Никнейм", value: user.nickName)

            if let firstName = user.firstName, !firstName.isEmpty {
                infoRow(icon: "person", title: "Имя", value: firstName)
            }

            if let lastName = user.lastName, !lastName.isEmpty {
                infoRow(icon: "person.text.rectangle", title: "Фамилия", value: lastName)
            }

            if let email = user.email, !email.isEmpty {
                infoRow(icon: "envelope", title: "Email", value: email)
            }

            if let phone = user.phone, !phone.isEmpty {
                infoRow(icon: "phone", title: "Телефон", value: phone)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var selfProfileCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
                    .frame(width: 34, height: 34)

                Image(systemName: "person.crop.circle")
                    .foregroundStyle(Color(red: 217 / 255, green: 122 / 255, blue: 92 / 255))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Ваш профиль")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)

                Text("Здесь недоступны действия для чата и контактов с самим собой")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var actionsCard: some View {
        VStack(spacing: 12) {
            Button {
                guard !isCurrentUserProfile else { return }

                Task {
                    if let chat = await viewModel.startPrivateChatAndGetChat() {
                        await MainActor.run {
                            NotificationCenter.default.post(name: .openChat, object: chat)
                            dismiss()
                        }
                    }
                }
            } label: {
                Label("Написать сообщение", systemImage: "bubble.left.and.bubble.right.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 217 / 255, green: 122 / 255, blue: 92 / 255))

            switch viewModel.contactStatus {
            case "accepted":
                Button(role: .destructive) {
                    guard !isCurrentUserProfile else { return }
                    viewModel.removeFromContacts()
                } label: {
                    Label("Удалить из контактов", systemImage: "person.crop.circle.badge.minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            case "pending":
                Text("Заявка уже отправлена")
                    .font(.subheadline)
                    .foregroundStyle(.orange)

                Button(role: .destructive) {
                    guard !isCurrentUserProfile else { return }
                    viewModel.cancelOutgoingRequest()
                } label: {
                    Label("Отменить заявку", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            case "incomingpending":
                Text("Входящий запрос в контакты")
                    .font(.subheadline)
                    .foregroundStyle(.blue)

                HStack(spacing: 12) {
                    Button {
                        guard !isCurrentUserProfile else { return }
                        viewModel.acceptIncomingRequest()
                    } label: {
                        Label("Принять", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        guard !isCurrentUserProfile else { return }
                        viewModel.declineIncomingRequest()
                    } label: {
                        Label("Отклонить", systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

            default:
                Button {
                    guard !isCurrentUserProfile else { return }
                    viewModel.addToContacts()
                } label: {
                    Label("Добавить в контакты", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 217 / 255, green: 122 / 255, blue: 92 / 255))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .foregroundStyle(Color(red: 217 / 255, green: 122 / 255, blue: 92 / 255))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
