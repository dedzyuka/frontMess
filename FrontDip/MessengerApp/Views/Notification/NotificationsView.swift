// ./FrontDip/MessengerApp/Views/Contact/NotificationsView.swift
import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var contactService: ContactService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if contactService.pendingRequests.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("Нет уведомлений")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(contactService.pendingRequests) { request in
                        ContactRequestRow(request: request)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Уведомления")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                contactService.loadPendingRequests()
            }
        }
    }
}

struct ContactRequestRow: View {
    let request: ContactRequest
    @State private var showingActionSheet = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.orange.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(request.fromNickname.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(.orange)
                )
            
            VStack(alignment: .leading) {
                Text(request.fromNickname)
                    .font(.headline)
                Text("Запрос на контакт")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                showingActionSheet = true
            }) {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Запрос на контакт"),
                message: Text("Принять запрос от \(request.fromNickname)?"),
                buttons: [
                    .default(Text("Принять")) {
                        ContactService.shared.acceptContactRequest(request)
                    },
                    .destructive(Text("Отклонить")) {
                        ContactService.shared.declineContactRequest(request)
                    },
                    .cancel()
                ]
            )
        }
    }
}
