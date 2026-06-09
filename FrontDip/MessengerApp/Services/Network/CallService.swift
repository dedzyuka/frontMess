//
//  CallService.swift
//  MessengerApp
//

import Foundation
import LiveKit
import Combine
import AVFoundation

@MainActor
class CallService: NSObject, ObservableObject {
    static let shared = CallService()
    
    @Published var activeCall: Call? {
        didSet {
            print("🔄 CallService: activeCall changed to \(activeCall?.status ?? "nil")")
        }
    }
    @Published var room: Room?
    @Published var isConnectingToRoom = false
    @Published var connectionError: String?
    
    private let graphQL = GraphQLClient.shared
    private var endCallTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    
    override private init() { super.init() }
    
    // MARK: - GraphQL
    
    func startCall(chatId: UUID, type: String = "video") async throws -> Call {
        let variables: [String: Any] = ["chatId": chatId.uuidString, "type": type]
        struct Response: Decodable { let call: StartCallWrapper }
        struct StartCallWrapper: Decodable { let startCall: Call }
        let response: Response = try await graphQL.perform(
            query: GraphQLQueries.startCall,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        )
        let call = response.call.startCall
        await MainActor.run { self.activeCall = call }
        return call
    }
    
    func acceptCall(callId: UUID) async throws -> Call {
        let variables = ["callId": callId.uuidString]
        struct Response: Decodable { let call: AcceptCallWrapper }
        struct AcceptCallWrapper: Decodable { let acceptCall: Call }
        
        do {
            let response: Response = try await graphQL.perform(
                query: GraphQLQueries.acceptCall,
                variables: variables,
                responseType: Response.self,
                authToken: TokenManager.shared.accessToken
            )
            let call = response.call.acceptCall
            await MainActor.run { self.activeCall = call }
            return call
        } catch {
            await MainActor.run { self.activeCall = nil }
            throw error
        }
    }
    
    func rejectCall(callId: UUID) async throws {
        let variables = ["callId": callId.uuidString]
        struct Response: Decodable { let call: RejectCallWrapper }
        struct RejectCallWrapper: Decodable { let rejectCall: Bool }
        _ = try await graphQL.perform(
            query: GraphQLQueries.rejectCall,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        )
        await MainActor.run {
            if activeCall?.callId == callId { activeCall = nil }
        }
    }
    
    func endCall(callId: UUID) async throws {
        guard let call = activeCall, call.callId == callId, call.status == "pending" else {
            print("🔚 endCall ignored – call not pending (status: \(activeCall?.status ?? "nil"))")
            return
        }
        print("🔚 endCall called for call \(callId)")
        print("📞 Call stack:\n\(Thread.callStackSymbols.prefix(20).joined(separator: "\n"))")

        let variables = ["callId": callId.uuidString]
        struct Response: Decodable { let call: EndCallWrapper }
        struct EndCallWrapper: Decodable { let endCall: Bool }
        _ = try await graphQL.perform(
            query: GraphQLQueries.endCall,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        )
        await MainActor.run {
            if activeCall?.callId == callId {
                activeCall = nil
                endCallTask = Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await room?.disconnect()
                    room = nil
                }
            }
        }
    }
    
    func getLiveKitToken(callId: UUID) async throws -> (token: String, wsUrl: String) {
        let variables = ["callId": callId.uuidString]
        struct Response: Decodable {
            let call: TokenWrapper
        }
        struct TokenWrapper: Decodable {
            let getLiveKitToken: TokenResult
        }
        struct TokenResult: Decodable {
            let token: String
            let wsUrl: String
        }
        let response: Response = try await graphQL.perform(
            query: GraphQLQueries.getLiveKitToken,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        )
        let result = response.call.getLiveKitToken
        return (result.token, result.wsUrl)
    }
    
    // MARK: - LiveKit
    
    func connectToRoom(callId: UUID, token: String, wsUrl: String, publishTracks: Bool = true) async throws {
        await MainActor.run { isConnectingToRoom = true }
        defer { Task { await MainActor.run { self.isConnectingToRoom = false } } }
        
        // Если уже есть комната, не создаём новую
        if room != nil {
            print("⚠️ Already connected to room")
            return
        }
        
        let newRoom = Room(delegate: self)
        self.room = newRoom
        try await newRoom.connect(url: wsUrl, token: token)
        
        if publishTracks {
            // Включаем микрофон и камеру сразу
            try await newRoom.localParticipant.setMicrophone(enabled: true)
            try await newRoom.localParticipant.setCamera(enabled: true)
            print("🎥 Connected to room and publishing tracks")
        }
    }
    
    func disconnect() async {
        endCallTask?.cancel()
        reconnectTask?.cancel()
        await room?.disconnect()
        room = nil
        await MainActor.run { activeCall = nil }
    }
    
    func toggleCamera(enabled: Bool) async throws {
        try await room?.localParticipant.setCamera(enabled: enabled)
    }
    
    func toggleMicrophone(enabled: Bool) async throws {
        try await room?.localParticipant.setMicrophone(enabled: enabled)
    }
    
    func switchCamera() async throws {
        guard let room = room else { return }
        if let localVideoTrack = room.localParticipant.videoTracks.first(where: { $0.kind == .video })?.track as? LocalVideoTrack,
           let capturer = localVideoTrack.capturer as? CameraCapturer {
            try await capturer.switchCameraPosition()
        }
    }
    
    // MARK: - Private reconnect logic
    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let call = activeCall, room == nil else { return }
            do {
                let (token, wsUrl) = try await getLiveKitToken(callId: call.callId)
                try await connectToRoom(callId: call.callId, token: token, wsUrl: wsUrl, publishTracks: true)
            } catch {
                print("Reconnect failed: \(error)")
            }
        }
    }
}

// MARK: - RoomDelegate
extension CallService: RoomDelegate {
    func room(_ room: Room, participantDidJoin participant: Participant) {
        print("👤 Participant joined: \(participant.identity)")
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
    
    func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didSubscribeTrack track: Track) {
        print("📹 Subscribed to \(track.kind) track from \(participant.identity)")
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
    
    func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didUnsubscribeTrack track: Track) {
        print("📹 Unsubscribed from \(track.kind) track from \(participant.identity)")
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
    
    func room(_ room: Room, didDisconnectWithError error: Error?) {
        print("❌ Room disconnected: \(error?.localizedDescription ?? "no error")")
        print("🔍 Call stack: \(Thread.callStackSymbols.prefix(10).joined(separator: "\n"))")
        DispatchQueue.main.async {
            if let error = error, self.activeCall != nil {
                print("🔍 Disconnect error details: \(error)")
                // Пробуем переподключиться, а не завершать звонок
                self.scheduleReconnect()
            } else {
                self.activeCall = nil
                self.room = nil
            }
        }
    }
}
