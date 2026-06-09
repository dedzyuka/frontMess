import SwiftUI

struct OutgoingCallView: View {
    let call: Call
    let contactName: String
    let avatarURL: String?
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var callService = CallService.shared
    @State private var showingActiveCall = false
    @State private var connectionError: String?
    @State private var isConnecting = true
    @State private var timeoutWorkItem: DispatchWorkItem?
    @State private var hasEnded = false
    @State private var hasBeenDismissed = false

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
                
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Подключение...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                } else if let error = connectionError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Button("Повторить") {
                        Task { await connectToRoom() }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Ожидание ответа...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Button {
                    Task {
                        try? await callService.endCall(callId: call.callId)
                        WebSocketService.shared.sendCallEnd(callId: call.callId)
                        await callService.disconnect()
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
            ActiveCallView(call: call)
                .onAppear {
                    // Закрываем текущий экран после появления ActiveCallView
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }
        }
        .onAppear {
            hasEnded = false
            hasBeenDismissed = false
            Task { await connectToRoom() }
            startObserving()
            
            // Таймаут на случай, если звонок не будет принят
            let workItem = DispatchWorkItem {
                if callService.activeCall?.status != "active" {
                    Task { try? await callService.endCall(callId: call.callId) }
                }
            }
            timeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: workItem)
        }
        .onDisappear {
            stopObserving()
            timeoutWorkItem?.cancel()
            // Вызываем endCall только если звонок всё ещё pending и мы не переключились на активный
            if !hasBeenDismissed && callService.activeCall?.status != "active" {
                Task { try? await callService.endCall(callId: call.callId) }
            }
        }
    }
    
    private func startObserving() {
        NotificationCenter.default.addObserver(
            forName: .callStatusChanged,
            object: nil,
            queue: .main
        ) { notification in
            guard let updatedCall = notification.object as? Call,
                  updatedCall.callId == call.callId,
                  updatedCall.status == "active" else { return }
            hasBeenDismissed = true
            showingActiveCall = true
            dismiss()
        }
    }
    
    private func stopObserving() {
        NotificationCenter.default.removeObserver(self, name: .callStatusChanged, object: nil)
    }
    
    private func connectToRoom() async {
        isConnecting = true
        connectionError = nil
        do {
            let (token, wsUrl) = try await callService.getLiveKitToken(callId: call.callId)
            try await callService.connectToRoom(callId: call.callId, token: token, wsUrl: wsUrl, publishTracks: true)
            isConnecting = false
        } catch {
            connectionError = "Ошибка подключения: \(error.localizedDescription)"
            isConnecting = false
        }
    }
}
