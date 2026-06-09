import SwiftUI

struct IncomingCallOverlay: View {
    let call: Call
    let contactName: String
    let avatarURL: String?

    @ObservedObject private var callService = CallService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingActiveCall = false
    @State private var isProcessing = false
    @State private var connectionError: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                AvatarView(urlString: avatarURL, size: 100)

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

                HStack(spacing: 40) {
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
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(Color.red)
                                .clipShape(Circle())

                            Text("Отклонить")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }

                    Button {
                        guard !isProcessing else { return }
                        isProcessing = true
                        connectionError = nil

                        Task {
                            do {
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
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(Color.green)
                                .clipShape(Circle())

                            Text(isProcessing ? "Подключение..." : "Принять")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }

                Spacer().frame(height: 36)
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showingActiveCall) {
            ActiveCallView(call: callService.activeCall ?? call)
        }
        .onReceive(NotificationCenter.default.publisher(for: .callEnded)) { notification in
            if let endedCallId = notification.object as? UUID, endedCallId == call.callId {
                dismiss()
            }
        }
        .onDisappear {
            // Почему поменял:
            // Никакого endCall() здесь.
            // Overlay может закрыться просто потому, что открылся ActiveCallView.
        }
    }
}
