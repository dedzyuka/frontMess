// ./FrontDip/MessengerApp/Views/Profile/SessionsView.swift
import SwiftUI

struct SessionsView: View {
    @StateObject private var viewModel = SessionsViewModel()
    @State private var showingLogoutAllAlert = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.sessions, id: \.sessionId) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.isCurrent ? "Текущая сессия" : (session.deviceInfo ?? "Неизвестное устройство"))
                                .font(.headline)
                            Spacer()
                            if !session.isCurrent {
                                Button("Завершить") {
                                    Task {
                                        _ = await viewModel.revokeSession(sessionId: session.sessionId)
                                    }
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.red)
                            }
                        }
                        if let userAgent = session.userAgent {
                            Text(userAgent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let ip = session.ipAddress {
                            Text("IP: \(ip)")
                                .font(.caption2)
                        }
                        if let lastSeen = session.lastSeenAt {
                            Text("Активна: \(formatDate(lastSeen))")
                                .font(.caption2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Активные сессии")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Завершить все") {
                        showingLogoutAllAlert = true
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .alert("Завершить все сессии кроме текущей?", isPresented: $showingLogoutAllAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Завершить", role: .destructive) {
                    Task {
                        _ = await viewModel.logoutAllOther()
                    }
                }
            }
            .onAppear {
                viewModel.loadSessions()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
