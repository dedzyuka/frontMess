//
//  IncomingCallView.swift
//  MessengerApp
//

import SwiftUI

struct IncomingCallView: View {
    let call: Call
    let contactName: String
    let avatarURL: String?
    @Environment(\.dismiss) var dismiss
    @StateObject private var callService = CallService.shared
    @State private var showingActiveCall = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                AvatarView(urlString: avatarURL, size: 100)
                    .padding(.top, 40)
                Text(contactName)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("Видеозвонок...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                HStack(spacing: 50) {
                    Button {
                        Task {
                            try? await callService.rejectCall(callId: call.callId)
                            WebSocketService.shared.sendCallReject(callId: call.callId)
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
                            Text("Отклонить")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    Button {
                        Task {
                            do {
                                let (token, wsUrl) = try await callService.getLiveKitToken(callId: call.callId)
                                try await callService.connectToRoom(callId: call.callId, token: token, wsUrl: wsUrl)
                                try await callService.acceptCall(callId: call.callId)
                                WebSocketService.shared.sendCallAccept(callId: call.callId)
                                showingActiveCall = true
                                dismiss()
                            } catch {
                                print("Accept error: \(error)")
                            }
                        }
                    } label: {
                        VStack {
                            Image(systemName: "phone.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.green)
                                .clipShape(Circle())
                            Text("Принять")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .fullScreenCover(isPresented: $showingActiveCall) {
            ActiveCallView(call: call)
        }
        .onDisappear {
            if !showingActiveCall {
                Task { await callService.disconnect() }
            }
        }
    }
}
