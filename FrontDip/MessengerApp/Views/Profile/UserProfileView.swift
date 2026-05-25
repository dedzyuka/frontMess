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
                        .padding(.top, 20)
                    
                    Text(viewModel.user?.nickName ?? "Загрузка...")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let isOnline = viewModel.user?.isOnline {
                        Text(isOnline ? "Онлайн" : "Был(а) недавно")
                            .font(.subheadline)
                            .foregroundColor(isOnline ? .green : .secondary)
                    }
                    
                    if let bio = viewModel.user?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 12) {
                        if viewModel.isContact {
                            Button("Написать") {
                                viewModel.startPrivateChat()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Удалить из контактов", role: .destructive) {
                                viewModel.removeFromContacts()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Добавить в контакты") {
                                viewModel.addToContacts()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Написать") {
                                viewModel.startPrivateChat()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
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
}
