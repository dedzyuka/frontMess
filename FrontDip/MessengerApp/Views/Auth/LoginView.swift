import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                VStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Anonymous Messenger")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Secure end-to-end encrypted messaging")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
                
                VStack(spacing: 16) {
                    TextField("Enter your nickname", text: $viewModel.nickname)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(.horizontal)
                    
                    Button(action: {
                        Task {
                            await viewModel.register()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Start Messaging")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canRegister ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(!viewModel.canRegister || viewModel.isLoading)
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Text("Your messages are encrypted and never stored on our servers")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                Spacer()
                
                // Добавляем кнопку для отладки
                Button("Debug: Auto Login") {
                    viewModel.autoLogin()
                }
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom)
            }
            .padding()
            .navigationBarHidden(true)
            .onAppear {
                // Убираем отсюда вызов метода - переносим в ContentView
            }
        }
    }
}
