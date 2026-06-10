import Foundation

@MainActor
final class TokenRefreshManager {
    static let shared = TokenRefreshManager()

    private var refreshTask: Task<Void, Never>?
    private let refreshSkew: TimeInterval = 60
    private var isStarting = false

    private init() {}

    func start() {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        scheduleNextRefresh()
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        print("⏱ Token refresh timer stopped")
    }

    func restart() {
        stop()
        start()
    }

    private func scheduleNextRefresh() {
        refreshTask?.cancel()

        guard let expiresAt = TokenManager.shared.accessTokenExpiresAt else {
            print("⏱ No accessTokenExpiresAt, timer not scheduled")
            return
        }

        guard TokenManager.shared.refreshToken != nil else {
            print("⏱ No refresh token, timer not scheduled")
            return
        }

        let delay = max(5, expiresAt.timeIntervalSinceNow - refreshSkew)
        print("⏱ Next token refresh scheduled in \(delay) sec")

        refreshTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }

                let success = await AuthViewModel().refreshAccessTokenByTimer()
                guard success, !Task.isCancelled else { return }

                self?.scheduleNextRefresh()
            } catch {
                print("⏱ Token refresh task cancelled or failed: \(error.localizedDescription)")
            }
        }
    }
}
