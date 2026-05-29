//
//  ChatView.swift
//  FrontDip
//
//

import SwiftUI

struct ChatView: View {
    let chat: Chat
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Для вложений
    @State private var selectedImage: UIImage?
    @State private var selectedDocumentURL: URL?
    @State private var showingActionSheet = false
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var isUploading = false
    
    // Для редактирования/удаления/реакций
    @State private var selectedMessage: Message?
    @State private var editText = ""
    @State private var showEditAlert = false
    @State private var showDeleteConfirmation = false
    @State private var showReactionPicker = false
    @State private var reactionEmoji = ""
    
    init(chat: Chat) {
        self.chat = chat
        _viewModel = StateObject(wrappedValue: ChatViewModel(chat: chat))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Кастомный заголовок
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .frame(width: 44, height: 44)
                
                Spacer()
                
                Text(viewModel.chatTitle)
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: ChatSidebarView(chat: chat)) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            // Список сообщений
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isCurrentUser: viewModel.isCurrentUser(senderId: message.senderId),
                                senderUser: viewModel.getUser(for: message.senderId),
                                viewModel: viewModel,
                                onEdit: {
                                    selectedMessage = message
                                    editText = message.content ?? ""
                                    showEditAlert = true
                                },
                                onDelete: {
                                    selectedMessage = message
                                    showDeleteConfirmation = true
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            
            // Поле ввода с кнопкой вложения
            HStack(spacing: 12) {
                Button(action: { showingActionSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                
                TextField("Сообщение", text: $viewModel.newMessageText)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(25)
                
                if isUploading {
                    ProgressView()
                        .frame(width: 32, height: 32)
                } else {
                    Button {
                        sendMessageWithAttachment()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(viewModel.newMessageText.isEmpty && selectedImage == nil && selectedDocumentURL == nil ? .gray : .blue)
                    }
                    .disabled(viewModel.newMessageText.isEmpty && selectedImage == nil && selectedDocumentURL == nil)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationBarHidden(true)
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(title: Text("Вложение"), buttons: [
                .default(Text("Фото или видео")) { showingImagePicker = true },
                .default(Text("Документ")) { showingDocumentPicker = true },
                .cancel()
            ])
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(selectedURL: $selectedDocumentURL)
        }
        .alert("Редактировать сообщение", isPresented: $showEditAlert, actions: {
            TextField("Новый текст", text: $editText)
            Button("Отмена", role: .cancel) { }
            Button("Сохранить") {
                if let message = selectedMessage {
                    Task {
                        _ = await viewModel.editMessage(message, newContent: editText)
                    }
                }
            }
        })
        .alert("Удалить сообщение", isPresented: $showDeleteConfirmation) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                if let message = selectedMessage {
                    Task {
                        _ = await viewModel.deleteMessage(message)
                    }
                }
            }
        } message: {
            Text("Это сообщение будет удалено для всех участников чата. Отменить действие будет невозможно.")
        }
    }
    
    private func sendMessageWithAttachment() {
        Task {
            isUploading = true
            var attachmentId: UUID? = nil
            if let image = selectedImage {
                attachmentId = try? await AttachmentUploader.shared.uploadImage(image)
                await MainActor.run { selectedImage = nil }
            } else if let url = selectedDocumentURL {
                attachmentId = try? await AttachmentUploader.shared.uploadFile(url: url)
                await MainActor.run { selectedDocumentURL = nil }
            }
            await MainActor.run {
                viewModel.sendMessage(attachmentId: attachmentId)
                isUploading = false
            }
        }
    }
}
