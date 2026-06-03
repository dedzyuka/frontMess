// ./FrontDip/MessengerApp/Views/Common/SearchView.swift
import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var contactService: ContactService
    @StateObject private var viewModel = SearchViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    TextField("Введите никнейм", text: $viewModel.searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit {
                            viewModel.search()
                        }
                    
                    Button(action: {
                        viewModel.search()
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    Spacer()
                    Text("Пользователи не найдены")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(viewModel.searchResults) { user in
                        SearchResultRow(user: user) {
                            viewModel.sendContactRequest(to: user)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Поиск пользователей")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let user: UserPublicResponse
    let onAdd: () -> Void
    @State private var showingAlert = false
    
    var body: some View {
        NavigationLink(destination: UserProfileView(userId: user.userId)) {
            HStack {
                // ✅ ИСПРАВЛЕНО: используем AvatarView вместо Circle с текстом
                AvatarView(urlString: user.avatarUrl, size: 40)
                
                VStack(alignment: .leading) {
                    Text(user.nickName)
                        .font(.headline)
                    Text("ID: \(user.userId.uuidString.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingAlert = true
                }) {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
            .alert("Добавить в контакты", isPresented: $showingAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Добавить", role: .none) {
                    onAdd()
                }
            } message: {
                Text("Отправить запрос на добавление в контакты пользователю \(user.nickName)?")
            }
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions {
            Button("Добавить") { onAdd() }
        }
    }
}
