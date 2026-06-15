import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AuthViewModel()

    @State private var nickname = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""

    @FocusState private var focusedField: RegisterField?

    private enum RegisterField: Hashable {
        case nickname
        case email
        case phone
        case password
    }

    private var canSubmit: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        !viewModel.isLoading
    }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerView
                    formCard
                    bottomActions
                }
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(red: 244 / 255, green: 248 / 255, blue: 246 / 255),
                Color(red: 235 / 255, green: 241 / 255, blue: 239 / 255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Color.black.opacity(colorSchemeOverlayOpacity)
        )
        .ignoresSafeArea()
    }

    private var colorSchemeOverlayOpacity: Double {
        UITraitCollection.current.userInterfaceStyle == .dark ? 0.22 : 0.0
    }

    private var headerView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 217 / 255, green: 122 / 255, blue: 92 / 255).opacity(0.14))
                    .frame(width: 94, height: 94)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Color(red: 217 / 255, green: 122 / 255, blue: 92 / 255))
            }

            VStack(spacing: 6) {
                Text("Создать аккаунт")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Спокойный и аккуратный старт без лишнего шума.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 22)
    }

    private var formCard: some View {
        VStack(spacing: 16) {
            AuthInputField(
                icon: "person",
                title: "Никнейм",
                placeholder: "Введите никнейм",
                text: $nickname,
                textContentType: .username,
                keyboardType: .default,
                submitLabel: .next
            )
            .focused($focusedField, equals: .nickname)
            .onSubmit {
                focusedField = .email
            }

            AuthInputField(
                icon: "envelope",
                title: "Email",
                placeholder: "name@example.com",
                text: $email,
                textContentType: .emailAddress,
                keyboardType: .emailAddress,
                submitLabel: .next
            )
            .textInputAutocapitalization(.never)
            .focused($focusedField, equals: .email)
            .onSubmit {
                focusedField = .phone
            }

            AuthInputField(
                icon: "phone",
                title: "Телефон",
                placeholder: "+375 ...",
                text: $phone,
                textContentType: .telephoneNumber,
                keyboardType: .phonePad,
                submitLabel: .next
            )
            .focused($focusedField, equals: .phone)
            .onSubmit {
                focusedField = .password
            }

            AuthSecureInputField(
                icon: "lock",
                title: "Пароль",
                placeholder: "Введите пароль",
                text: $password,
                textContentType: .newPassword,
                submitLabel: .done
            )
            .focused($focusedField, equals: .password)
            .onSubmit {
                submit()
            }

            Button(action: submit) {
                HStack(spacing: 10) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }

                    Text(viewModel.isLoading ? "Создание..." : "Зарегистрироваться")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    canSubmit
                    ? Color(red: 217 / 255, green: 122 / 255, blue: 92 / 255)
                    : Color.gray.opacity(0.35)
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .animation(.easeInOut(duration: 0.18), value: canSubmit)
            }
            .disabled(!canSubmit)
            .padding(.top, 6)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var bottomActions: some View {
        VStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Text("Уже есть аккаунт? Войти")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(red: 217 / 255, green: 122 / 255, blue: 92 / 255))
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 4)
    }

    private func submit() {
        guard canSubmit else { return }

        focusedField = nil

        Task {
            let success = await viewModel.register(
                nickname: nickname,
                email: email,
                password: password,
                phone: phone
            )

            if success {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Reusable Auth Fields

private struct AuthInputField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String

    var textContentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 217 / 255, green: 122 / 255, blue: 92 / 255))
                    .frame(width: 18)

                TextField(placeholder, text: $text)
                    .textContentType(textContentType)
                    .keyboardType(keyboardType)
                    .submitLabel(submitLabel)
                    .autocorrectionDisabled()
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color(.systemGray6).opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct AuthSecureInputField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String

    var textContentType: UITextContentType?
    var submitLabel: SubmitLabel = .done

    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 217 / 255, green: 122 / 255, blue: 92 / 255))
                    .frame(width: 18)

                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textContentType(textContentType)
                .submitLabel(submitLabel)
                .font(.system(size: 16))

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color(.systemGray6).opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
