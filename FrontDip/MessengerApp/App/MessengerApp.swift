// MessengerApp.swift
import SwiftUI

import PushKit
import LiveKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Регистрация VoIP push
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = CallManager.shared
        registry.desiredPushTypes = [.voIP]
        
        return true
    }
    
}

@main
struct MessengerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var contactService = ContactService.shared
    @StateObject private var activeVideoManager = ActiveVideoManager.shared   // новая строка
    
    init() {
            // Включаем детальное логирование для отладки WebRTC
            LiveKitSDK.setLogLevel(.debug)
        }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(contactService)
                .environmentObject(activeVideoManager)
                .preferredColorScheme(.light)
        }
    }
}

struct OutgoingCallData: Identifiable {
    let id: UUID
    let call: Call
    let contactName: String
    let avatarURL: String?
    
    init(call: Call, contactName: String, avatarURL: String?) {
        self.id = call.callId
        self.call = call
        self.contactName = contactName
        self.avatarURL = avatarURL
    }
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var contactService = ContactService.shared
    @StateObject private var activeVideoManager = ActiveVideoManager.shared
    @StateObject private var callService = CallService.shared
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
        .sheet(item: $callService.activeCall) { call in
            if call.initiatorId == appState.currentUser?.userId {
                // Исходящий звонок – нужно получить имя и аватар
                OutgoingCallView(
                    call: call,
                    contactName: getContactName(for: call.chatId, initiatorId: call.initiatorId),
                    avatarURL: getAvatarURL(for: call.chatId, initiatorId: call.initiatorId)
                )
            } else {
                IncomingCallView(
                    call: call,
                    contactName: getContactName(for: call.chatId, initiatorId: call.initiatorId),
                    avatarURL: getAvatarURL(for: call.chatId, initiatorId: call.initiatorId)
                )
            }
        }
    }
    
    private func checkAutoLogin() {
        Task {
            let success = await AuthViewModel().restoreSession()
            await MainActor.run {
                isChecking = false
            }
        }
    }
    
    private func getContactName(for chatId: UUID, initiatorId: UUID) -> String {
        // Здесь нужно получить имя контакта из кэша или БД
        // Временная заглушка:
        return "Контакт"
    }
    
    private func getAvatarURL(for chatId: UUID, initiatorId: UUID) -> String? {
        return nil
    }
}
