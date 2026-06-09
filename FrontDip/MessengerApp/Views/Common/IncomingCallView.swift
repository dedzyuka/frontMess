import SwiftUI
import AVFAudio

struct IncomingCallView: View {
    let call: Call
    let contactName: String
    let avatarURL: String?

    @State private var isProcessing = false
    @State private var showingActiveCall = false
    @State private var connectionError: String?
    @ObservedObject private var callService = CallService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                AvatarView(urlString: avatarURL, size: 108)

                Text(contactName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(call.type.lowercased() == "video" ? "Видеозвонок" : "Аудиозвонок")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                if let connectionError {
                    Text(connectionError)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                HStack(spacing: 44) {
                    Button {
                        guard !isProcessing else { return }
                        isProcessing = true

                        Task {
                            do {
                                try await callService.rejectCall(callId: call.callId)
                                WebSocketService.shared.sendCallReject(callId: call.callId)
                                dismiss()
                            } catch {
                                await MainActor.run {
                                    self.connectionError = error.localizedDescription
                                    self.isProcessing = false
                                }
                            }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "phone.down.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 68, height: 68)
                                .background(Color.red)
                                .clipShape(Circle())

                            Text("Отклонить")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isProcessing)

                    Button {
                        guard !isProcessing else { return }
                        isProcessing = true
                        connectionError = nil

                        Task {
                            do {
                                // Почему поменял:
                                // сперва acceptCall, чтобы сервер перевёл звонок в active,
                                // и только потом берём токен и подключаемся к room.
                                let acceptedCall = try await callService.acceptCall(callId: call.callId)
                                let tokenData = try await callService.getLiveKitToken(callId: acceptedCall.callId)
                                try await callService.connectToRoom(
                                    callId: acceptedCall.callId,
                                    token: tokenData.token,
                                    wsUrl: tokenData.wsUrl,
                                    publishTracks: true
                                )

                                WebSocketService.shared.sendCallAccept(callId: acceptedCall.callId)

                                await MainActor.run {
                                    showingActiveCall = true
                                    isProcessing = false
                                }
                            } catch {
                                await MainActor.run {
                                    self.connectionError = error.localizedDescription
                                    self.isProcessing = false
                                }
                            }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 68, height: 68)
                                .background(Color.green)
                                .clipShape(Circle())

                            Text(isProcessing ? "Подключение..." : "Принять")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isProcessing)
                }

                Spacer().frame(height: 40)
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showingActiveCall) {
            ActiveCallView(call: callService.activeCall ?? call)
        }
        .onAppear {
            configureAudioSession()
        }
        .onDisappear {
            // Почему поменял:
            // НИЧЕГО не disconnect/endCall здесь.
            // Этот экран исчезает и при нормальном переходе в ActiveCallView.
        }
        .onReceive(NotificationCenter.default.publisher(for: .callEnded)) { notification in
            if let endedCallId = notification.object as? UUID, endedCallId == call.callId {
                dismiss()
            }
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
}
