//
//  CircularVideoView.swift
//  MessengerApp
//

import SwiftUI
import AVFoundation

struct CircularVideoView: View {
    let attachment: Attachment
    @ObservedObject private var manager = VideoCircleManager.shared
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = true
    
    private var videoId: String { attachment.attachmentId.uuidString }
    private var videoURL: URL? {
        let base = AppConfig.baseURL
        let path = attachment.storagePath.hasPrefix("/") ? attachment.storagePath : "/media/" + attachment.storagePath
        return URL(string: base + path)
    }
    
    private var thumbnailURL: URL? {
        guard let path = attachment.thumbnailUrl, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        let base = AppConfig.baseURL
        let fullPath = path.hasPrefix("/") ? path : "/media/" + path
        return URL(string: base + fullPath)
    }
    
    private var isPlaying: Bool {
        manager.expandedVideoId == videoId && manager.activePlayer != nil
    }
    
    var body: some View {
        ZStack {
            if isPlaying, let player = manager.activePlayer {
                VideoPlayerLayer(player: player)
                    .frame(width: expandedSize, height: expandedSize)
                    .clipShape(Circle())
            } else {
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: collapsedSize, height: collapsedSize)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: collapsedSize, height: collapsedSize)
                        .overlay(isLoadingThumbnail ? ProgressView() : nil)
                }
            }
        }
        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPlaying)
        .onTapGesture {
            guard let url = videoURL else { return }
            if isPlaying {
                manager.stopCurrent()
            } else {
                manager.play(id: videoId, url: url) { }
            }
        }
        .onDisappear {
            if isPlaying {
                manager.stopCurrent()
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard let url = thumbnailURL else {
            isLoadingThumbnail = false
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data) {
                    thumbnailImage = image
                } else if error != nil {
                    print("Thumbnail error: \(error!.localizedDescription)")
                }
                isLoadingThumbnail = false
            }
        }.resume()
    }
    
    private var collapsedSize: CGFloat { 150 }
    private var expandedSize: CGFloat { UIScreen.main.bounds.width * 0.7 }
}

// MARK: - VideoPlayerLayer
struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer?
    
    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.player = player
        view.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.player = player
    }
}

class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var player: AVPlayer? {
        get { (layer as? AVPlayerLayer)?.player }
        set { (layer as? AVPlayerLayer)?.player = newValue }
    }
    var videoGravity: AVLayerVideoGravity {
        get { (layer as? AVPlayerLayer)?.videoGravity ?? .resizeAspectFill }
        set { (layer as? AVPlayerLayer)?.videoGravity = newValue }
    }
}
