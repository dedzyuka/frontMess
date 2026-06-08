//
//  OutgoingCallView.swift
//  FrontDip
//
//  Created by Bogdan Sakhno on 8.06.26.
//


//
//  OutgoingCallView.swift
//  MessengerApp
//

import SwiftUI

struct OutgoingCallView: View {
    let call: Call
    let contactName: String
    let avatarURL: String?
    @Environment(\.dismiss) var dismiss
    @ObservedObject var callService = CallService.shared
    @State private var showingActiveCall = false

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
                Text("Звоним...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .callStatusChanged)) { notification in
            if let updatedCall = notification.object as? Call,
               updatedCall.callId == call.callId,
               updatedCall.status == "active" {
                showingActiveCall = true
                dismiss()
            }
        }
    }
}