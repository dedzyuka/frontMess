import SwiftUI

struct AvatarView: View {
    let urlString: String?
    let size: CGFloat

    @State private var image: UIImage?

    private var fullURL: URL? {
        guard let urlString, !urlString.isEmpty, urlString != "null" else { return nil }

        if urlString.lowercased().hasPrefix("http") {
            return URL(string: urlString)
        }

        let base = AppConfig.baseURL
        let path = urlString.hasPrefix("/") ? String(urlString.dropFirst()) : urlString
        return URL(string: "\(base)/media/\(path)")
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            MessengerTheme.accent.opacity(0.22),
                            MessengerTheme.secondarySurface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.36, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(MessengerTheme.accent.opacity(0.65), lineWidth: 1)
        )
        .onAppear(perform: loadImage)
    }

    private func loadImage() {
        guard image == nil, let url = fullURL else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let uiImage = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.image = uiImage
            }
        }.resume()
    }
}
