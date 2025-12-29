// ./FrontDip/MessengerApp/App/MessengerApp.swift
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

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var contactService = ContactService.shared
    
    @State private var isCheckingAutoLogin = true
    
    var body: some View {
        Group {
            if isCheckingAutoLogin {
                LoadingView()
            } else if appState.isAuthenticated {
                ChatListView()
                    .environmentObject(authViewModel)
                    .environmentObject(contactService)
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
            checkAutoLogin()
        }
    }
    
    private func checkAutoLogin() {
        print("🚀 Запуск приложения...")
        
        if authViewModel.hasSavedUser() {
            print("👤 Найден сохраненный пользователь")
            authViewModel.autoLogin()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isCheckingAutoLogin = false
                if !appState.isAuthenticated {
                    print("⏱️ Автологин не удался")
                }
            }
        } else {
            print("👤 Сохраненный пользователь не найден")
            isCheckingAutoLogin = false
        }
    }
}
