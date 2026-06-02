import Foundation
import UIKit

enum UploadError: Error {
    case invalidImage
    case notAuthenticated
    case invalidResponse
    case networkError(String)
}

class AttachmentUploader {
    static let shared = AttachmentUploader()
    private let baseURL = AppConfig.baseURL

    func uploadImage(_ image: UIImage) async throws -> UUID {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.invalidImage
        }
        return try await upload(data: imageData, mimeType: "image/jpeg", fileName: "image.jpg")
    }

    func uploadFile(url: URL) async throws -> UUID {
        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        let mimeType = guessMimeType(from: fileName)
        return try await upload(data: data, mimeType: mimeType, fileName: fileName)
    }

    private func upload(data: Data, mimeType: String, fileName: String) async throws -> UUID {
        guard let token = TokenManager.shared.accessToken else {
            print("❌ Upload: no access token")
            throw UploadError.notAuthenticated
        }
        print("✅ Upload: using token: \(token.prefix(20))...")

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/upload/")!)
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
        return uuid
    }

    private func guessMimeType(from fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "mp4": return "video/mp4"
        case "mp3": return "audio/mpeg"
        case "pdf": return "application/pdf"
        case "doc", "docx": return "application/msword"
        case "xls", "xlsx": return "application/vnd.ms-excel"
        case "zip", "rar": return "application/zip"
        case "txt": return "text/plain"
        default: return "application/octet-stream"
        }
    }
}
