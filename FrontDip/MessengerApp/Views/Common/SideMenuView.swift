import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var viewModel: ChatListViewModel
    @StateObject private var authVM = AuthViewModel()
    @State private var showLogoutAlert = false
    @State private var showContacts = false
    @State private var showSearch = false
    @State private var showNotifications = false

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
                        // ... профиль ...
                        
                        MenuItem(icon: "person.2.fill", title: "Контакты") {
                            showContacts = true
                        }
                        MenuItem(icon: "magnifyingglass", title: "Поиск") {
                            showSearch = true
                        }
                        MenuItem(icon: "bell.fill", title: "Уведомления") {
                            showNotifications = true
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
        .sheet(isPresented: $showContacts) {
            ContactsView()
                .environmentObject(ContactService.shared)
        }
        .sheet(isPresented: $showSearch) {
            SearchView()
                .environmentObject(ContactService.shared)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
                .environmentObject(ContactService.shared)
        }
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
