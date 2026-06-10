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
    
    // ✅ Исправленный метод регистрации
    func register(nickname: String, email: String, password: String, phone: String = "") async -> Bool {
        return await authViewModel.register(nickname: nickname, email: email, password: password, phone: phone)
    }
    
    // ✅ Добавлен метод логина
    func login(login: String, password: String) async -> Bool {
        return await authViewModel.login(login: login, password: password)
    }
    @MainActor
    func logout() {
        authViewModel.logout()
    }
    @MainActor
    func wipeAllData() {
        authViewModel.wipeAllData()
    }
}
