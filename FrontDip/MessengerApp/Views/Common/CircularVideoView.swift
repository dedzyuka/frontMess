//
//  CircularVideoView.swift
//  MessengerApp
//

import SwiftUI
import AVKit

struct CircularVideoView: View {
    let attachment: Attachment
    @State private var showPlayer = false
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true

    private var thumbnailURL: URL? {
        guard let path = attachment.thumbnailUrl, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        let base = AppConfig.baseURL
        let fullPath = path.hasPrefix("/") ? path : "/media/" + path
        return URL(string: base + fullPath)
    }

    private var videoURL: URL? {
        let base = AppConfig.baseURL
        let path = attachment.storagePath.hasPrefix("/") ? attachment.storagePath : "/media/" + attachment.storagePath
        return URL(string: base + path)
    }

    var body: some View {
        Button {
            showPlayer = true
        } label: {
            ZStack {
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 150, height: 150)
                        .overlay(ProgressView().scaleEffect(0.8))
                }

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .shadow(radius: 3)
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let url = videoURL {
                VideoPlayerView(url: url)
            }
        }
        .onAppear(perform: loadThumbnail)
    }

    private func loadThumbnail() {
        guard let url = thumbnailURL else { return }
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async { thumbnailImage = image; isLoading = false }
            } else {
                DispatchQueue.main.async { isLoading = false }
                print("❌ Thumbnail load error: \(error?.localizedDescription ?? "unknown")")
            }
        }.resume()
    }
}
