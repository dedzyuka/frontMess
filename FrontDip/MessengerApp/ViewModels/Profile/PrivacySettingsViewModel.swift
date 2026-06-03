// ./FrontDip/MessengerApp/ViewModels/Profile/PrivacySettingsViewModel.swift
import Foundation

class PrivacySettingsViewModel: ObservableObject {
    @Published var settings: PrivacySettingsResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let graphQL = GraphQLClient.shared
    
    func loadSettings() {
        isLoading = true
        Task {
            do {
                let response: MyPrivacyResponse = try await graphQL.perform(
                    query: GraphQLQueries.myPrivacy,
                    variables: [:],
                    responseType: MyPrivacyResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                await MainActor.run {
                    self.settings = response.user.myPrivacy
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func update(whoCanWriteMe: String? = nil,
                whoCanAddToGroups: String? = nil,
                whoCanSeePhone: String? = nil,
                whoCanSeeLastSeen: String? = nil) async -> Bool {
        await MainActor.run { isLoading = true }
        var variables: [String: Any] = [:]
        if let w = whoCanWriteMe { variables["whoCanWriteMe"] = w }
        if let a = whoCanAddToGroups { variables["whoCanAddToGroups"] = a }
        if let p = whoCanSeePhone { variables["whoCanSeePhone"] = p }
        if let l = whoCanSeeLastSeen { variables["whoCanSeeLastSeen"] = l }
        
        do {
            let response: UpdatePrivacyResponse = try await graphQL.perform(
                query: GraphQLQueries.updatePrivacy,
                variables: variables,
                responseType: UpdatePrivacyResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            await MainActor.run {
                self.settings = response.user.updatePrivacy
                self.isLoading = false
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
}
