import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = AuthViewModel()
    @State private var login = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case login
        case password
    }

    var body: some View {
        ZStack {
            MessengerTheme.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topSection
                        .padding(.top, 54)

                    formSection
                        .padding(.top, 36)

                    Spacer(minLength: 30)

                    footerSection
                        .padding(.top, 28)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 22)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topTrailing) {
            closeButton
        }
    }

    private var topSection: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(MessengerTheme.accentSoft.opacity(0.58))
                    .frame(width: 104, height: 104)

                Circle()
                    .stroke(MessengerTheme.accent.opacity(0.24), lineWidth: 1)
                    .frame(width: 124, height: 124)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(MessengerTheme.accent)
            }

            VStack(spacing: 8) {
                Text("Вход")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))

            }
        }
    }

    private var formSection: some View {
        VStack(spacing: 14) {
            AuthInputField(
                icon: "person.fill",
                title: "Email или логин",
                placeholder: "Введите email",
                text: $login
            )
            .focused($focusedField, equals: .login)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .password
            }

            AuthSecureInputField(
                icon: "lock.fill",
                title: "Пароль",
                placeholder: "Введите пароль",
                text: $password
            )
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit {
                submit()
            }

            if let error = viewModel.errorMessage, !error.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)

                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button(action: submit) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(MessengerTheme.selfBubbleGradient)
                        .frame(height: 56)

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Войти")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || viewModel.isLoading)
            .opacity((!canSubmit || viewModel.isLoading) ? 0.88 : 1.0)
            .scaleEffect(viewModel.isLoading ? 0.985 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.isLoading)
        }
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            Text("Используй данные аккаунта, которые уже работают на бэке.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Назад")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(MessengerTheme.elevatedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(MessengerTheme.divider, lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .background(MessengerTheme.elevatedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MessengerTheme.divider, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
        .padding(.trailing, 16)
    }

    private var canSubmit: Bool {
        !login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSubmit, !viewModel.isLoading else { return }

        focusedField = nil

        Task {
            let success = await viewModel.login(login: login, password: password)
            if success {
                dismiss()
            }
        }
    }
}

private struct AuthInputField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MessengerTheme.accent)
                    .frame(width: 18)

                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(MessengerTheme.elevatedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MessengerTheme.divider, lineWidth: 0.8)
            )
        }
    }
}

private struct AuthSecureInputField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MessengerTheme.accent)
                    .frame(width: 18)

                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .font(.system(size: 16))

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isRevealed.toggle()
                    }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(MessengerTheme.elevatedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MessengerTheme.divider, lineWidth: 0.8)
            )
        }
    }
}
