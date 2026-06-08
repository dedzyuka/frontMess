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

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isChecking = true
    
    @State private var incomingCall: Call?
    @State private var incomingCallerName = ""
    @State private var incomingCallerAvatar: String?
    
    @State private var outgoingCallData: OutgoingCallData?   // ← исправлено
    
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
        .sheet(item: $outgoingCallData) { data in
            OutgoingCallView(call: data.call, contactName: data.contactName, avatarURL: data.avatarURL)
                .onDisappear {
                            outgoingCallData = nil
                        }
        }
        // Входящий вызов
        .onReceive(NotificationCenter.default.publisher(for: .incomingCall)) { notification in
            // Не показываем входящий вызов, если уже есть активный вызов (исходящий или входящий)
            guard incomingCall == nil && outgoingCallData == nil else {
                print("Already presenting a call screen, ignoring new incoming call")
                return
            }
            if let call = notification.object as? Call {
                incomingCall = call
                Task {
                    if let user = try? await UserService.shared.getUser(userId: call.initiatorId) {
                        await MainActor.run {
                            incomingCallerName = user.nickName
                            incomingCallerAvatar = user.avatarUrl
                        }
                    }
                }
            }
        }

        .onReceive(NotificationCenter.default.publisher(for: .showOutgoingCall)) { notification in
            guard incomingCall == nil && outgoingCallData == nil else {
                print("Already presenting a call screen, ignoring new outgoing call")
                return
            }
            if let (call, name, avatar) = notification.object as? (Call, String, String?) {
                outgoingCallData = OutgoingCallData(call: call, contactName: name, avatarURL: avatar)
            }
        }
        .sheet(item: $incomingCall) { call in
            IncomingCallView(call: call, contactName: incomingCallerName, avatarURL: incomingCallerAvatar).onDisappear {
                incomingCall = nil
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
}
