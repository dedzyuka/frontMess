//
//  NotificationsView.swift
//  FrontDip
//

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var contactService: ContactService
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if contactService.pendingRequests.isEmpty && contactService.outgoingRequests.isEmpty {
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
                    List {
                        if !contactService.outgoingRequests.isEmpty {
                            Section(header: Text("Отправленные запросы")) {
                                ForEach(contactService.outgoingRequests) { request in
                                    ContactRequestRow(request: request, isOutgoing: true)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                contactService.cancelOutgoingRequest(userId: request.contactUserId)
                                            } label: {
                                                Label("Отменить", systemImage: "xmark.circle")
                                            }
                                        }
                                }
                            }
                        }
                        
                        if !contactService.pendingRequests.isEmpty {
                            Section(header: Text("Входящие запросы")) {
                                ForEach(contactService.pendingRequests) { request in
                                    ContactRequestRow(request: request, isOutgoing: false)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                // Отклонить – используем userId отправителя
                                                Task {
                                                    await declineRequest(request)
                                                }
                                            } label: {
                                                Label("Отклонить", systemImage: "xmark.circle")
                                            }
                                            
                                            Button {
                                                Task { await acceptRequest(request) }
                                            } label: {
                                                Label("Принять", systemImage: "checkmark.circle")
                                                    .tint(.green)
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .refreshable {
                        await refreshRequests()
                    }
                }
            }
            .navigationTitle("Уведомления")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Обновить") {
                            Task { await refreshRequests() }
                        }
                    }
                }
            }
            .onAppear {
                contactService.loadPendingRequests()
                contactService.loadOutgoingRequests()
            }
        }
    }
    
    private func acceptRequest(_ request: Contact) async {
        do {
            _ = try await contactService.acceptContact(contactUserId: request.userId.uuidString)
            await MainActor.run {
                contactService.loadContacts()
                contactService.loadPendingRequests()
                NotificationService.shared.showSuccess("Контакт добавлен")
            }
        } catch {
            await MainActor.run {
                NotificationService.shared.showError("Ошибка: \(error.localizedDescription)")
            }
        }
    }
    
    private func declineRequest(_ request: Contact) async {
        do {
            // Для отклонения используем userId отправителя
            _ = try await contactService.removeContact(userId: request.userId.uuidString)
            await MainActor.run {
                contactService.loadPendingRequests()
                NotificationService.shared.showInfo("Запрос отклонён")
            }
        } catch {
            await MainActor.run {
                NotificationService.shared.showError("Ошибка: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshRequests() async {
        isLoading = true
        await contactService.syncPendingRequests()
        await contactService.syncOutgoingRequests()
        isLoading = false
    }
}

struct ContactRequestRow: View {
    let request: Contact
    let isOutgoing: Bool
    @State private var showingActionSheet = false
    
    var body: some View {
        // ✅ Исправлено: для входящего запроса открываем профиль отправителя (request.userId)
        NavigationLink(destination: UserProfileView(userId: isOutgoing ? request.contactUserId : request.userId)) {
            HStack {
                Circle()
                    .fill(isOutgoing ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text((request.contactUser?.nickName ?? "?").prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(isOutgoing ? .blue : .orange)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.contactUser?.nickName ?? "Неизвестный")
                        .font(.headline)
                    
                    Text(isOutgoing ? "Ожидает подтверждения" : "Запрос на контакт")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatDate(request.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isOutgoing {
                    Text("Отправлен")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                } else if request.status == "pending" {
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
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
