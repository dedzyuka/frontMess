import SwiftUI
import LiveKit
import AVFAudio

struct ActiveCallView: View {
    let call: Call
    @ObservedObject var callService = CallService.shared
    @Environment(\.dismiss) var dismiss
    @State private var isMicOn = true
    @State private var isCameraOn = true
    @State private var isSpeakerOn = false
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        let _ = Self._printChanges()
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Видео удалённого участника
            if let remoteParticipant = callService.room?.remoteParticipants.values.first {
                RemoteVideoView(participant: remoteParticipant)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Подключение...")
                        .foregroundColor(.white)
                        .padding(.top, 10)
                }
            }
            
            // Миниатюра локального видео
            if let localParticipant = callService.room?.localParticipant, isCameraOn {
                LocalVideoView(participant: localParticipant)
                    .frame(width: 100, height: 150)
                    .cornerRadius(12)
                    .padding()
                    .position(x: UIScreen.main.bounds.width - 70, y: 100)
            }
            
            // Верхняя панель
            VStack {
                HStack {
                    Button {
                        dismiss()
                        Task {
                            try? await callService.endCall(callId: call.callId)
                            WebSocketService.shared.sendCallEnd(callId: call.callId)
                            await callService.disconnect()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    Spacer()
                    Text(timeString(from: duration))
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                }
                .padding(.horizontal)
                .padding(.top, 60)
                Spacer()
            }
            
            // Нижняя панель управления
            VStack {
                Spacer()
                HStack(spacing: 40) {
                    // Микрофон
                    Button {
                        Task {
                            try? await callService.toggleMicrophone(enabled: !isMicOn)
                            isMicOn.toggle()
                        }
                    } label: {
                        VStack {
                            Image(systemName: isMicOn ? "mic.fill" : "mic.slash.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.gray.opacity(0.6))
                                .clipShape(Circle())
                            Text(isMicOn ? "Выкл" : "Вкл")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Динамик
                    Button {
                        isSpeakerOn.toggle()
                        let audioSession = AVAudioSession.sharedInstance()
                        try? audioSession.overrideOutputAudioPort(isSpeakerOn ? .speaker : .none)
                    } label: {
                        VStack {
                            Image(systemName: isSpeakerOn ? "speaker.wave.2.fill" : "speaker.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.gray.opacity(0.6))
                                .clipShape(Circle())
                            Text(isSpeakerOn ? "Громк" : "Динамик")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Камера (вкл/выкл)
                    Button {
                        Task {
                            try? await callService.toggleCamera(enabled: !isCameraOn)
                            isCameraOn.toggle()
                        }
                    } label: {
                        VStack {
                            Image(systemName: isCameraOn ? "video.fill" : "video.slash.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.gray.opacity(0.6))
                                .clipShape(Circle())
                            Text(isCameraOn ? "Выкл" : "Вкл")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Переключение камеры
                    Button {
                        Task {
                            try? await callService.switchCamera()
                        }
                    } label: {
                        VStack {
                            Image(systemName: "camera.rotate.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.gray.opacity(0.6))
                                .clipShape(Circle())
                            Text("Повернуть")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Завершить звонок
                    Button {
                        dismiss()
                        Task {
                            try? await callService.endCall(callId: call.callId)
                            WebSocketService.shared.sendCallEnd(callId: call.callId)
                            await callService.disconnect()
                        }
                    } label: {
                        VStack {
                            Image(systemName: "phone.down.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.red)
                                .clipShape(Circle())
                            Text("Завершить")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }.id(callService.room?.sid?.stringValue ?? "no-room")
        .onAppear {
            startTimer()
            do {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Audio session error: \(error)")
            }
        }
        .onDisappear {
            timer?.invalidate()
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if callService.activeCall?.isActive == true {
                duration += 1
            }
        }
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
