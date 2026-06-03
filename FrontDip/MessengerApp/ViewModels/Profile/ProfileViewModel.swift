import Foundation
import SwiftUI

class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let graphQL = GraphQLClient.shared
    
    func loadMyProfile() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            
            do {
                let response: MyProfileResponse = try await graphQL.perform(
                    query: GraphQLQueries.myProfile,
                    variables: [:],
                    responseType: MyProfileResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                self.user = response.user.myProfile
                AppState.shared.currentUser = self.user
            } catch {
                self.errorMessage = "Ошибка загрузки профиля: \(error.localizedDescription)"
                print("❌ Profile load error: \(error)")
            }
        }
    }
    
    func updateUser(updatedUser: User, avatarData: Data? = nil) async -> Bool {
        await MainActor.run { isLoading = true }
        
        var avatarUrl = updatedUser.avatarUrl
        if let avatarData = avatarData {
            print("📤 Uploading avatar with size: \(avatarData.count) bytes")
            do {
                let (attachmentId, storagePath) = try await AttachmentUploader.shared.uploadImage(UIImage(data: avatarData)!)
                print("✅ Avatar uploaded: id=\(attachmentId), path=\(storagePath)")
                avatarUrl = storagePath
            } catch {
                print("❌ Avatar upload error: \(error)")
                await MainActor.run { errorMessage = "Ошибка загрузки аватара: \(error.localizedDescription)" }
                return false
            }
        }
        
        guard let currentUserId = AppState.shared.currentUser?.userId.uuidString.lowercased() else {
            await MainActor.run { errorMessage = "Пользователь не авторизован" }
            return false
        }
        
        let nilIfEmpty: (String?) -> Any = { value in
            guard let value = value, !value.isEmpty else { return NSNull() }
            return value
        }
        
        let variables: [String: Any] = [
            "userId": currentUserId,
            "nickName": updatedUser.nickName,
            "firstName": nilIfEmpty(updatedUser.firstName),
            "lastName": nilIfEmpty(updatedUser.lastName),
            "middleName": nilIfEmpty(updatedUser.middleName),
            "email": nilIfEmpty(updatedUser.email),
            "phone": nilIfEmpty(updatedUser.phone),
            "avatarUrl": avatarUrl ?? NSNull(),
            "bio": nilIfEmpty(updatedUser.bio)
        ]
        
        do {
            let response: UpdateUserResponse = try await graphQL.perform(
                query: GraphQLQueries.updateUser,
                variables: variables,
                responseType: UpdateUserResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            await MainActor.run {
                self.user = response.user.update
                AppState.shared.currentUser = self.user
                self.isLoading = false
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            // Пробуем перезагрузить профиль на случай частичного обновления
            await loadMyProfile()
            return false
        }
    }
}
