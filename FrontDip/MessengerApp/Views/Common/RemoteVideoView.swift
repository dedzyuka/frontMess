import SwiftUI
import LiveKit
import Combine

struct RemoteVideoView: View {
    let participant: RemoteParticipant
    @State private var videoTrack: VideoTrack?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        Group {
            if let track = videoTrack {
                VideoTrackView(track: track)
                    .onAppear {
                        print("🎬 RemoteVideoView: displaying video track")
                    }
            } else {
                VStack {
                    ProgressView()
                    Text("Ожидание видео...")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .onAppear {
                    print("⚠️ RemoteVideoView: no video track yet, participant = \(participant.identity)")
                    updateTrack()
                }
            }
        }
        .onAppear {
            updateTrack()
            participant.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    updateTrack()
                }
                .store(in: &cancellables)
        }
        .onDisappear {
            cancellables.removeAll()
        }
    }
    
    private func updateTrack() {
        let tracks = participant.videoTracks
        print("🔍 RemoteVideoView: checking \(tracks.count) video tracks")
        guard let publication = tracks.first(where: { $0.kind == .video }),
              let track = publication.track as? VideoTrack else {
            if videoTrack != nil {
                print("⚠️ RemoteVideoView: video track lost")
                videoTrack = nil
            }
            return
        }
        if track.sid != videoTrack?.sid {
            videoTrack = track
            print("✅ RemoteVideoView: got video track, sid=\(track.sid?.stringValue ?? "unknown")")
        }
    }
}
import SwiftUI
import LiveKit
import Combine

struct LocalVideoView: View {
    let participant: LocalParticipant
    @State private var videoTrack: VideoTrack?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        Group {
            if let track = videoTrack {
                VideoTrackView(track: track)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            updateTrack()
            participant.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    updateTrack()
                }
                .store(in: &cancellables)
        }
        .onDisappear {
            cancellables.removeAll()
        }
    }
    
    private func updateTrack() {
        let newTrack = participant.videoTracks.first { $0.kind == .video }?.track as? VideoTrack
        if let newTrack = newTrack, newTrack.sid != videoTrack?.sid {
            videoTrack = newTrack
            print("✅ LocalVideoView: video track active, sid=\(newTrack.sid?.stringValue ?? "unknown")")
        }
    }
}
