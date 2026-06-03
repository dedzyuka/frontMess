// ./FrontDip/MessengerApp/Views/Profile/EditProfileView.swift
import SwiftUI

struct EditProfileView: View {
    let user: User?
    let onSave: (User, Data?) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var nickName: String
    @State private var firstName: String
    @State private var lastName: String
    @State private var middleName: String
    @State private var email: String
    @State private var phone: String
    @State private var bio: String
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    
    init(user: User?, onSave: @escaping (User, Data?) -> Void) {
        self.user = user
        self.onSave = onSave
        _nickName = State(initialValue: user?.nickName ?? "")
        _firstName = State(initialValue: user?.firstName ?? "")
        _lastName = State(initialValue: user?.lastName ?? "")
        _middleName = State(initialValue: user?.middleName ?? "")
        _email = State(initialValue: user?.email ?? "")
        _phone = State(initialValue: user?.phone ?? "")
        _bio = State(initialValue: user?.bio ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Аватар")) {
                    HStack {
                        AvatarView(urlString: user?.avatarUrl, size: 60)
                        Button("Выбрать фото") {
                            showingImagePicker = true
                        }
                    }
                }
                Section(header: Text("Основное")) {
                    TextField("Никнейм *", text: $nickName)
                    TextField("Имя", text: $firstName)
                    TextField("Фамилия", text: $lastName)
                    TextField("Отчество", text: $middleName)
                }
                Section(header: Text("Контакты")) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Телефон", text: $phone)
                        .keyboardType(.phonePad)
                }
                Section(header: Text("О себе")) {
                    TextEditor(text: $bio)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        guard let user = user else { return }
                        let updatedUser = User(
                            userId: user.userId,
                            nickName: nickName,
                            firstName: firstName.isEmpty ? nil : firstName,
                            lastName: lastName.isEmpty ? nil : lastName,
                            middleName: middleName.isEmpty ? nil : middleName,
                            email: email.isEmpty ? nil : email,
                            phone: phone.isEmpty ? nil : phone,
                            avatarUrl: user.avatarUrl,
                            bio: bio.isEmpty ? nil : bio,
                            lastSeen: user.lastSeen,
                            isOnline: user.isOnline,
                            status: user.status,
                            emailVerified: user.emailVerified,
                            phoneVerified: user.phoneVerified,
                            isAdmin: user.isAdmin,
                            createdAt: user.createdAt,
                            updatedAt: user.updatedAt
                        )
                        let avatarData = selectedImage?.jpegData(compressionQuality: 0.8)
                        print("📸 Avatar data size: \(avatarData?.count ?? 0) bytes")
                        onSave(updatedUser, avatarData)
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }
}
