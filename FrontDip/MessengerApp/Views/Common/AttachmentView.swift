import SwiftUI
import PhotosUI

struct AttachmentView: View {
    let attachment: Attachment
    let isCurrentUser: Bool
    
    @State private var imageURL: URL?
    @State private var showShareSheet = false
    @State private var fileData: Data?
    @State private var isDownloading = false
    @State private var tempFileURL: URL?
    @State private var showImageViewer = false
    @State private var showSaveSuccess = false
    
    var body: some View {
        Group {
            if attachment.mimeType?.hasPrefix("image/") == true {
                if let url = imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().frame(width: 200, height: 200)
                        case .success(let image):
                            image.resizable().scaledToFit().frame(maxWidth: 200, maxHeight: 200).cornerRadius(12)
                                .onTapGesture {
                                    showImageViewer = true
                                }
                        case .failure:
                            fallbackIcon(systemName: "photo")
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .fullScreenCover(isPresented: $showImageViewer) {
                        ZoomableImageView(imageURL: url)
                    }
                } else {
                    ProgressView().frame(width: 200, height: 200)
                        .onAppear { loadImageURL() }
                }
            } else {
                fileContent
            }
        }
        .contextMenu {
            if attachment.mimeType?.hasPrefix("image/") == true {
                Button("Сохранить в галерею") {
                    saveImageToGallery()
                }
            } else {
                Button("Сохранить") {
                    if let url = tempFileURL {
                        showShareSheet = true
                    } else if fileData != nil {
                        createTempFileAndShare()
                    } else {
                        Task { await downloadAndShare() }
                    }
                }
            }
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
        .alert("Сохранено", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Изображение сохранено в галерею")
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
                    ProgressView().scaleEffect(0.8)
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
                Task { await downloadAndShare() }
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
        let urlString = "http://localhost:9000/messenger/\(attachment.storagePath)"
        if let url = URL(string: urlString) { imageURL = url }
    }
    
    private func saveImageToGallery() {
        guard let url = imageURL else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    await MainActor.run {
                        showSaveSuccess = true
                    }
                }
            } catch {
                print("Save image error: \(error)")
            }
        }
    }
    
    private func downloadAndShare() async {
        isDownloading = true
        let urlString = "http://localhost:9000/messenger/\(attachment.storagePath)"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                fileData = data
                isDownloading = false
                createTempFileAndShare()
            }
        } catch {
            print("Download error: \(error)")
            await MainActor.run { isDownloading = false }
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
