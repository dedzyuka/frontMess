import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var contactService: ContactService

    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                searchBar

                Group {
                    if viewModel.isLoading {
                        VStack(spacing: 14) {
                            ProgressView()
                            Text("Ищем пользователей…")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.searchResults.isEmpty, !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text("Ничего не найдено")
                                .font(.system(size: 18, weight: .semibold))

                            Text("Попробуй изменить запрос или используй точный никнейм.")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.searchResults.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text("Начни поиск")
                                .font(.system(size: 18, weight: .semibold))

                            Text("Введи никнейм или часть имени пользователя.")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.searchResults) { user in
                                    SearchResultRow(user: user) {
                                        viewModel.sendContactRequest(to: user)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 18)
                        }
                    }
                }
            }
            .messengerBackground()
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Никнейм или имя", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    viewModel.search()
                }

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                viewModel.search()
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(MessengerTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(MessengerTheme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MessengerTheme.divider, lineWidth: 0.8)
        )
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }
}

struct SearchResultRow: View {
    let user: UserPublicResponse
    let onAdd: () -> Void

    @State private var showingAlert = false

    var body: some View {
        NavigationLink(destination: UserProfileView(userId: user.userId)) {
            HStack(spacing: 12) {
                AvatarView(urlString: user.avatarUrl, size: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.nickName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("ID \(user.userId.uuidString.prefix(8))…")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button {
                    showingAlert = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MessengerTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(MessengerTheme.secondarySurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .alert("Добавить в контакты?", isPresented: $showingAlert) {
                    Button("Отмена", role: .cancel) {}
                    Button("Отправить") {
                        onAdd()
                    }
                } message: {
                    Text(user.nickName)
                }
            }
            .padding(14)
            .background(MessengerTheme.elevatedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MessengerTheme.divider, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}
