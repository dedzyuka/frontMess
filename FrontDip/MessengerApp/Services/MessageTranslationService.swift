import Foundation
import NaturalLanguage

enum TranslationTargetLanguage: String, CaseIterable, Identifiable {
    case ru
    case en

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .ru: return "Перевести на русский"
        case .en: return "Перевести на английский"
        }
    }

    var displayTitle: String {
        switch self {
        case .ru: return "русский"
        case .en: return "английский"
        }
    }
}

enum MessageTranslationError: LocalizedError {
    case empty
    case unsupported
    case sameLanguage

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Нечего переводить"
        case .unsupported:
            return "Поддерживаются только русский и английский"
        case .sameLanguage:
            return "Сообщение уже на выбранном языке"
        }
    }
}

final class MessageTranslationService {
    static let shared = MessageTranslationService()

    private let graphQL = GraphQLClient.shared

    private init() {}

    func detectLanguage(for text: String) -> TranslationTargetLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)

        if let lang = recognizer.dominantLanguage {
            switch lang {
            case .russian: return .ru
            case .english: return .en
            default: break
            }
        }

        var cyr = 0
        var lat = 0
        for scalar in trimmed.unicodeScalars {
            switch scalar.value {
            case 0x0400...0x04FF: cyr += 1
            case 0x0041...0x005A, 0x0061...0x007A: lat += 1
            default: break
            }
        }

        if cyr == 0 && lat == 0 { return nil }
        return cyr >= lat ? .ru : .en
    }

    func availableTargets(for text: String) -> [TranslationTargetLanguage] {
        guard let source = detectLanguage(for: text) else {
            return [.ru, .en]
        }

        switch source {
        case .ru: return [.en]
        case .en: return [.ru]
        }
    }

    func translate(text: String, targetLanguage: TranslationTargetLanguage) async throws -> TranslationPayload {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MessageTranslationError.empty }

        let source = detectLanguage(for: trimmed)
        guard let source else { throw MessageTranslationError.unsupported }
        guard source != targetLanguage else { throw MessageTranslationError.sameLanguage }

        let variables: [String: Any] = [
            "input": [
                "text": trimmed,
                "targetLanguage": targetLanguage.rawValue,
                "sourceLanguage": source.rawValue
            ]
        ]

        let response: TranslateTextResponse = try await graphQL.perform(
            query: GraphQLQueries.translateText,
            variables: variables,
            responseType: TranslateTextResponse.self,
            authToken: TokenManager.shared.accessToken
        )

        return response.translation.translate
    }
}
