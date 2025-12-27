import SwiftUI

@main
struct MessengerApp: App {
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    appState.setup()
                }
        }
    }
}

// В ContentView.swift
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var webSocketService = WebSocketService.shared
    @StateObject private var contactService = ContactService.shared  // Добавляем
    @State private var isCheckingAutoLogin = true
    
    var body: some View {
        Group {
            if isCheckingAutoLogin {
                LoadingView()
            } else if appState.isAuthenticated {
                ChatListView()
                    .environmentObject(webSocketService)
                    .environmentObject(authViewModel)
                    .environmentObject(contactService)  // Добавляем
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
        .alert("Ошибка", isPresented: .constant(appState.errorMessage != nil)) {
            Button("OK") {
                appState.errorMessage = nil
            }
            
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .onAppear {
            // Проверяем автологин при запуске
            checkAutoLogin()
        }
        Button("Debug: Recreate DB") {
            LocalDatabase.shared.recreateTables()
        }
        .font(.caption)
        .foregroundColor(.red)
    }
    
    private func checkAutoLogin() {
        print("🚀 Запуск приложения...")
        
        // Проверяем, есть ли сохраненный пользователь
        if authViewModel.hasSavedUser() {
            print("👤 Найден сохраненный пользователь, пытаемся войти...")
            authViewModel.autoLogin()
            
            
            // Даем 2 секунды на попытку автологина
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isCheckingAutoLogin = false
                if !appState.isAuthenticated {
                    print("⏱️ Автологин не удался, показываем экран входа")
                }
            }
        } else {
            print("👤 Сохраненный пользователь не найден, показываем экран входа")
            isCheckingAutoLogin = false
        }
    }
}
