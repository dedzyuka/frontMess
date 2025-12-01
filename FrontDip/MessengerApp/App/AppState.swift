
import Foundation
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var currentUser: User?
    
    private init() {}
    
    func setup() {
        print("App initialized")
    }
    
    func login() {
        isAuthenticated = true
    }
    
    func logout() {
        isAuthenticated = false
        currentUser = nil
    }
    
    func showError(_ message: String) {
        errorMessage = message
    }
}
