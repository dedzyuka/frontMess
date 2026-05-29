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
                        Label("\(chat.membersCount) участников", systemImage: "person.2")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(chat.createdAt))
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
                                ForEach(viewModel.members, id: \.userId) { member in
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
    let member: ChatMemberItem
    
    var body: some View {
        NavigationLink(destination: UserProfileView(userId: member.userId)) {
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(member.nickName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading) {
                    Text(member.nickName)
                        .font(.headline)
                    HStack {
                        Circle()
                            .fill(member.isOnline ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(member.isOnline ? "онлайн" : "офлайн")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}
