import SwiftUI

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @State private var showMenu = false
    @State private var showCreateChat = false
    @State private var newChatName = ""
    @State private var isCreating = false
    @State private var selectedChat: Chat?
    @State private var showChat = false

    var body: some View {
        ZStack {
            NavigationView {
                mainContent
                    .navigationTitle("Чаты")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                withAnimation(.spring()) { showMenu.toggle() }
                            } label: {
                                Image(systemName: "line.horizontal.3")
                                    .font(.title2)
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showCreateChat = true
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }
                        }
                    }
                    .background(
                        NavigationLink(destination: selectedChat.map { ChatView(chat: $0) }, isActive: $showChat) {
                            EmptyView()
                        }
                    )
            }
            .disabled(showMenu)
            .blur(radius: showMenu ? 5 : 0)
            .onReceive(NotificationCenter.default.publisher(for: .chatCreated)) { notification in
                if let newChat = notification.object as? Chat {
                    viewModel.addChat(newChat)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openChat)) { notification in
                if let chatId = notification.object as? UUID,
                   let chat = viewModel.chats.first(where: { $0.id == chatId }) {
                    selectedChat = chat
                    showChat = true
                }
            }

            SideMenuView(isShowing: $showMenu)
                .environmentObject(viewModel)
        }
        .onAppear {
            Task { await viewModel.loadChats() }
        }
        .alert("Новый чат", isPresented: $showCreateChat) {
            TextField("Название", text: $newChatName)
            Button("Отмена", role: .cancel) {
                newChatName = ""
                isCreating = false
            }
            Button("Создать") {
                isCreating = true
                Task {
                    await createChat()
                    isCreating = false
                    showCreateChat = false
                }
            }
            .disabled(newChatName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
        } message: {
            Text("Введите название группового чата")
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading && viewModel.chats.isEmpty {
            LoadingView()
        } else if viewModel.chats.isEmpty {
            VStack(spacing: 24) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("Нет чатов")
                    .font(.title2)
                Text("Создайте первый чат или присоединитесь по приглашению")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                Button("Создать чат") {
                    showCreateChat = true
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            List(viewModel.chats) { chat in
                NavigationLink(destination: ChatView(chat: chat)) {
                    ChatRow(chat: chat)
                }
            }
            .listStyle(PlainListStyle())
            .refreshable {
                await viewModel.loadChats()
            }
        }
    }

    private func createChat() async {
        let success = await viewModel.createChat(name: newChatName)
        if success {
            newChatName = ""
        }
    }
}

struct ChatRow: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text((chat.name?.prefix(1).uppercased() ?? "?"))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.name ?? "Чат")
                    .font(.headline)
                Text(chat.lastMessage ?? "Нет сообщений")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(formatDate(chat.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
