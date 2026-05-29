// MessengerApp.swift
import SwiftUI

@main
struct MessengerApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var contactService = ContactService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(contactService)
                .preferredColorScheme(.light)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isChecking = true

    var body: some View {
        Group {
            if isChecking {
                LoadingView()
            } else if appState.isAuthenticated {
                ChatListView()
            } else {
                WelcomeView()
            }
        }
        .onAppear {
            checkAutoLogin()
        }
    }

    private func checkAutoLogin() {
        Task {
            let success = await AuthViewModel().restoreSession()
            await MainActor.run {
                isChecking = false
                // если success == false, остаёмся на WelcomeView
            }
        }
    }
}
