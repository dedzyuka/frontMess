//
//  GrapgQLModels.swift
//  FrontDip
//
//  Created by Bogdan Sakhno on 21.05.26.
//

import Foundation

// MARK: - Общие структуры для пользователя и чата
struct GraphQLUser: Decodable {
    let user_id: UUID
    let nick_name: String
    let email: String?
    let avatar_url: String?
    let created_at: Date
    let updated_at: Date
    let is_online: Bool
}

struct GraphQLChat: Decodable {
    let chat_id: UUID
    let name: String?
    let chat_type: String
    let members_count: Int
    let created_at: Date
    let updated_at: Date
    let last_message_preview: GraphQLMessagePreview?
}

struct GraphQLMessagePreview: Decodable {
    let message_id: Int
    let sender_id: String
    let text_preview: String?
    let created_at: Date
}

