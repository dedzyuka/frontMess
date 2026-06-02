import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Готово") { dismiss() }
                    }
                }
        }
        .onAppear {
            // Автоматически начать воспроизведение
            let player = AVPlayer(url: url)
            player.play()
        }
    }
}
