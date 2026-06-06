import SwiftUI

struct JoinChatView: View {
    @Environment(\.dismiss) var dismiss
    @State private var inviteKey = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Пригласительная ссылка или ключ")) {
                    TextField("Вставьте ссылку или ключ", text: $inviteKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Section {
                    Button("Вступить") {
                        Task { await join() }
                    }
                    .disabled(inviteKey.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .navigationTitle("Присоединиться")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .overlay { if isLoading { ProgressView() } }
            .alert("Ошибка", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
    
    private func join() async {
        isLoading = true
        defer { isLoading = false }
        
        let key = inviteKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = key.split(separator: "/").last.map(String.init) ?? key
        do {
            try await ChatService.shared.joinChat(inviteToken: token)
            NotificationCenter.default.post(name: .chatCreated, object: nil) // обновить список чатов
            dismiss()
        } catch {
            errorMessage = "Не удалось вступить: \(error.localizedDescription)"
        }
    }
}
