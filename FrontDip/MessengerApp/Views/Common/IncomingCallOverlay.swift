//
//  IncomingCallOverlay.swift
//  MessengerApp
//

import SwiftUI

struct IncomingCallOverlay: View {
    let call: Call
    @Environment(\.dismiss) var dismiss
    @StateObject private var callService = CallService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Входящий звонок")
                .font(.title)
            Text(call.type == "video" ? "Видеозвонок" : "Аудиозвонок")
            HStack(spacing: 40) {
                Button("Отклонить") {
                    Task {
                        try? await callService.rejectCall(callId: call.callId)
                        WebSocketService.shared.sendCallReject(callId: call.callId)
                        dismiss()
                    }
                }
                .foregroundColor(.red)
                Button("Принять") {
                    Task {
                        do {
                            let (token, wsUrl) = try await callService.getLiveKitToken(callId: call.callId)
                            try await callService.connectToRoom(callId: call.callId, token: token, wsUrl: wsUrl)
                            try await callService.acceptCall(callId: call.callId)  // ← добавлен try
                            WebSocketService.shared.sendCallAccept(callId: call.callId)
                            dismiss()
                            NotificationCenter.default.post(name: .showCallScreen, object: call)
                        } catch {
                            print("Failed to accept call: \(error)")
                        }
                    }
                }
                .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}
