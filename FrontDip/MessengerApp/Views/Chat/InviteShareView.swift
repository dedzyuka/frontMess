// ./FrontDip/MessengerApp/Views/Chat/InviteShareView.swift
import SwiftUI

struct InviteShareView: View {
    let inviteKey: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 15) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Chat Created!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Share this invite key with friends:")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Invite Key
                VStack(spacing: 10) {
                    Text("Invite Key:")
                        .font(.headline)
                    
                    Text(inviteKey)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .textSelection(.enabled)
                }
                .padding(.horizontal)
                
                // Share button
                Button(action: {
                    shareInviteKey()
                }) {
                    Label("Share Invite Key", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func shareInviteKey() {
        let activityVC = UIActivityViewController(
            activityItems: [inviteKey],
            applicationActivities: nil
        )
        
        // Для iOS
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
