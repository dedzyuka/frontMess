//
//  CircularVideoView.swift
//  MessengerApp
//

import SwiftUI
import AVFoundation

struct CircularVideoView: View {
    let attachment: Attachment
    
    @ObservedObject private var manager = VideoCircleManager.shared
    @State private var loopPlayer: AVQueuePlayer?
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
    
    private var isExpanded: Bool {
        manager.expandedVideoId == videoId
    }
    
    var body: some View {
        ZStack {
            if let url = videoURL {
                // Если развёрнут – показываем однократный плеер, иначе – цикл
                if isExpanded {
                    SinglePlayVideoView(url: url)
                        .frame(width: expandedSize, height: expandedSize)
                        .clipShape(Circle())
                } else {
                    LoopingVideoView(player: loopPlayer)
                        .frame(width: collapsedSize, height: collapsedSize)
                        .clipShape(Circle())
                        .onAppear {
                            if loopPlayer == nil {
                                loopPlayer = manager.registerLooper(id: videoId, url: url)
                            } else {
                                loopPlayer?.play()
                            }
                        }
                        .onDisappear {
                            manager.unregisterLooper(id: videoId)
                            loopPlayer?.pause()
                            loopPlayer = nil
                        }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .onTapGesture {
            if isExpanded {
                // Сворачиваем
                manager.setExpanded(nil, url: nil, onFinish: {})
            } else {
                // Разворачиваем и включаем однократное воспроизведение
                if let url = videoURL {
                    manager.setExpanded(videoId, url: url, onFinish: {})
                }
            }
        }
        .onAppear(perform: loadThumbnail)
    }
    
    // MARK: - Thumbnail
    private var thumbnailPlaceholder: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        isLoadingThumbnail ?
                            AnyView(ProgressView()) :
                            AnyView(Image(systemName: "play.circle.fill").font(.largeTitle))
                    )
            }
        }
        .frame(width: collapsedSize, height: collapsedSize)
        .clipShape(Circle())
    }
    
    private var collapsedSize: CGFloat { 150 }
    private var expandedSize: CGFloat { UIScreen.main.bounds.width * 0.7 }
    
    private func loadThumbnail() {
        guard let url = thumbnailURL else { isLoadingThumbnail = false; return }
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data) {
                    thumbnailImage = image
                } else {
                    print("❌ Thumbnail load error: \(error?.localizedDescription ?? "unknown")")
                }
                isLoadingThumbnail = false
            }
        }.resume()
    }
}

// MARK: - Looping Video (бесшумный цикл)
struct LoopingVideoView: UIViewRepresentable {
    let player: AVQueuePlayer?
    
    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.player = player
        view.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.player = player
        uiView.player?.isMuted = true
    }
    
    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) {
        uiView.player?.pause()
    }
}

// MARK: - Single Play Video (один раз со звуком)
struct SinglePlayVideoView: UIViewRepresentable {
    let url: URL
    @State private var player: AVPlayer?
    
    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = false
        view.player = newPlayer
        view.videoGravity = .resizeAspectFill
        newPlayer.play()
        return view
    }
    
    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        // не нужно
    }
    
    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) {
        uiView.player?.pause()
        uiView.player = nil
    }
}

// MARK: - Общий вью для AVPlayerLayer
class PlayerContainerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    var player: AVPlayer? {
        get { (layer as? AVPlayerLayer)?.player }
        set { (layer as? AVPlayerLayer)?.player = newValue }
    }
    
    var videoGravity: AVLayerVideoGravity {
        get { (layer as? AVPlayerLayer)?.videoGravity ?? .resizeAspectFill }
        set { (layer as? AVPlayerLayer)?.videoGravity = newValue }
    }
}
