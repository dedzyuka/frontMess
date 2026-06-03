import SwiftUI
import AVKit
import Photos

struct AttachmentView: View {
    let attachment: Attachment
    let isCurrentUser: Bool
    
    @State private var imageURL: URL?
    @State private var showShareSheet = false
    @State private var fileData: Data?
    @State private var isDownloading = false
    @State private var tempFileURL: URL?
    @State private var showImageViewer = false
    @State private var showVideoPlayer = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    
    var body: some View {
        Group {
            if attachment.mimeType?.hasPrefix("image/") == true {
                imageContent
            } else if attachment.mimeType?.hasPrefix("video/") == true {
                videoContent
            } else {
                fileContent
            }
        }
        .contextMenu {
            if attachment.mimeType?.hasPrefix("image/") == true {
                Button("Сохранить в галерею") {
                    saveImageToGallery()
                }
            } else if attachment.mimeType?.hasPrefix("video/") == true {
                Button("Сохранить видео") {
                    saveVideoToFiles()
                }
            } else {
                Button("Сохранить") {
                    saveFile()
                }
            }
        }
        .alert("Сохранено", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Сохранено")
        }
        .alert("Ошибка", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = tempFileURL {
                ActivityView(activityItems: [url])
                    .onDisappear {
                        try? FileManager.default.removeItem(at: url)
                        tempFileURL = nil
                    }
            }
        }
    }
    
    @ViewBuilder
    private var imageContent: some View {
        if let url = imageURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .cornerRadius(12)
                        .onTapGesture {
                            showImageViewer = true
                        }
                } else if phase.error != nil {
                    fallbackIcon(systemName: "photo")
                } else {
                    ProgressView()
                }
            }
            .fullScreenCover(isPresented: $showImageViewer) {
                ZoomableImageView(imageURL: url)
            }
        } else {
            ProgressView()
                .onAppear {
                    loadImageURL()
                }
        }
    }
    
    @ViewBuilder
    private var videoContent: some View {
        if let url = imageURL {
            VideoThumbnailView(url: url)
                .frame(maxWidth: 200, maxHeight: 200)
                .cornerRadius(12)
                .onTapGesture {
                    showVideoPlayer = true
                }
                .fullScreenCover(isPresented: $showVideoPlayer) {
                    VideoPlayerView(url: url)
                }
        } else {
            ProgressView().frame(width: 200, height: 200)
                .onAppear {
                    print("Video onAppear, storagePath=\(attachment.storagePath)")
                    loadImageURL()
                }
        }
    }
    
    @ViewBuilder
    private var fileContent: some View {
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
                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            Spacer()
            Image(systemName: "arrow.down.circle")
                .foregroundColor(isCurrentUser ? .white : .blue)
        }
        .padding(10)
        .background(isCurrentUser ? Color.blue : Color(.systemGray5))
        .cornerRadius(12)
        .onTapGesture {
            if tempFileURL != nil {
                showShareSheet = true
            } else if fileData == nil && !isDownloading {
                Task {
                    await downloadAndShare()
                }
            } else if fileData != nil {
                createTempFileAndShare()
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
        let base = AppConfig.baseURL
        let path = attachment.storagePath
        let urlString = base + "/media/" + path
        if let url = URL(string: urlString) {
            print("Attachment URL: \(urlString)")
            imageURL = url
        }
    }
    
    private func saveImageToGallery() {
        guard let url = imageURL else {
            saveErrorMessage = "Изображение не загружено"
            showSaveError = true
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else {
                    throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать изображение"])
                }
                
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized else {
                    throw NSError(domain: "PhotoLibrary", code: -3, userInfo: [NSLocalizedDescriptionKey: "Нет доступа к галерее. Разрешите доступ в настройках."])
                }
                
                await MainActor.run {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    showSaveSuccess = true
                }
            } catch {
                await MainActor.run {
                    saveErrorMessage = error.localizedDescription
                    showSaveError = true
                }
            }
        }
    }
    
    private func saveVideoToFiles() {
        guard let url = imageURL else { return }
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = attachment.fileName
        let destURL = tempDir.appendingPathComponent(fileName)
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: destURL)
                await MainActor.run {
                    tempFileURL = destURL
                    showShareSheet = true
                }
            } catch {
                print("Save video error: \(error)")
            }
        }
    }
    
    private func saveFile() {
        if let url = tempFileURL {
            showShareSheet = true
        } else if fileData != nil {
            createTempFileAndShare()
        } else {
            Task {
                await downloadAndShare()
            }
        }
    }
    
    private func downloadAndShare() async {
        isDownloading = true
        guard let url = imageURL else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                fileData = data
                isDownloading = false
                createTempFileAndShare()
            }
        } catch {
            await MainActor.run {
                isDownloading = false
            }
        }
    }
    
    private func createTempFileAndShare() {
        guard let data = fileData else { return }
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(attachment.fileName)
        do {
            try data.write(to: fileURL)
            tempFileURL = fileURL
            showShareSheet = true
        } catch {
            print("Failed to create temp file: \(error)")
        }
    }
    
    private func iconForMimeType(_ mime: String?) -> String {
        guard let mime = mime else { return "doc" }
        if mime.hasPrefix("image") { return "photo" }
        if mime.hasPrefix("video") { return "video" }
        if mime.hasPrefix("audio") { return "music.note" }
        if mime == "application/pdf" { return "doc" }
        if mime == "application/zip" || mime == "application/x-zip-compressed" { return "doc.zipper" }
        if mime.hasPrefix("text") { return "doc.text" }
        if mime.contains("word") || mime.contains("document") { return "doc" }
        if mime.contains("excel") || mime.contains("spreadsheet") { return "tablecells" }
        return "doc"
    }
    
    private func formattedFileSize(_ size: Int?) -> String {
        guard let size = size else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


import SwiftUI
import AVKit

struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Color.black
                    Image(systemName: "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        if let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil) {
            thumbnail = UIImage(cgImage: cgImage)
        }
    }
}
