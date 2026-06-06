//
//  ChatView.swift
//  MessengerApp
//

import SwiftUI

struct ChatView: View {
    let chat: Chat
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Вложения и остальные состояния...
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var selectedDocumentURL: URL?
    @State private var showingActionSheet = false
    @State private var showingMediaPicker = false
    @State private var showingDocumentPicker = false
    @State private var isUploading = false
    @State private var isSending = false
    
    @State private var selectedMessage: Message?
    @State private var editText = ""
    @State private var showEditAlert = false
    @State private var showDeleteConfirmation = false
    
    @State private var typingTimer: Timer?
    @State private var isTyping = false
    
    private var canSendMessage: Bool {
        if chat.isChannel {
            return viewModel.myRole == "owner" || viewModel.myRole == "admin"
        }
        return true
    }
    
    init(chat: Chat) {
        self.chat = chat
        _viewModel = StateObject(wrappedValue: ChatViewModel(chat: chat))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок (шапка) с аватаркой
            HStack(spacing: 12) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .frame(width: 44, height: 44)
                
                if chat.isPrivate, let otherUser = viewModel.otherUser {
                    Button {
                        let profileView = UserProfileView(userId: otherUser.userId)
                        let hosting = UIHostingController(rootView: profileView)
                        UIApplication.shared.windows.first?.rootViewController?.present(hosting, animated: true)
                    } label: {
                        HStack(spacing: 8) {
                            AvatarView(urlString: otherUser.avatarUrl, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(otherUser.nickName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                if viewModel.isSomeoneTyping {
                                    Text("печатает...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(viewModel.isOtherUserOnline ? Color.green : Color.gray)
                                            .frame(width: 8, height: 8)
                                        Text(viewModel.isOtherUserOnline ? "онлайн" : "офлайн")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Группа или канал – показываем аватарку чата и название
                    HStack(spacing: 8) {
                        if let avatarUrl = chat.avatarUrl, !avatarUrl.isEmpty {
                            AvatarView(urlString: avatarUrl, size: 40)
                        } else {
                            Circle()
                                .fill(chat.isGroup ? Color.blue.opacity(0.2) : Color.purple.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: chat.isGroup ? "person.2.fill" : "megaphone.fill")
                                        .foregroundColor(chat.isGroup ? .blue : .purple)
                                )
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.chatTitle)
                                .font(.headline)
                                .lineLimit(1)
                            if viewModel.isSomeoneTyping {
                                Text("печатает...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
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
            
            // Список сообщений (остаётся без изменений)
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
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            
            // Поле ввода (остаётся без изменений)
            if canSendMessage {
                HStack(spacing: 12) {
                    Button { showingActionSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                    
                    TextField("Сообщение", text: $viewModel.newMessageText)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(25)
                        .disabled(isSending)
                        .onChange(of: viewModel.newMessageText) { newValue in
                            handleTyping(newValue)
                        }
                    
                    if isUploading || isSending {
                        ProgressView().frame(width: 32, height: 32)
                    } else {
                        Button {
                            sendMessageWithAttachment()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor((viewModel.newMessageText.isEmpty && selectedImage == nil && selectedVideoURL == nil && selectedDocumentURL == nil) ? .gray : .blue)
                        }
                        .disabled((viewModel.newMessageText.isEmpty && selectedImage == nil && selectedVideoURL == nil && selectedDocumentURL == nil) || isSending)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .navigationBarHidden(true)
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(title: Text("Вложение"), buttons: [
                .default(Text("Фото или видео")) { showingMediaPicker = true },
                .default(Text("Документ")) { showingDocumentPicker = true },
                .cancel()
            ])
        }
        .sheet(isPresented: $showingMediaPicker) {
            MediaPicker(selectedImage: $selectedImage, selectedVideoURL: $selectedVideoURL)
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(selectedURL: $selectedDocumentURL)
        }
        .alert("Редактировать сообщение", isPresented: $showEditAlert, actions: {
            TextField("Новый текст", text: $editText)
            Button("Отмена", role: .cancel) { }
            Button("Сохранить") {
                if let message = selectedMessage {
                    Task { _ = await viewModel.editMessage(message, newContent: editText) }
                }
            }
        })
        .alert("Удалить сообщение", isPresented: $showDeleteConfirmation) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                if let message = selectedMessage {
                    Task { _ = await viewModel.deleteMessage(message) }
                }
            }
        } message: {
            Text("Это сообщение будет удалено для всех участников чата. Отменить действие будет невозможно.")
        }
        .overlay(
            Group {
                if isSending {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(ProgressView().scaleEffect(1.5))
                }
            }
        )
        .onAppear {
            NotificationCenter.default.post(name: .chatOpened, object: chat.id)
            Task {
                await viewModel.refreshOtherUserStatus()
            }
        }
    }
    
    // MARK: - Отправка с вложением (остаётся без изменений)
    private func sendMessageWithAttachment() {
        Task {
            isSending = true
            isUploading = true
            var attachmentId: UUID? = nil
            var storagePath: String? = nil
            var fileName: String? = nil
            var fileSize: Int? = nil
            var mimeType: String? = nil
            
            if let image = selectedImage {
                do {
                    let result = try await AttachmentUploader.shared.uploadImage(image)
                    attachmentId = result.attachmentId
                    storagePath = result.storagePath
                    fileName = "image.jpg"
                    if let data = image.jpegData(compressionQuality: 0.8) { fileSize = data.count }
                    mimeType = "image/jpeg"
                } catch {
                    print("Upload failed: \(error)")
                    await MainActor.run { isSending = false; isUploading = false }
                    return
                }
            } else if let videoURL = selectedVideoURL {
                do {
                    let result = try await AttachmentUploader.shared.uploadFile(url: videoURL)
                    attachmentId = result.attachmentId
                    storagePath = result.storagePath
                    fileName = videoURL.lastPathComponent
                    let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
                    fileSize = attributes[.size] as? Int
                    mimeType = "video/mp4"
                } catch {
                    print("Upload failed: \(error)")
                    await MainActor.run { isSending = false; isUploading = false }
                    return
                }
            } else if let documentURL = selectedDocumentURL {
                do {
                    let result = try await AttachmentUploader.shared.uploadFile(url: documentURL)
                    attachmentId = result.attachmentId
                    storagePath = result.storagePath
                    fileName = documentURL.lastPathComponent
                    let attributes = try FileManager.default.attributesOfItem(atPath: documentURL.path)
                    fileSize = attributes[.size] as? Int
                    mimeType = AttachmentUploader.shared.guessMimeType(from: fileName ?? "")
                } catch {
                    print("Upload failed: \(error)")
                    await MainActor.run { isSending = false; isUploading = false }
                    return
                }
            }
            
            let success = await viewModel.sendMessage(
                attachmentId: attachmentId,
                storagePath: storagePath,
                fileName: fileName,
                fileSize: fileSize,
                mimeType: mimeType
            )
            
            await MainActor.run {
                isSending = false
                isUploading = false
                selectedImage = nil
                selectedVideoURL = nil
                selectedDocumentURL = nil
                if !success {
                    NotificationService.shared.showError("Не удалось отправить сообщение")
                }
            }
        }
    }
    
    // MARK: - Typing indicator
    private func handleTyping(_ text: String) {
        if !text.isEmpty && !isTyping && canSendMessage {
            isTyping = true
            WebSocketService.shared.sendTyping(chatId: chat.id, isTyping: true)
        }
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            if self.isTyping {
                self.isTyping = false
                WebSocketService.shared.sendTyping(chatId: self.chat.id, isTyping: false)
            }
        }
    }
}
