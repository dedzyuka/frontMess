import SwiftUI
import LiveKit

struct VideoTrackView: UIViewRepresentable {
    let track: VideoTrack?
    
    func makeUIView(context: Context) -> LiveKit.VideoView {
        let view = LiveKit.VideoView()
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: LiveKit.VideoView, context: Context) {
        if uiView.track !== track {
            uiView.track = track
            print("🎥 VideoTrackView: track updated, hasTrack=\(track != nil)")
        }
    }
}
