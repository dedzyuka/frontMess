// ./FrontDip/MessengerApp/Views/Profile/PrivacySettingsView.swift
import SwiftUI

struct PrivacySettingsView: View {
    @StateObject private var viewModel = PrivacySettingsViewModel()
    @Environment(\.dismiss) var dismiss
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
                                dismiss()
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadSettings()
                if let settings = viewModel.settings {
                    selectedWriteMe = settings.whoCanWriteMe
                    selectedAddToGroups = settings.whoCanAddToGroups
                    selectedSeePhone = settings.whoCanSeePhone
                    selectedSeeLastSeen = settings.whoCanSeeLastSeen
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
