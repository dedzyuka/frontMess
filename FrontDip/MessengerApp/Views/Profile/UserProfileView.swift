// ./FrontDip/MessengerApp/Views/Profile/UserProfileView.swift

import SwiftUI

struct UserProfileView: View {
    let userId: UUID
    @StateObject private var viewModel: UserProfileViewModel
    @Environment(\.dismiss) var dismiss
    
    init(userId: UUID) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(userId: userId))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    AvatarView(urlString: viewModel.user?.avatarUrl, size: 100)
                        .id(viewModel.user?.avatarUrl)
                        .padding(.top, 20)
                    
                    Text(viewModel.user?.nickName ?? "Загрузка...")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let isOnline = viewModel.user?.isOnline {
                        Text(isOnline ? "Онлайн" : "Был(а) недавно")
                            .font(.subheadline)
                            .foregroundColor(isOnline ? .green : .secondary)
                    }
                    
                    if let lastSeen = viewModel.user?.lastSeen {
                        Text("Последний раз: \(formatRelativeDate(lastSeen))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let bio = viewModel.user?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // MARK: - Кнопки действий в зависимости от contactStatus
                    VStack(spacing: 12) {
                        if viewModel.contactStatus == "accepted" {
                            // Уже контакт
                            Button("Написать") {
                                viewModel.startPrivateChat()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            
                            Button("Удалить из контактов", role: .destructive) {
                                viewModel.removeFromContacts()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            
                        } else if viewModel.contactStatus == "pending" {
                            // Исходящий запрос (ожидаем подтверждения)
                            Text("Запрос отправлен")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            
                            Button("Отменить запрос", role: .destructive) {
                                viewModel.cancelOutgoingRequest()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            
                        } else if viewModel.contactStatus == "incoming_pending" {
                            // Входящий запрос (кто-то добавил меня)
                            Text("Запрос на добавление")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            HStack(spacing: 20) {
                                Button("Принять") {
                                    viewModel.acceptIncomingRequest()
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button("Отклонить", role: .destructive) {
                                    viewModel.declineIncomingRequest()
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(maxWidth: .infinity)
                            
                        } else {
                            // Нет контакта
                            Button("Добавить в контакты") {
                                viewModel.addToContacts()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            
                            Button("Написать") {
                                viewModel.startPrivateChat()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer(minLength: 40)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .onAppear {
                viewModel.loadUser()
            }
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
