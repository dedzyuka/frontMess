//
//  PendingForwardManager.swift
//  MessengerApp
//

import Foundation

/// Глобальный менеджер для временного хранения данных пересылки
final class PendingForwardManager {
    static let shared = PendingForwardManager()
    
    struct ForwardData {
        let originalContent: String
        let forwardedFromUserId: UUID
        let forwardedFromNickname: String
        let attachmentId: UUID?
        let targetChatId: UUID
    }
    
    private var pendingData: ForwardData?
    
    private init() {}
    
    /// Сохранить данные пересылки для целевого чата
    func setPendingForward(chatId: UUID,
                           content: String,
                           fromUserId: UUID,
                           fromNickname: String,
                           attachmentId: UUID?) {
        pendingData = ForwardData(
            originalContent: content,
            forwardedFromUserId: fromUserId,
            forwardedFromNickname: fromNickname,
            attachmentId: attachmentId,
            targetChatId: chatId
        )
    }
    
    /// Забрать данные пересылки для указанного чата (если они есть и совпадают)
    func consumePendingForward(for chatId: UUID) -> (content: String,
                                                     fromUserId: UUID,
                                                     fromNickname: String,
                                                     attachmentId: UUID?)? {
        guard let data = pendingData, data.targetChatId == chatId else { return nil }
        pendingData = nil
        return (data.originalContent,
                data.forwardedFromUserId,
                data.forwardedFromNickname,
                data.attachmentId)
    }
}
