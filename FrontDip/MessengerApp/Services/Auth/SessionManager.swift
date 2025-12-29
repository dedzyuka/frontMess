// ./FrontDip/MessengerApp/Services/Auth/SessionManager.swift
import Foundation
import Combine

class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = true
    
    private let authViewModel = AuthViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBindings()
    }
    
    func start() {
        print("🚀 Запуск SessionManager...")
        
        if authViewModel.hasSavedUser() {
            Task {
                await authViewModel.restoreSession()
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } else {
            isLoading = false
        }
    }
    
    private func setupBindings() {
        AppState.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
            }
            .store(in: &cancellables)
        
        AppState.shared.$currentUser
            .sink { [weak self] user in
                self?.currentUser = user
            }
            .store(in: &cancellables)
    }
    
    func register(nickname: String) async -> Bool {
        await authViewModel.register()
        return authViewModel.currentUser != nil
    }
    
    func logout() {
        authViewModel.logout()
    }
    
    func wipeAllData() {
        authViewModel.wipeAllData()
    }
}
