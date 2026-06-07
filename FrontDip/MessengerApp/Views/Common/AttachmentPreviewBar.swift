import SwiftUI

struct AttachmentPreviewBar: View {
    enum AttachmentType {
        case image(UIImage)
        case video(URL)
        case document(URL)
        case forward(content: String, fromNickname: String, attachmentId: UUID?)   // пересылка
    }
    
    let type: AttachmentType
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Иконка / превью
            Group {
                switch type {
                case .image(let image):
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .video(let url):
                    ZStack {
                        VideoThumbnailView(url: url)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                case .document(let url):
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 50, height: 50)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .forward(let content, let fromNickname, _):
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.right.fill")
                                .font(.caption)
                            Text("Переслано от \(fromNickname)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        Text(content.isEmpty ? "[Вложение]" : content)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Информация
            VStack(alignment: .leading, spacing: 2) {
                switch type {
                case .image:
                    Text("Изображение")
                        .font(.caption)
                        .fontWeight(.medium)
                case .video(let url):
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                case .document(let url):
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                case .forward(_, _, let attachmentId):
                    Text(attachmentId == nil ? "Текстовое сообщение" : "Сообщение с вложением")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if case .video = type {
                    Text("Видео")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
