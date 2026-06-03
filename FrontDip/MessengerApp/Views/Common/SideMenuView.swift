//
//  SideMenuView.swift
//  FrontDip
//
//

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
                        // MARK: - User Profile Section
                        if let currentUser = AppState.shared.currentUser {
                            HStack(spacing: 16) {
                                AvatarView(urlString: currentUser.avatarUrl, size: 60)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(currentUser.nickName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text(currentUser.email ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.bottom, 20)
                        } else {
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(ProgressView())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Загрузка...")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("")
                                        .font(.caption)
                                }
                                Spacer()
                            }
                            .padding(.bottom, 20)
                        }
                        
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
                        MenuItem(icon: "person.circle", title: "Мой профиль") {
                            let profileView = ProfileView()
                            let hosting = UIHostingController(rootView: profileView)
                            UIApplication.shared.windows.first?.rootViewController?.present(hosting, animated: true)
                        }
                        MenuItem(icon: "lock.shield", title: "Приватность") {
                            let privacyView = PrivacySettingsView()
                            let hosting = UIHostingController(rootView: privacyView)
                            UIApplication.shared.windows.first?.rootViewController?.present(hosting, animated: true)
                        }
                        MenuItem(icon: "laptopcomputer.and.iphone", title: "Сессии") {
                            let sessionsView = SessionsView()
                            let hosting = UIHostingController(rootView: sessionsView)
                            UIApplication.shared.windows.first?.rootViewController?.present(hosting, animated: true)
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

// MARK: - AvatarView (вынесена для переиспользования)
// AvatarView.swift (обновить)
// ./FrontDip/MessengerApp/Views/Common/AvatarView.swift
import SwiftUI

struct AvatarView: View {
    let urlString: String?
    let size: CGFloat
    
    private var fullURL: URL? {
        guard let urlString, !urlString.isEmpty else { return nil }
        if urlString.hasPrefix("http") {
            return URL(string: urlString)
        }
        // Базовый URL для аватаров (настраивается в AppConfig)
        let base = AppConfig.baseURL
        return URL(string: base + "/media/" + urlString)
    }
    
    var body: some View {
        if let url = fullURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable()
                } else if phase.error != nil {
                    placeholderView
                } else {
                    ProgressView()
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person")
                    .foregroundColor(.gray)
            )
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
