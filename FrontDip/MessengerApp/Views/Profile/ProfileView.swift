// ./FrontDip/MessengerApp/Views/Profile/ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showingEditSheet = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let user = viewModel.user {
                    ScrollView {
                        VStack(spacing: 20) {
                            AvatarView(urlString: user.avatarUrl, size: 120)
                                .padding(.top, 30)
                            
                            Text(user.nickName)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            if let firstName = user.firstName, let lastName = user.lastName {
                                Text("\(firstName) \(lastName)")
                                    .font(.subheadline)
                            }
                            
                            if let email = user.email {
                                Label(email, systemImage: "envelope")
                                    .font(.caption)
                            }
                            
                            if let phone = user.phone {
                                Label(phone, systemImage: "phone")
                                    .font(.caption)
                            }
                            
                            if let bio = user.bio, !bio.isEmpty {
                                Text(bio)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            }
                            
                            HStack {
                                Text("Аккаунт создан:")
                                Text(formatDate(user.createdAt ?? Date()))
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Button("Редактировать профиль") {
                                showingEditSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                        .padding()
                    }
                } else {
                    Text("Не удалось загрузить профиль")
                }
            }
            .navigationTitle("Мой профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditProfileView(user: viewModel.user) { updatedUser, avatarData in
                    Task {
                        _ = await viewModel.updateUser(updatedUser: updatedUser, avatarData: avatarData)
                        await MainActor.run { showingEditSheet = false }
                    }
                }
            }
            .onAppear {
                viewModel.loadMyProfile()
            }
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}
