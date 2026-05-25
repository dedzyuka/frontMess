import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    let senderUser: User?
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCurrentUser {
                NavigationLink(destination: UserProfileView(userId: message.senderId)) {
                    AvatarView(urlString: senderUser?.avatarUrl, size: 32)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Spacer().frame(width: 32)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content ?? "")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(18)
                
                HStack(spacing: 4) {
                    Text(formatTime(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if isCurrentUser {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if isCurrentUser {
                Spacer().frame(width: 32)
            } else {
                Spacer().frame(width: 32)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct AvatarView: View {
    let urlString: String?
    let size: CGFloat
    
    var body: some View {
        if let urlString, let url = URL(string: urlString), !urlString.isEmpty {
            AsyncImage(url: url) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "person")
                        .foregroundColor(.gray)
                )
        }
    }
}
