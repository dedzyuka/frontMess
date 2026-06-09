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
        // Ключевое: присваиваем трек
        uiView.track = track
        // Принудительно запрашиваем рендеринг, если трек есть
        if track != nil && !uiView.isRendering {
            uiView.setNeedsLayout()
        }
    }
}
