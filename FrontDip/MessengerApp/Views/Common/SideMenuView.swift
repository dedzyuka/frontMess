import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var viewModel: ChatListViewModel
    @StateObject private var authVM = AuthViewModel()
    @State private var showLogoutAlert = false

    var body: some View {
        ZStack {
            if isShowing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { isShowing = false }
                    }
                HStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 24) {
                        // Профиль
                        VStack(alignment: .leading, spacing: 12) {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text((authVM.currentUser?.nickName.prefix(1).uppercased() ?? "U"))
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                )
                            Text(authVM.currentUser?.nickName ?? "Пользователь")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("ID: \(authVM.currentUser?.id.uuidString.prefix(8) ?? "")...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 20)

                        // Пункты меню
                        MenuItem(icon: "person.2.fill", title: "Контакты") {
                            // показать ContactsView
                        }
                        MenuItem(icon: "magnifyingglass", title: "Поиск") {
                            // показать SearchView
                        }
                        MenuItem(icon: "bell.fill", title: "Уведомления") {
                            // показать NotificationsView
                        }
                        Divider()
                        MenuItem(icon: "rectangle.portrait.and.arrow.right", title: "Выйти", isDestructive: true) {
                            showLogoutAlert = true
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .frame(width: UIScreen.main.bounds.width * 0.8)
                    .background(Color(.systemBackground))
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.spring(), value: isShowing)
        .alert("Выход", isPresented: $showLogoutAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Выйти", role: .destructive) {
                authVM.logout()
                isShowing = false
            }
        } message: {
            Text("Вы уверены, что хотите выйти?")
        }
    }
}

struct MenuItem: View {
    let icon: String
    let title: String
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundColor(isDestructive ? .red : .blue)
                Text(title)
                    .foregroundColor(isDestructive ? .red : .primary)
                Spacer()
            }
            .padding(.vertical, 12)
        }
    }
}
