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
    @State private var isSpeakerOn = false
    
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
            
            // Локальное видео (превью своей камеры)
            if let localParticipant = callService.room?.localParticipant, isCameraOn {
                LocalVideoView(participant: localParticipant)
                    .frame(width: 100, height: 150)
                    .cornerRadius(12)
                    .padding()
                    .position(x: UIScreen.main.bounds.width - 70, y: 100)
            }
            
            // Элементы управления
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
                    
                    Button {
                        isSpeakerOn.toggle()
                        let audioSession = AVAudioSession.sharedInstance()
                        try? audioSession.overrideOutputAudioPort(isSpeakerOn ? .speaker : .none)
                    } label: {
                        Image(systemName: isSpeakerOn ? "speaker.wave.2.fill" : "speaker.fill")
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
                }
                .padding(.bottom, 40)
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
import SwiftUI
import LiveKit

struct RemoteVideoView: View {
    let participant: RemoteParticipant
    @State private var videoTrackId: String?
    @State private var videoTrack: VideoTrack?
    
    var body: some View {
        Group {
            if let track = videoTrack {
                VideoTrackView(track: track)
            } else {
                ProgressView()
                    .onAppear {
                        print("RemoteVideoView: waiting for video track for participant \(participant.identity)")
                        updateTrack()
                    }
            }
        }
        .onReceive(participant.objectWillChange) { _ in
            updateTrack()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            updateTrack()
        }
    }
    
    private func updateTrack() {
        let newTrack = participant.videoTracks.first?.track as? VideoTrack
        let newTrackId = newTrack?.sid?.stringValue
        if newTrackId != videoTrackId {
            videoTrackId = newTrackId
            videoTrack = newTrack
            if let track = newTrack {
                print("RemoteVideoView: video track added, sid = \(track.sid?.stringValue ?? "unknown")")
            } else {
                print("RemoteVideoView: video track still nil")
            }
        }
    }
}

struct VideoTrackView: UIViewRepresentable {
    let track: VideoTrack
    
    func makeUIView(context: Context) -> LiveKit.VideoView {
        let view = LiveKit.VideoView()
        track.add(videoRenderer: view)
        print("VideoTrackView: renderer added for track \(track.sid?.stringValue ?? "unknown")")
        return view
    }
    
    func updateUIView(_ uiView: LiveKit.VideoView, context: Context) {}
}

// MARK: - LocalVideoView
struct LocalVideoView: View {
    let participant: LocalParticipant
    @State private var videoTrack: VideoTrack?
    
    var body: some View {
        Group {
            if let track = videoTrack {
                VideoTrackView(track: track)
            } else {
                ProgressView()
                    .onAppear {
                        updateTrack()
                    }
            }
        }
        .onReceive(participant.objectWillChange) { _ in
            updateTrack()
        }
    }
    
    private func updateTrack() {
        let newTrack = participant.videoTracks.first?.track as? VideoTrack
        if newTrack?.sid?.stringValue != videoTrack?.sid?.stringValue {
            videoTrack = newTrack
            if let track = newTrack {
                print("LocalVideoView: video track available, sid = \(track.sid?.stringValue ?? "unknown")")
            }
        }
    }
}
