//
//  ChatSelectionForForwardView.swift
//  MessengerApp
//

import SwiftUI

struct ChatSelectionForForwardView: View {
    let onSelect: (Chat) -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ChatListViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.chats) { chat in
                Button {
                    onSelect(chat)
                    dismiss()
                } label: {
                    ChatRow(chat: chat, currentUserId: AppState.shared.currentUser?.userId)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Выберите чат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
        .onAppear {
            Task { await viewModel.loadChats() }
        }
    }
}
