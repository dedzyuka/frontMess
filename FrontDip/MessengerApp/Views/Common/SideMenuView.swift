import SwiftUI

struct SideMenuView: View {
    enum Destination: Identifiable {
        case profile
        case contacts
        case search
        case notifications
        case privacy
        case sessions

        var id: String {
            switch self {
            case .profile: return "profile"
            case .contacts: return "contacts"
            case .search: return "search"
            case .notifications: return "notifications"
            case .privacy: return "privacy"
            case .sessions: return "sessions"
            }
        }
    }

    @Binding var isShowing: Bool
    let onSelect: (Destination) -> Void

    @StateObject private var authVM = AuthViewModel()
    @State private var showLogoutAlert = false

    var body: some View {
        ZStack(alignment: .leading) {
            if isShowing {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        closeMenu()
                    }

                HStack(spacing: 0) {
                    sidePanel
                        .frame(width: min(UIScreen.main.bounds.width * 0.82, 320))
                        .transition(.move(edge: .leading))

                    Spacer(minLength: 0)
                }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: isShowing)
        .onAppear {
            AppState.shared.isSidebarOpen = isShowing
        }
        .onChange(of: isShowing) { newValue in
            AppState.shared.isSidebarOpen = newValue
        }
        .alert("Выйти из аккаунта?", isPresented: $showLogoutAlert) {
            Button("Отмена", role: .cancel) { }

            Button("Выйти", role: .destructive) {
                authVM.logout()
                closeMenu()
            }
        } message: {
            Text("Текущая сессия будет завершена на этом устройстве.")
        }
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileBlock
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 18)

            Rectangle()
                .fill(MessengerTheme.divider)
                .frame(height: 0.8)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                MenuItem(icon: "person.circle", title: "Мой профиль") {
                    select(.profile)
                }

                MenuItem(icon: "person.2.fill", title: "Контакты") {
                    select(.contacts)
                }

                MenuItem(icon: "magnifyingglass", title: "Поиск людей") {
                    select(.search)
                }

                MenuItem(icon: "bell.fill", title: "Уведомления") {
                    select(.notifications)
                }

                MenuItem(icon: "lock.shield", title: "Приватность") {
                    select(.privacy)
                }

                MenuItem(icon: "laptopcomputer.and.iphone", title: "Сессии") {
                    select(.sessions)
                }

                MenuItem(icon: "rectangle.portrait.and.arrow.right",
                         title: "Выйти",
                         isDestructive: true) {
                    showLogoutAlert = true
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 14)

            Spacer(minLength: 0)


        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(MessengerTheme.appBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(MessengerTheme.divider)
                .frame(width: 0.8)
        }
    }

    @ViewBuilder
    private var profileBlock: some View {
        if let currentUser = AppState.shared.currentUser {
            HStack(spacing: 14) {
                AvatarView(urlString: currentUser.avatarUrl, size: 62)

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentUser.nickName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let email = currentUser.email, !email.isEmpty {
                        Text(email)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Аккаунт активен")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: 14) {
                Circle()
                    .fill(MessengerTheme.secondarySurface)
                    .frame(width: 62, height: 62)
                    .overlay {
                        ProgressView()
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Загрузка профиля…")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Подготавливаем меню")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func closeMenu() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            isShowing = false
            AppState.shared.isSidebarOpen = false
        }
    }

    private func select(_ destination: Destination) {
        closeMenu()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onSelect(destination)
        }
    }
}

struct MenuItem: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isDestructive ? Color.red.opacity(0.10) : MessengerTheme.secondarySurface)
                        .frame(width: 34, height: 34)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDestructive ? .red : MessengerTheme.accent)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDestructive ? .red : .primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
