import SwiftUI

struct EditChatView: View {
    let chat: Chat
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: EditChatViewModel
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
    init(chat: Chat) {
        self.chat = chat
        _viewModel = StateObject(wrappedValue: EditChatViewModel(chat: chat))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        AvatarView(urlString: viewModel.avatarUrl, size: 60)
                        Button("Изменить") { showingImagePicker = true }
                    }
                }
                Section {
                    TextField("Название", text: $viewModel.name)
                    TextField("Описание", text: $viewModel.description)
                }
                Section {
                    Toggle("Публичный чат", isOn: $viewModel.isPublic)
                    if viewModel.isPublic {
                        HStack {
                            Text("Макс. участников:")
                            TextField("от 2 до 500", value: $viewModel.maxMembers, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                            Stepper("", value: $viewModel.maxMembers, in: 2...500)
                                .labelsHidden()
                        }
                    }
                }
            }
            .navigationTitle("Редактировать чат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        Task {
                            await viewModel.save(avatarData: selectedImage?.jpegData(compressionQuality: 0.8))
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .overlay { if viewModel.isLoading { ProgressView() } }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: { Text(viewModel.errorMessage ?? "") }
        }
    }
}

import SwiftUI

@MainActor
class EditChatViewModel: ObservableObject {
    @Published var name: String
    @Published var description: String
    @Published var avatarUrl: String?
    @Published var isPublic: Bool
    @Published var maxMembers: Int
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let chat: Chat
    
    init(chat: Chat) {
        self.chat = chat
        self.name = chat.name ?? ""
        self.description = chat.description ?? ""
        self.avatarUrl = chat.avatarUrl
        self.isPublic = chat.isPublic
        self.maxMembers = chat.maxMembers
    }
    
    func save(avatarData: Data?) async {
        isLoading = true
        defer { isLoading = false }
        
        var newAvatarUrl = avatarUrl
        if let data = avatarData {
            do {
                let (_, storagePath) = try await AttachmentUploader.shared.uploadImage(UIImage(data: data)!)
                newAvatarUrl = storagePath
                print("✅ Avatar uploaded: \(storagePath)")
            } catch {
                errorMessage = "Ошибка загрузки аватара: \(error.localizedDescription)"
                return
            }
        }
        
        do {
            let updated = try await ChatService.shared.updateChat(
                chatId: chat.id,
                name: name.isEmpty ? nil : name,
                description: description.isEmpty ? nil : description,
                avatarUrl: newAvatarUrl,
                isPublic: isPublic,
                maxMembers: maxMembers
            )
            await MainActor.run {
                self.avatarUrl = updated.avatarUrl
                self.objectWillChange.send()
                NotificationCenter.default.post(name: .chatUpdated, object: updated)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Ошибка сохранения: \(error.localizedDescription)"
            }
        }
    }
}

extension Notification.Name {
    static let chatUpdated = Notification.Name("chatUpdated")
}
