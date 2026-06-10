import SwiftUI
import CallKit
import AVFoundation

struct ChatView: View {
    let chat: Chat
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.presentationMode) var presentationMode

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

    @State private var replyingToMessage: Message?
    @State private var showForwardChatSelection = false
    @State private var forwardMessage: Message?

    @State private var showCallScreen = false

    @State private var sendButtonMode: SendButtonMode = .audio
    @AppStorage("lastSendButtonMode") private var lastSendButtonModeRaw: String = "audio"

    @State private var showingVoiceRecorder = false
    @State private var showingVideoRecorder = false
    @State private var scrollProxy: ScrollViewProxy?

    private var canSendMessage: Bool {
        if chat.isChannel {
            return viewModel.myRole == "owner" || viewModel.myRole == "admin"
        }
        return true
    }

    private var canSend: Bool {
        (
            !viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            selectedImage != nil ||
            selectedVideoURL != nil ||
            selectedDocumentURL != nil ||
            viewModel.pendingForward?.attachmentId != nil
        ) && !isSending
    }

    private var shouldShowSend: Bool {
        !viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedImage != nil ||
        selectedVideoURL != nil ||
        selectedDocumentURL != nil ||
        viewModel.pendingForward != nil
    }

    enum SendButtonMode: String {
        case video
        case audio
    }

    private var recorderButtonIcon: String {
        sendButtonMode == .audio ? "mic.circle.fill" : "video.circle.fill"
    }

    private var recorderToggleIcon: String {
        sendButtonMode == .audio ? "video.fill" : "mic.fill"
    }

    private var recorderToggleTitle: String {
        sendButtonMode == .audio ? "Видео" : "Аудио"
    }

    init(chat: Chat) {
        self.chat = chat
        _viewModel = StateObject(wrappedValue: ChatViewModel(chat: chat))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            messagesListView

            if selectedImage != nil || selectedVideoURL != nil || selectedDocumentURL != nil {
                AttachmentPreviewBar(
                    type: previewTypeForSelected(),
                    onCancel: clearSelectedAttachments
                )
            } else if let pending = viewModel.pendingForward {
                AttachmentPreviewBar(
                    type: .forward(
                        content: pending.originalContent,
                        fromNickname: pending.forwardedFromNickname,
                        attachmentId: pending.attachmentId
                    ),
                    onCancel: {
                        viewModel.pendingForward = nil
                    }
                )
            }

            replyPreviewBar

            if canSendMessage {
                inputAreaView
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCallScreen)) { _ in
            showCallScreen = true
        }
        .fullScreenCover(isPresented: $showCallScreen) {
            if let call = CallService.shared.activeCall {
                ActiveCallView(call: call)
            } else {
                Text("Нет активного звонка")
            }
        }
        .navigationBarHidden(true)
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Вложение"),
                buttons: [
                    .default(Text("Фото или видео")) {
                        showingMediaPicker = true
                    },
                    .default(Text("Документ")) {
                        showingDocumentPicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingMediaPicker) {
            MediaPicker(
                selectedImage: $selectedImage,
                selectedVideoURL: $selectedVideoURL
            )
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(selectedURL: $selectedDocumentURL)
        }
        .sheet(isPresented: $showForwardChatSelection) {
            ChatSelectionForForwardView { selectedChat in
                forwardMessageToChat(forwardMessage, selectedChat)
                forwardMessage = nil
            }
        }
        .fullScreenCover(isPresented: $showingVoiceRecorder) {
            VoiceRecorderView(onComplete: { url, duration, waveform in
                Task {
                    await sendVoiceMessage(url: url, duration: duration, waveform: waveform)
                }
            })
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingVideoRecorder) {
            VideoRecorderView { url in
                Task {
                    await sendCircularVideo(url: url)
                }
            }
            .ignoresSafeArea()
        }
        .alert("Редактировать сообщение", isPresented: $showEditAlert, actions: {
            TextField("Текст", text: $editText)

            Button("Отмена", role: .cancel) {}

            Button("Сохранить") {
                if let message = selectedMessage {
                    Task {
                        _ = await viewModel.editMessage(message, newContent: editText)
                    }
                }
            }
        }, message: {
            Text("Измените текст сообщения")
        })
        .alert("Удалить сообщение?", isPresented: $showDeleteConfirmation, actions: {
            Button("Отмена", role: .cancel) {}

            Button("Удалить", role: .destructive) {
                if let message = selectedMessage {
                    Task {
                        _ = await viewModel.deleteMessage(message)
                    }
                }
            }
        }, message: {
            Text("Это действие нельзя отменить.")
        })
        .overlay {
            if isSending {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                    )
            }
        }
        .onAppear {
            NotificationCenter.default.post(name: .chatOpened, object: chat.id)

            Task {
                await viewModel.refreshOtherUserStatus()
            }

            if let pending = PendingForwardManager.shared.consumePendingForward(for: chat.id) {
                viewModel.pendingForward = ChatViewModel.PendingForward(
                    originalContent: pending.content,
                    forwardedFromUserId: pending.fromUserId,
                    forwardedFromNickname: pending.fromNickname,
                    attachmentId: pending.attachmentId
                )
                viewModel.newMessageText = pending.content
            }

            if let pendingId = AppState.shared.pendingScrollToMessageId {
                AppState.shared.pendingScrollToMessageId = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.scrollToMessage(messageId: pendingId) {
                        DispatchQueue.main.async {
                            withAnimation {
                                self.scrollProxy?.scrollTo(pendingId, anchor: .center)
                            }
                            viewModel.highlightMessage(pendingId)
                        }
                    }
                }
            }

            sendButtonMode = SendButtonMode(rawValue: lastSendButtonModeRaw) ?? .audio
        }
        .onReceive(AppState.shared.$pendingScrollToMessageId) { newId in
            guard let id = newId else { return }
            AppState.shared.pendingScrollToMessageId = nil

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                viewModel.scrollToMessage(messageId: id) {
                    DispatchQueue.main.async {
                        withAnimation {
                            scrollProxy?.scrollTo(id, anchor: .center)
                        }
                        viewModel.highlightMessage(id)
                    }
                }
            }
        }
        .onDisappear {
            viewModel.clearPendingForward()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(spacing: 12) {
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }

            if chat.isPrivate, let otherUser = viewModel.otherUser {
                Button {
                    let profileView = UserProfileView(userId: otherUser.userId)
                    let hosting = UIHostingController(rootView: profileView)
                    UIApplication.shared.windows.first?.rootViewController?.present(
                        hosting,
                        animated: true,
                        completion: nil
                    )
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
                            Text("кто-то печатает...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Button {
                Task {
                    do {
                        _ = try await CallService.shared.startCall(chatId: chat.id, type: "video")
                    } catch {
                        print("Start call error: \(error)")
                        NotificationService.shared.showError(error.localizedDescription)
                    }
                }
            } label: {
                Image(systemName: "video.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            NavigationLink(destination: ChatSidebarView(chat: chat, chatViewModel: viewModel)) {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        messageView(for: message, proxy: proxy)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 12)
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onDisappear {
                scrollProxy = nil
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    @ViewBuilder
    private func messageView(for message: Message, proxy: ScrollViewProxy) -> some View {
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
            },
            onReply: {
                replyingToMessage = message
            },
            onReplyTap: { replyId in
                viewModel.scrollToMessage(messageId: replyId) {
                    withAnimation {
                        proxy.scrollTo(replyId, anchor: .center)
                    }
                    viewModel.highlightMessage(replyId)
                }
            },
            onForward: {
                forwardMessage = message
                showForwardChatSelection = true
            },
            isPrivateChat: chat.isPrivate
        )
        .id(message.messageId)
        .background(
            viewModel.highlightMessageId == message.messageId
            ? Color.yellow.opacity(0.3)
            : Color.clear
        )
    }

    private var replyPreviewBar: some View {
        Group {
            if let reply = replyingToMessage {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(reply.content ?? (reply.attachments != nil ? "Вложение" : "Сообщение"))
                        .font(.caption)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Button {
                        replyingToMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.clear)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
    }

    private var inputAreaView: some View {
        HStack(spacing: 12) {
            Button {
                showingActionSheet = true
            } label: {
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
                ProgressView()
                    .frame(width: 32, height: 32)
            } else if shouldShowSend {
                Button {
                    sendMessageWithAttachment(replyToId: replyingToMessage?.messageId)
                    replyingToMessage = nil
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSend ? .blue : .gray)
                }
                .disabled(!canSend)
            } else {
                HStack(spacing: 8) {
                    Button {
                        toggleRecorderMode()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: recorderToggleIcon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(recorderToggleTitle)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    Button {
                        openCurrentRecorder()
                    } label: {
                        Image(systemName: recorderButtonIcon)
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func toggleRecorderMode() {
        sendButtonMode = sendButtonMode == .audio ? .video : .audio
        lastSendButtonModeRaw = sendButtonMode.rawValue
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func openCurrentRecorder() {
        switch sendButtonMode {
        case .audio:
            showingVoiceRecorder = true
        case .video:
            showingVideoRecorder = true
        }
    }

    private func sendMessageWithAttachment(replyToId: Int64? = nil) {
        Task {
            isSending = true
            isUploading = true

            var attachmentId: UUID? = nil
            var storagePath: String? = nil
            var fileName: String? = nil
            var fileSize: Int? = nil
            var mimeType: String? = nil

            if let pending = viewModel.pendingForward, let pendingAttachId = pending.attachmentId {
                attachmentId = pendingAttachId
            } else if let image = selectedImage {
                do {
                    let result = try await AttachmentUploader.shared.uploadImage(image)
                    attachmentId = result.attachmentId
                    storagePath = result.storagePath
                    fileName = "image.jpg"

                    if let data = image.jpegData(compressionQuality: 0.8) {
                        fileSize = data.count
                    }

                    mimeType = "image/jpeg"
                } catch {
                    await MainActor.run {
                        isSending = false
                        isUploading = false
                    }
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
                    await MainActor.run {
                        isSending = false
                        isUploading = false
                    }
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
                    await MainActor.run {
                        isSending = false
                        isUploading = false
                    }
                    return
                }
            }

            let contentToSend = viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
            let forwardUserId = viewModel.pendingForward?.forwardedFromUserId
            let forwardNickname = viewModel.pendingForward?.forwardedFromNickname

            let success = await viewModel.sendMessage(
                attachmentId: attachmentId,
                storagePath: storagePath,
                fileName: fileName,
                fileSize: fileSize,
                mimeType: mimeType,
                replyToId: replyToId,
                forwardedFromUserId: forwardUserId,
                forwardedFromNickname: forwardNickname,
                customContent: contentToSend
            )

            await MainActor.run {
                viewModel.pendingForward = nil
                isSending = false
                isUploading = false
                selectedImage = nil
                selectedVideoURL = nil
                selectedDocumentURL = nil

                if success {
                    viewModel.newMessageText = ""
                } else {
                    NotificationService.shared.showError("Не удалось отправить сообщение")
                }
            }
        }
    }

    private func sendVoiceMessage(url: URL, duration: TimeInterval, waveform: String?) async {
        isSending = true
        isUploading = true

        defer {
            isSending = false
            isUploading = false
        }

        do {
            let result = try await AttachmentUploader.shared.uploadFile(url: url, mimeType: "audio/m4a")

            let success = await viewModel.sendMessage(
                attachmentId: result.attachmentId,
                storagePath: result.storagePath,
                fileName: url.lastPathComponent,
                fileSize: nil,
                mimeType: "audio/m4a",
                replyToId: replyingToMessage?.messageId,
                forwardedFromUserId: nil,
                forwardedFromNickname: nil,
                customContent: nil
            )

            if success {
                replyingToMessage = nil
            }
        } catch {
            await MainActor.run {
                NotificationService.shared.showError(error.localizedDescription)
            }
        }
    }

    private func sendCircularVideo(url: URL) async {
        print("sendCircularVideo called with url: \(url)")
        isSending = true
        isUploading = true

        defer {
            isSending = false
            isUploading = false
        }

        let asset = AVAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        print("Video duration: \(duration)")

        do {
            print("Uploading video to server...")
            let result = try await AttachmentUploader.shared.uploadFile(url: url)
            print("Upload success, attachmentId: \(result.attachmentId)")

            let success = await viewModel.sendMessage(
                attachmentId: result.attachmentId,
                storagePath: result.storagePath,
                fileName: url.lastPathComponent,
                fileSize: nil,
                mimeType: "video/mp4",
                replyToId: replyingToMessage?.messageId,
                isCircular: true
            )

            print("sendMessage success: \(success)")

            if success {
                replyingToMessage = nil
            }
        } catch {
            await MainActor.run {
                NotificationService.shared.showError(error.localizedDescription)
            }
            print("Video upload error: \(error)")
        }
    }

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

    private func previewTypeForSelected() -> AttachmentPreviewBar.AttachmentType {
        if let image = selectedImage {
            return .image(image)
        } else if let videoURL = selectedVideoURL {
            return .video(videoURL)
        } else if let docURL = selectedDocumentURL {
            return .document(docURL)
        }

        fatalError("No attachment selected")
    }

    private func clearSelectedAttachments() {
        selectedImage = nil
        selectedVideoURL = nil
        selectedDocumentURL = nil
    }

    private func forwardMessageToChat(_ message: Message?, _ targetChat: Chat) {
        guard let message = message else { return }

        let senderNick = viewModel.getNicknameForForward(for: message.senderId)

        if targetChat.id == chat.id {
            viewModel.newMessageText = message.content ?? ""
            viewModel.pendingForward = nil
        } else {
            PendingForwardManager.shared.setPendingForward(
                chatId: targetChat.id,
                content: message.content ?? "",
                fromUserId: message.senderId,
                fromNickname: senderNick,
                attachmentId: message.attachments?.first?.attachmentId
            )

            presentationMode.wrappedValue.dismiss()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .openChat, object: targetChat)
            }
        }
    }
}
