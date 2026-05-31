// MARK: - Компонент для отображения вложения

import Foundation
import SwiftUI
struct AttachmentView: View {
    let attachment: Attachment
    let isCurrentUser: Bool
    
    @State private var imageURL: URL?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if attachment.mimeType?.hasPrefix("image/") == true {
                // Изображение
                if let url = imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 200, height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200, maxHeight: 200)
                                .cornerRadius(12)
                        case .failure:
                            // fallback иконка при ошибке загрузки
                            fallbackIcon(systemName: "photo")
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .onTapGesture {
                        // TODO: открыть полноэкранный просмотр
                        print("Open image: \(attachment.storagePath)")
                    }
                } else {
                    ProgressView()
                        .frame(width: 200, height: 200)
                        .onAppear {
                            loadImageURL()
                        }
                }
            } else {
                // Файл (документ, аудио, видео и т.д.)
                HStack {
                    Image(systemName: iconForMimeType(attachment.mimeType))
                        .font(.title2)
                        .foregroundColor(isCurrentUser ? .white : .blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(attachment.fileName)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(formattedFileSize(attachment.fileSize))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(isCurrentUser ? .white : .blue)
                }
                .padding(10)
                .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                .cornerRadius(12)
                .onTapGesture {
                    // TODO: скачать файл или открыть
                    print("Download file: \(attachment.storagePath)")
                }
            }
        }
    }
    
    @ViewBuilder
    private func fallbackIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .frame(width: 50, height: 50)
            .padding()
            .foregroundColor(.gray)
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
    
    private func loadImageURL() {
        // Прямой URL к MinIO (для локальной разработки)
        // В production нужно получать подписанный URL от сервера
        let urlString = "http://localhost:9000/messenger/\(attachment.storagePath)"
        if let url = URL(string: urlString) {
            self.imageURL = url
        }
        isLoading = false
    }
    
    private func iconForMimeType(_ mime: String?) -> String {
        guard let mime = mime else { return "doc" }
        if mime.hasPrefix("image") { return "photo" }
        if mime.hasPrefix("video") { return "video" }
        if mime.hasPrefix("audio") { return "music.note" }
        if mime == "application/pdf" { return "doc" }
        if mime.hasPrefix("text") { return "doc.text" }
        return "doc"
    }
    
    private func formattedFileSize(_ size: Int?) -> String {
        guard let size = size else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}
