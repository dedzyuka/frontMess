// ./FrontDip/MessengerApp/Views/Common/SideMenuView.swift
import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var contactService: ContactService
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var isShowing: Bool
    
    // Новые binding переменные для управления показами View
    @Binding var showSearchView: Bool
    @Binding var showContactsView: Bool
    @Binding var showNotificationsView: Bool
    
    @State private var showWipeAlert = false
    @State private var showLogoutAlert = false
    
    // Для анимации
    @State private var offset: CGFloat = UIScreen.main.bounds.width
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Полупрозрачный фон
            if isShowing {
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isShowing = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Само меню
            HStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Заголовок с аватаркой
                    VStack(alignment: .leading, spacing: 12) {
                        Circle()
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(authViewModel.currentUser?.nickname.prefix(1).uppercased() ?? "?")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authViewModel.currentUser?.nickname ?? "Пользователь")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            if let userId = authViewModel.currentUser?.id {
                                Text("ID: \(userId.uuidString.prefix(8))...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 32)
                    
                    // Пункты меню
                    ScrollView {
                        VStack(spacing: 0) {
                            MenuItem(
                                icon: "magnifyingglass",
                                title: "Поиск",
                                color: .blue
                            ) {
                                showSearchView = true
                                withAnimation(.spring()) {
                                    isShowing = false
                                }
                            }
                            
                            MenuItem(
                                icon: "person.2.fill",
                                title: "Контакты",
                                color: .green,
                                badgeCount: contactService.contacts.count
                            ) {
                                // Показываем ContactsView
                                showContactsView = true
                                isShowing = false
                            }

                            MenuItem(
                                icon: "bell.fill",
                                title: "Уведомления",
                                color: .orange,
                                badgeCount: contactService.pendingRequests.count
                            ) {
                                // Показываем NotificationsView
                                showNotificationsView = true
                                isShowing = false
                            }
                            
                            Divider()
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                            
                            MenuItem(
                                icon: "gear",
                                title: "Настройки",
                                color: .gray
                            ) {
                                // TODO: Реализовать настройки
                                print("Настройки")
                                withAnimation(.spring()) {
                                    isShowing = false
                                }
                            }
                            
                            Divider()
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                            
                            MenuItem(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Выйти",
                                color: .orange,
                                isDestructive: false
                            ) {
                                showLogoutAlert = true
                            }
                            
                            MenuItem(
                                icon: "trash",
                                title: "Очистить все",
                                color: .red,
                                isDestructive: true
                            ) {
                                showWipeAlert = true
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Версия приложения
                    Text("Версия 1.0.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 20)
                }
                .frame(width: UIScreen.main.bounds.width * 0.9)
                .background(Color(.systemBackground))
                .offset(x: offset)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: -3, y: 0)
            }
            .ignoresSafeArea()
        }
        .onChange(of: isShowing) { newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                offset = newValue ? 0 : UIScreen.main.bounds.width
                opacity = newValue ? 1 : 0
            }
        }
        .onAppear {
            offset = UIScreen.main.bounds.width
            opacity = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)) {
                offset = isShowing ? 0 : UIScreen.main.bounds.width
                opacity = isShowing ? 1 : 0
            }
        }
        .alert("Выйти из аккаунта", isPresented: $showLogoutAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Выйти", role: .destructive) {
                authViewModel.logout()
                withAnimation(.spring()) {
                    isShowing = false
                }
            }
        } message: {
            Text("Вы уверены, что хотите выйти из аккаунта? Ваши чаты останутся сохраненными.")
        }
        .alert("Очистить все данные", isPresented: $showWipeAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Очистить", role: .destructive) {
                authViewModel.completeWipe()
                withAnimation(.spring()) {
                    isShowing = false
                }
            }
        } message: {
            Text("Все данные будут удалены: аккаунт, чаты, сообщения. Это действие нельзя отменить.")
        }
    }
}

// Компонент пункта меню
struct MenuItem: View {
    let icon: String
    let title: String
    let color: Color
    let isDestructive: Bool
    let badgeCount: Int?
    let action: () -> Void
    
    init(icon: String, title: String, color: Color, isDestructive: Bool = false,
         badgeCount: Int? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.color = color
        self.isDestructive = isDestructive
        self.badgeCount = badgeCount
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 24, height: 24)
                    .foregroundColor(isDestructive ? .red : color)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Spacer()
                
                // Отображаем бейдж если есть
                if let count = badgeCount, count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
}
