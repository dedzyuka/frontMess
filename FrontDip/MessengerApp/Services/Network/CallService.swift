//
//  CallService.swift
//  MessengerApp
//

import Foundation
import LiveKit
import Combine
import AVFoundation

class CallService: NSObject, ObservableObject {
    static let shared = CallService()
    
    @Published var currentCall: Call?
    @Published var room: Room?
    
    private let graphQL = GraphQLClient.shared
    
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
        await MainActor.run { self.currentCall = call }
        return call
    }
    
    func acceptCall(callId: UUID) async throws -> Call {
        let variables = ["callId": callId.uuidString]
        struct Response: Decodable { let call: AcceptCallWrapper }
        struct AcceptCallWrapper: Decodable { let acceptCall: Call }
        let response: Response = try await graphQL.perform(
            query: GraphQLQueries.acceptCall,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        )
        let call = response.call.acceptCall
        await MainActor.run { self.currentCall = call }
        return call
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
        await MainActor.run { if currentCall?.callId == callId { currentCall = nil } }
    }
    
    func endCall(callId: UUID) async throws {
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
            if currentCall?.callId == callId {
                currentCall = nil
                Task { await room?.disconnect() }
                room = nil
            }
        }
    }
    
    func getLiveKitToken(callId: UUID) async throws -> (token: String, wsUrl: String) {
        let variables = ["callId": callId.uuidString]
        struct Response: Decodable { let call: TokenWrapper }
        struct TokenWrapper: Decodable { let getLiveKitToken: String }
        let response: Response = try await graphQL.perform(
            query: GraphQLQueries.getLiveKitToken,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        )
        let token = response.call.getLiveKitToken
        let wsUrl = AppConfig.liveKitWSURL
        return (token, wsUrl)
    }
    
    // MARK: - LiveKit
    func connectToRoom(callId: UUID, token: String, wsUrl: String) async throws {
        guard room == nil else { return }
        let newRoom = Room(delegate: self)
        self.room = newRoom
        try await newRoom.connect(url: wsUrl, token: token)
        try await newRoom.localParticipant.setMicrophone(enabled: true)
        try await newRoom.localParticipant.setCamera(enabled: true)
    }
    
    func disconnect() async {
        await room?.disconnect()
        room = nil
    }
    
    func toggleCamera(enabled: Bool) async throws {
        try await room?.localParticipant.setCamera(enabled: enabled)
    }
    
    func toggleMicrophone(enabled: Bool) async throws {
        try await room?.localParticipant.setMicrophone(enabled: enabled)
    }
    
    // ИСПРАВЛЕННЫЙ МЕТОД
    func switchCamera() async throws {
        guard let room = room else { return }
        if let localVideoTrack = room.localParticipant.videoTracks.first(where: { $0.kind == .video })?.track as? LocalVideoTrack,
           let capturer = localVideoTrack.capturer as? CameraCapturer {
            try await capturer.switchCameraPosition()
        }
    }
}

// MARK: - RoomDelegate
extension CallService: RoomDelegate {
    @MainActor
    func room(_ room: Room, didDisconnectWithError error: Error?) {
        currentCall = nil
    }
}
