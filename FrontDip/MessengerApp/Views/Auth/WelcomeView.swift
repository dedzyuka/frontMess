import SwiftUI

struct WelcomeView: View {
    @State private var showLogin = false
    @State private var showRegister = false

    var body: some View {
        ZStack {
            MessengerTheme.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(MessengerTheme.accentSoft.opacity(0.55))
                            .frame(width: 112, height: 112)

                        Circle()
                            .stroke(MessengerTheme.accent.opacity(0.22), lineWidth: 1)
                            .frame(width: 132, height: 132)

                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(MessengerTheme.accent)
                    }

                    VStack(spacing: 10) {
                        Text("SocketUp")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))


                    }
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            showLogin = true
                        }
                    } label: {
                        Text("Войти")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(MessengerTheme.selfBubbleGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            showRegister = true
                        }
                    } label: {
                        Text("Создать аккаунт")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(MessengerTheme.elevatedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(MessengerTheme.divider, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .fullScreenCover(isPresented: $showRegister) {
            RegisterView()
        }
    }
}
