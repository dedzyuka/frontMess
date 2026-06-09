import SwiftUI

struct OutgoingCallView: View {
    let call: Call
    let contactName: String
    let avatarURL: String?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var callService = CallService.shared

    @State private var showingActiveCall = false
    @State private var connectionError: String?
    @State private var isWaitingForAnswer = true
    @State private var isJoiningRoom = false
    @State private var timeoutWorkItem: DispatchWorkItem?

    // Почему добавил:
    // onDisappear у outgoing sheet вызывается и при нормальном переходе в active screen.
    // Поэтому нужен явный флаг, что это не пользовательская отмена.
    @State private var isTransitioningToActive = false
    @State private var didUserCancel = false

    // Почему добавил:
    // removeObserver(self, ...) не снимает closure-based observer.
    // Нужно хранить токен и удалять именно его.
    @State private var callStatusObserver: NSObjectProtocol?
    @State private var callEndedObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                AvatarView(urlString: avatarURL, size: 100)
                    .padding(.top, 40)

                Text(contactName)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if isJoiningRoom {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text("Подключение к звонку...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                } else if let error = connectionError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Повторить") {
                        Task { await joinActiveCallIfNeeded() }
                    }
                    .buttonStyle(.borderedProminent)
                } else if isWaitingForAnswer {
                    Text("Ожидание ответа...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("Соединение установлено")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Button {
                    didUserCancel = true
                    timeoutWorkItem?.cancel()

                    Task {
                        try? await callService.endCall(callId: call.callId)
                        WebSocketService.shared.sendCallEnd(callId: call.callId)
                        await callService.disconnect(clearActiveCall: true)
                        dismiss()
                    }
                } label: {
                    VStack {
                        Image(systemName: "phone.down.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                            .clipShape(Circle())

                        Text("Отменить")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .fullScreenCover(isPresented: $showingActiveCall) {
            ActiveCallView(call: callService.activeCall ?? call)
        }
        .onAppear {
            startObserving()
            startTimeout()
        }
        .onDisappear {
            stopObserving()
            timeoutWorkItem?.cancel()

            // Почему поменял:
            // раньше onDisappear завершал звонок почти всегда,
            // из-за чего переход в ActiveCallView сам же убивал звонок.
            guard !isTransitioningToActive, !didUserCancel else { return }
        }
    }

    private func startTimeout() {
        timeoutWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            let status = callService.activeCall?.status.lowercased()
            if !isTransitioningToActive && status != "active" {
                didUserCancel = true
                Task {
                    try? await callService.endCall(callId: call.callId)
                    await callService.disconnect(clearActiveCall: true)
                    dismiss()
                }
            }
        }

        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: workItem)
    }

    private func startObserving() {
        callStatusObserver = NotificationCenter.default.addObserver(
            forName: .callStatusChanged,
            object: nil,
            queue: .main
        ) { notification in
            guard let updatedCall = notification.object as? Call,
                  updatedCall.callId == call.callId else {
                return
            }

            let status = updatedCall.status.lowercased()

            if status == "active" {
                timeoutWorkItem?.cancel()
                isWaitingForAnswer = false

                Task {
                    await joinActiveCallIfNeeded()
                }
                return
            }

            if ["ended", "declined", "missed", "completed"].contains(status) {
                didUserCancel = true
                timeoutWorkItem?.cancel()
                dismiss()
            }
        }

        callEndedObserver = NotificationCenter.default.addObserver(
            forName: .callEnded,
            object: nil,
            queue: .main
        ) { notification in
            guard let endedCallId = notification.object as? UUID,
                  endedCallId == call.callId else {
                return
            }

            didUserCancel = true
            timeoutWorkItem?.cancel()
            dismiss()
        }
    }

    private func stopObserving() {
        if let callStatusObserver {
            NotificationCenter.default.removeObserver(callStatusObserver)
            self.callStatusObserver = nil
        }

        if let callEndedObserver {
            NotificationCenter.default.removeObserver(callEndedObserver)
            self.callEndedObserver = nil
        }
    }

    private func joinActiveCallIfNeeded() async {
        guard let activeCall = callService.activeCall, activeCall.callId == call.callId else {
            return
        }

        guard activeCall.status.lowercased() == "active" else {
            return
        }

        isJoiningRoom = true
        connectionError = nil

        do {
            // Почему поменял:
            // outgoing side больше не коннектится в room на onAppear пока звонок pending.
            // Сначала ждём active, потом подключаем LiveKit.
            let (token, wsUrl) = try await callService.getLiveKitToken(callId: call.callId)
            try await callService.connectToRoom(
                callId: call.callId,
                token: token,
                wsUrl: wsUrl,
                publishTracks: true
            )

            await MainActor.run {
                isJoiningRoom = false
                isTransitioningToActive = true
                showingActiveCall = true
            }
        } catch {
            await MainActor.run {
                connectionError = "Ошибка подключения: \(error.localizedDescription)"
                isJoiningRoom = false
            }
        }
    }
}
