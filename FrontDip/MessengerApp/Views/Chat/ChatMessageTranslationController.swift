import Foundation
import SwiftUI

@MainActor
final class ChatMessageTranslationController: ObservableObject {
    struct State {
        let originalText: String
        let translatedText: String
        let sourceLanguage: String
        let targetLanguage: String
        var isShowingTranslation: Bool
    }

    @Published private(set) var translatedMessages: [Int64: State] = [:]
    @Published private(set) var loadingIds: Set<Int64> = []

    private let service = MessageTranslationService.shared

    func availableTargets(for message: Message) -> [TranslationTargetLanguage] {
        guard let text = message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return []
        }
        return service.availableTargets(for: text)
    }

    func displayText(for message: Message) -> String {
        if let state = translatedMessages[message.messageId], state.isShowingTranslation {
            return state.translatedText
        }
        return message.content ?? ""
    }

    func isTranslated(_ messageId: Int64) -> Bool {
        translatedMessages[messageId]?.isShowingTranslation == true
    }

    func isLoading(_ messageId: Int64) -> Bool {
        loadingIds.contains(messageId)
    }

    func caption(for messageId: Int64) -> String? {
        guard let state = translatedMessages[messageId], state.isShowingTranslation else { return nil }
        return "Переведено: \(state.sourceLanguage) → \(state.targetLanguage)"
    }

    func reset(_ messageId: Int64) {
        guard var state = translatedMessages[messageId] else { return }
        state.isShowingTranslation = false
        translatedMessages[messageId] = state
    }

    func clear() {
        translatedMessages.removeAll()
        loadingIds.removeAll()
    }

    func invalidate(_ messageId: Int64) {
        translatedMessages.removeValue(forKey: messageId)
        loadingIds.remove(messageId)
    }

    func translate(message: Message, targetLanguage: TranslationTargetLanguage) async {
        guard let raw = message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return
        }

        if let cached = translatedMessages[message.messageId],
           cached.originalText == raw,
           cached.targetLanguage == targetLanguage.rawValue {
            var updated = cached
            updated.isShowingTranslation = true
            translatedMessages[message.messageId] = updated
            return
        }

        loadingIds.insert(message.messageId)
        defer { loadingIds.remove(message.messageId) }

        do {
            let payload = try await service.translate(text: raw, targetLanguage: targetLanguage)
            translatedMessages[message.messageId] = State(
                originalText: payload.originalText,
                translatedText: payload.translatedText,
                sourceLanguage: payload.sourceLanguage,
                targetLanguage: payload.targetLanguage,
                isShowingTranslation: true
            )
        } catch {
            NotificationService.shared.showError(error.localizedDescription)
        }
    }
}
