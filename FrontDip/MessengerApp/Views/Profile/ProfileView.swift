import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Загружаем профиль…")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .messengerBackground()
                } else if let user = viewModel.user {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            VStack(spacing: 14) {
                                AvatarView(urlString: user.avatarUrl, size: 124)
                                    .padding(.top, 20)

                                VStack(spacing: 6) {
                                    Text(user.nickName)
                                        .font(.system(size: 28, weight: .semibold))

                                    if let firstName = user.firstName, let lastName = user.lastName {
                                        Text("\(firstName) \(lastName)")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            profileInfoCard(user: user)

                            if let bio = user.bio, !bio.isEmpty {
                                infoBlock(
                                    title: "О себе",
                                    value: bio,
                                    icon: "text.alignleft"
                                )
                            }

                            accountMetaCard(user: user)

                            Button {
                                showingEditSheet = true
                            } label: {
                                Text("Редактировать профиль")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(MessengerTheme.selfBubbleGradient)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 26)
                        }
                    }
                    .messengerBackground()
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)

                        Text("Профиль недоступен")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .messengerBackground()
                }
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
        }
        .sheet(isPresented: $showingEditSheet) {
            if let user = viewModel.user {
                EditProfileView(user: user) { updatedUser, avatarData in
                    Task {
                        await viewModel.updateUser(updatedUser: updatedUser, avatarData: avatarData)
                        await MainActor.run {
                            showingEditSheet = false
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadMyProfile()
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func profileInfoCard(user: User) -> some View {
        VStack(spacing: 0) {
            if let email = user.email {
                profileRow(icon: "envelope.fill", title: "Email", value: email)
            }

            if let phone = user.phone {
                dividerLine
                profileRow(icon: "phone.fill", title: "Телефон", value: phone)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(MessengerTheme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MessengerTheme.divider, lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
    }

    private func accountMetaCard(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Аккаунт")
                .font(.system(size: 16, weight: .semibold))

            if let createdAt = user.createdAt {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .foregroundStyle(MessengerTheme.accent)

                    Text("Создан: \(formatDate(createdAt))")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }


        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(MessengerTheme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MessengerTheme.divider, lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
    }

    private func infoBlock(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(MessengerTheme.accent)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }

            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(MessengerTheme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MessengerTheme.divider, lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
    }

    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(MessengerTheme.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(MessengerTheme.divider)
            .frame(height: 0.8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}
