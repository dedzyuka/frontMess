//
//  CallView.swift
//  MessengerApp
//

import SwiftUI
import LiveKit
import AVFoundation

struct CallView: View {
    @ObservedObject var callService = CallService.shared
    @Environment(\.dismiss) var dismiss
    @State private var isCameraOn = true
    @State private var isMicOn = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Видео удалённого участника
            if let remoteParticipant = callService.room?.remoteParticipants.values.first {
                RemoteVideoView(participant: remoteParticipant)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Ожидание подключения...")
                        .foregroundColor(.white)
                        .padding(.top, 20)
                }
            }
            
            VStack {
                Spacer()
                HStack(spacing: 40) {
                    Button {
                        Task {
                            try? await callService.toggleMicrophone(enabled: !isMicOn)
                            isMicOn.toggle()
                        }
                    } label: {
                        Image(systemName: isMicOn ? "mic.fill" : "mic.slash.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.gray.opacity(0.7))
                            .clipShape(Circle())
                    }
                    
                    Button {
                        Task {
                            if let call = callService.currentCall {
                                try? await callService.endCall(callId: call.callId)
                                WebSocketService.shared.sendCallEnd(callId: call.callId)
                                await callService.disconnect()
                                dismiss()
                            }
                        }
                    } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    
                    Button {
                        Task {
                            try? await callService.toggleCamera(enabled: !isCameraOn)
                            isCameraOn.toggle()
                        }
                    } label: {
                        Image(systemName: isCameraOn ? "video.fill" : "video.slash.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.gray.opacity(0.7))
                            .clipShape(Circle())
                    }
                    
                    Button {
                        Task {
                            try? await callService.switchCamera()
                        }
                    } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.gray.opacity(0.7))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 40)
            }
            
            // Локальное видео
            if let localParticipant = callService.room?.localParticipant, isCameraOn {
                LocalVideoView(participant: localParticipant)
                    .frame(width: 100, height: 150)
                    .cornerRadius(12)
                    .padding()
                    .position(x: UIScreen.main.bounds.width - 70, y: 100)
            }
        }
        .onAppear {
            AVCaptureDevice.requestAccess(for: .video) { _ in }
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
        .onDisappear {
            if callService.currentCall != nil {
                Task { await callService.disconnect() }
            }
        }
    }
}

