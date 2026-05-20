// ./FrontDip/MessengerApp/Views/Contact/NotificationsView.swift
import SwiftUI

// ./FrontDip/MessengerApp/Views/Contact/NotificationsView.swift
struct NotificationsView: View {
    @EnvironmentObject var contactService: ContactService
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    
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
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    contactService.declineContactRequest(request)
                                } label: {
                                    Label("Отклонить", systemImage: "xmark.circle")
                                }
                                
                                Button {
                                    contactService.acceptContactRequest(request)
                                } label: {
                                    Label("Принять", systemImage: "checkmark.circle")
                                        .tint(.green)
                                }
                            }
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
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Обновить") {
                            refreshRequests()
                        }
                    }
                }
            }
            .onAppear {
                contactService.loadPendingRequests()
            }
        }
    }
    
    private func refreshRequests() {
        isLoading = true
        Task {
            await contactService.syncPendingRequests()
            await MainActor.run {
                isLoading = false
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromNickname)
                    .font(.headline)
                
                Text("Запрос на контакт")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatDate(request.createdAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if request.status == "pending" {
                Text("Ждет ответа")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
