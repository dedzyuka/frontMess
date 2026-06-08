import Foundation
import UIKit
import CallKit
import PushKit
import AVFoundation

class CallManager: NSObject, ObservableObject {
    static let shared = CallManager()
    private let callController = CXCallController()
    private var provider: CXProvider?
    private var currentCallUUID: UUID?
    private let callService = CallService.shared
    
    override private init() {
        super.init()
        setupProvider()
        registerForVoIPPushes()
    }
    
    private func setupProvider() {
        let config = CXProviderConfiguration(localizedName: "SocketUp")
        config.supportsVideo = true
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        config.iconTemplateImageData = UIImage(named: "AppIcon")?.pngData()
        config.ringtoneSound = "ringtone.caf"
        provider = CXProvider(configuration: config)
        provider?.setDelegate(self, queue: nil)
    }
    
    private func registerForVoIPPushes() {
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
    }
    
    func startOutgoingCall(chatId: UUID, contactName: String, avatarURL: String?, type: String = "video") {
            Task {
                // 1. Запрашиваем разрешения
                let granted = await withCheckedContinuation { cont in
                    AVCaptureDevice.requestAccess(for: .video) { videoGranted in
                        AVAudioSession.sharedInstance().requestRecordPermission { audioGranted in
                            cont.resume(returning: videoGranted && audioGranted)
                        }
                    }
                }
                guard granted else { return }
                
                // 2. Активируем аудиосессию
                try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
                try? AVAudioSession.sharedInstance().setActive(true)
                
                // 3. Создаём звонок на бэкенде
                let call = try await callService.startCall(chatId: chatId, type: type)
                
                // 4. Отправляем событие для отображения OutgoingCallView
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .showOutgoingCall,
                        object: (call, contactName, avatarURL as Any)
                    )
                }
            }
        }
}

extension CallManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        currentCallUUID = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let callId = currentCallUUID else { action.fail(); return }
        Task {
            do {
                let (token, wsUrl) = try await callService.getLiveKitToken(callId: callId)
                try await callService.connectToRoom(callId: callId, token: token, wsUrl: wsUrl)
                try await callService.acceptCall(callId: callId)
                action.fulfill()
            } catch {
                action.fail()
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard let callId = currentCallUUID else { action.fail(); return }
        Task {
            try? await callService.endCall(callId: callId)
            await callService.disconnect()
            action.fulfill()
        }
        currentCallUUID = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        Task {
            try? await callService.toggleMicrophone(enabled: !action.isMuted)
            action.fulfill()
        }
    }
}

extension CallManager: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
        Task { await PushService.shared.registerVoIPToken(token) }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        // Здесь должен быть парсинг call_id из payload и отображение IncomingCallView
        // Реализуйте по аналогии с вашим текущим кодом, используя IncomingCallView
        completion()
    }
}
extension Notification.Name {
    static let showOutgoingCall = Notification.Name("showOutgoingCall")

}
