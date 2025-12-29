import Foundation

// Вместо текущего декодера, использовать этот:
extension JSONDecoder {
    static let flexibleISO8601: JSONDecoder = {
        let decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Форматы для сервера FastAPI
            let formatters: [ISO8601DateFormatter] = [
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return f
                }(),
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime]
                    return f
                }(),
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
                    return f
                }()
            ]
            
            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            // Пробуем старые форматы DateFormatter как fallback
            let legacyFormatters: [DateFormatter] = [
                {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                    f.locale = Locale(identifier: "en_US_POSIX")
                    f.timeZone = TimeZone(secondsFromGMT: 0)
                    return f
                }(),
                {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    f.locale = Locale(identifier: "en_US_POSIX")
                    f.timeZone = TimeZone(secondsFromGMT: 0)
                    return f
                }()
            ]
            
            for formatter in legacyFormatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
        
        return decoder
    }()
}
