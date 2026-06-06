//
//  AvatarView.swift
//  FrontDip
//

import SwiftUI

struct AvatarView: View {
    let urlString: String?
    let size: CGFloat
    @State private var image: UIImage?
    
    private var fullURL: URL? {
        guard let urlString, !urlString.isEmpty, urlString != "null" else { return nil }
        // Приводим к нижнему регистру, чтобы избежать проблем с регистром в MinIO
        let lowerPath = urlString.lowercased()
        if lowerPath.hasPrefix("http") {
            return URL(string: lowerPath)
        }
        let base = AppConfig.baseURL
        let path = lowerPath.hasPrefix("/") ? String(lowerPath.dropFirst()) : lowerPath
        return URL(string: base + "/media/" + path)
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                placeholderView
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = fullURL else { return }
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("❌ Avatar load error: \(error.localizedDescription)")
                return
            }
            guard let data = data, let uiImage = UIImage(data: data) else {
                print("❌ Failed to decode image from data")
                return
            }
            DispatchQueue.main.async {
                self.image = uiImage
            }
        }.resume()
    }
    
    private var placeholderView: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person")
                    .foregroundColor(.gray)
            )
    }
}
