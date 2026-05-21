import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    
    init(message: Message, isCurrentUser: Bool = false) {
        self.message = message
        self.isCurrentUser = isCurrentUser
    }
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Текст сообщения
                Text(message.content ?? "")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(18)
                    .contextMenu {
                        Button("Копировать") {
                            UIPasteboard.general.string = message.content ?? ""
                        }
                        
                        Button("Переслать") {
                            // TODO: Реализовать пересылку
                        }
                        
                        if isCurrentUser {
                            Button("Удалить", role: .destructive) {
                                // TODO: Реализовать удаление
                            }
                        }
                    }
                
                // Время и статус
                HStack(spacing: 4) {
                    Text(formatTime(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isCurrentUser {
                        // Статус доставки (упрощённо)
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if !isCurrentUser {
                Spacer()
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
