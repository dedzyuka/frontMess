import SwiftUI

struct PrivacySettingsView: View {
    @StateObject private var viewModel = PrivacySettingsViewModel()
    @Environment(\.dismiss) var dismiss

    // Локальные переменные теперь привязаны к viewModel, а не к @State
    @State private var selectedWriteMe = "everyone"
    @State private var selectedAddToGroups = "everyone"
    @State private var selectedSeePhone = "contacts"
    @State private var selectedSeeLastSeen = "everyone"

    let options = ["everyone", "contacts", "nobody"]

    var body: some View {
        NavigationView {
            Form {
                Picker("Кто может писать мне", selection: $selectedWriteMe) {
                    ForEach(options, id: \.self) { option in
                        Text(option.localizedCapitalized).tag(option)
                    }
                }
                Picker("Кто может добавлять в группы", selection: $selectedAddToGroups) {
                    ForEach(options, id: \.self) { option in
                        Text(option.localizedCapitalized).tag(option)
                    }
                }
                Picker("Кто видит мой телефон", selection: $selectedSeePhone) {
                    ForEach(options, id: \.self) { option in
                        Text(option.localizedCapitalized).tag(option)
                    }
                }
                Picker("Кто видит время последнего посещения", selection: $selectedSeeLastSeen) {
                    ForEach(options, id: \.self) { option in
                        Text(option.localizedCapitalized).tag(option)
                    }
                }
            }
            .navigationTitle("Приватность")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        Task {
                            let success = await viewModel.update(
                                whoCanWriteMe: selectedWriteMe,
                                whoCanAddToGroups: selectedAddToGroups,
                                whoCanSeePhone: selectedSeePhone,
                                whoCanSeeLastSeen: selectedSeeLastSeen
                            )
                            if success {
                                // После успешного сохранения перезагружаем настройки
                                await viewModel.loadSettings()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadSettings()
            }
            .onReceive(viewModel.$settings) { newSettings in
                // Обновляем локальные переменные, когда меняются данные в viewModel
                if let s = newSettings {
                    selectedWriteMe = s.whoCanWriteMe
                    selectedAddToGroups = s.whoCanAddToGroups
                    selectedSeePhone = s.whoCanSeePhone
                    selectedSeeLastSeen = s.whoCanSeeLastSeen
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
}
