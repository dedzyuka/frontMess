
import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AuthViewModel()
    @State private var nickname = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    // Заголовок
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 70))
                            .foregroundColor(.green)
                        Text("Создать аккаунт")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Начните общаться безопасно")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)

                    // Поля
                    VStack(spacing: 16) {
                        CustomTextField(icon: "person", placeholder: "Никнейм", text: $nickname)
                        CustomTextField(icon: "envelope", placeholder: "Email", text: $email)
                        CustomTextField(icon: "phone", placeholder: "Телефон (опционально)", text: $phone)
                        CustomSecureField(icon: "lock", placeholder: "Пароль", text: $password)
                    }
                    .padding(.horizontal, 24)

                    // Кнопка регистрации
                    Button {
                        Task {
                            let success = await viewModel.register(
                                                nickname: nickname,
                                                email: email,
                                                password: password,
                                                phone: phone
                                            )
                            if success {
                                        dismiss()          // ← добавить
                                }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(30)
                        } else {
                            Text("Зарегистрироваться")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(30)
                        }
                    }
                    .padding(.horizontal, 24)
                    .disabled(viewModel.isLoading)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Spacer()

                    Button("Уже есть аккаунт? Войти") {
                        dismiss()
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
    }
}
