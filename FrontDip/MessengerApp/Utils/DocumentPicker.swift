import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .data, .pdf, .text, .plainText, .rtf,
            .spreadsheet, .presentation, .archive,
            .audio, .video, .image, .xml, .json
        ]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let sourceURL = urls.first else { return }

            do {
                let persistedURL = try Self.copyToTemporaryDirectory(from: sourceURL)
                DispatchQueue.main.async {
                    self.parent.selectedURL = persistedURL
                    print("📄 Document copied to temp:", persistedURL)
                }
            } catch {
                DispatchQueue.main.async {
                    self.parent.selectedURL = nil
                    NotificationService.shared.showError("Не удалось открыть документ: \(error.localizedDescription)")
                }
                print("❌ DocumentPicker copy failed:", error)
            }
        }

        private static func copyToTemporaryDirectory(from sourceURL: URL) throws -> URL {
            let didAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = sourceURL.lastPathComponent
            let ext = sourceURL.pathExtension
            let baseName = (fileName as NSString).deletingPathExtension
            let uniqueName = "\(baseName)_\(UUID().uuidString).\(ext)"
            let destinationURL = tempDir.appendingPathComponent(uniqueName)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        }
    }
}
