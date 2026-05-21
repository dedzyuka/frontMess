import SwiftUI

struct ChatSidebarView: View {
    let chat: Chat
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ChatSidebarViewModel
    @State private var showingAddContact = false
    
    init(chat: Chat) {
        self.chat = chat
        _viewModel = StateObject(wrappedValue: ChatSidebarViewModel(chat: chat))
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                // Заголовок чата
                VStack(alignment: .leading, spacing: 12) {
                    Text(chat.name ?? "Чат")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    
                    HStack {
                        Label("\(chat.members_count) участников", systemImage: "person.2")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(chat.created_at))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                // Участники чата
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Участники")
                            .font(.headline)
                        Spacer()
                        Button(action: { showingAddContact = true }) {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.members.isEmpty {
                        Text("Нет участников")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.members, id: \.user_id) { member in
                                    ChatMemberRow(member: member)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .onAppear {
            viewModel.loadMembers()
        }
        .sheet(isPresented: $showingAddContact) {
            AddContactToChatView(chat: chat, viewModel: viewModel)
                .environmentObject(ContactService.shared)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}

struct ChatMemberRow: View {
    let member: ChatMemberItem   // используем ChatMemberItem, а не ChatMemberDetailed
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(member.nickname.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading) {
                Text(member.nickname)
                    .font(.headline)
                HStack {
                    Text("ID: \(member.user_id.uuidString.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Присоединился: \(formatDate(member.joined_at))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}
