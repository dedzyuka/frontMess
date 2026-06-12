import Foundation
import UIKit

enum UploadError: Error, LocalizedError {
    case invalidImage
    case notAuthenticated
    case invalidResponse
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image"
        case .notAuthenticated:
            return "Not authenticated"
        case .invalidResponse:
            return "Invalid server response"
        case .networkError(let message):
            return message
        }
    }
}

final class AttachmentUploader {
    static let shared = AttachmentUploader()
    private let baseURL = AppConfig.baseURL

    func uploadImage(_ image: UIImage) async throws -> (attachmentId: UUID, storagePath: String) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.invalidImage
        }
        return try await upload(data: imageData, mimeType: "image/jpeg", fileName: "image.jpg")
    }

    func uploadFile(url: URL, mimeType: String? = nil) async throws -> (attachmentId: UUID, storagePath: String) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        print("⬆️ uploadFile url:", url)
        print("⬆️ uploadFile exists:", FileManager.default.fileExists(atPath: url.path))

        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        let finalMimeType = mimeType ?? guessMimeType(from: fileName)

        print("⬆️ fileName:", fileName)
        print("⬆️ mimeType:", finalMimeType)
        print("⬆️ size:", data.count)

        return try await upload(data: data, mimeType: finalMimeType, fileName: fileName)
    }

    private func upload(data: Data, mimeType: String, fileName: String) async throws -> (attachmentId: UUID, storagePath: String) {
        guard let token = TokenManager.shared.accessToken, !token.isEmpty else {
            print("❌ No access token for upload")
            throw UploadError.notAuthenticated
        }

        let boundary = UUID().uuidString
        let url = URL(string: "\(baseURL)/upload/")!

        print("⬆️ Upload start:", url.absoluteString)
        print("⬆️ Token prefix:", String(token.prefix(20)))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("⬇️ Upload status:", httpResponse.statusCode)
        }

        if let text = String(data: responseData, encoding: .utf8) {
            print("⬇️ Upload response:", text)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UploadError.networkError("Server error")
        }

        struct Response: Decodable {
            let attachment_id: String
        }

        let decoded = try JSONDecoder().decode(Response.self, from: responseData)

        guard let uuid = UUID(uuidString: decoded.attachment_id) else {
            throw UploadError.invalidResponse
        }

        let ext = (fileName as NSString).pathExtension
        let storagePath = "attachments/\(uuid.uuidString).\(ext)"
        return (uuid, storagePath)
    }

    func guessMimeType(from fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/m4a"
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "zip": return "application/zip"
        case "rar": return "application/vnd.rar"
        case "txt": return "text/plain"
        default: return "application/octet-stream"
        }
    }
}
