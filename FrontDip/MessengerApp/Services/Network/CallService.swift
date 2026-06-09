import Foundation
import LiveKit
import Combine
import AVFoundation

@MainActor
final class CallService: NSObject, ObservableObject {
    static let shared = CallService()

    @Published var activeCall: Call? {
        didSet {
            print("CallService activeCall changed to \(activeCall?.status ?? "nil") id=\(activeCall?.callId.uuidString ?? "nil")")
        }
    }

    @Published var room: Room?
    @Published var isConnectingToRoom = false
    @Published var connectionError: String?

    private let graphQL = GraphQLClient.shared

    private var endCallTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3

    // Почему добавил: связываем текущую LiveKit-комнату с конкретным callId,
    // чтобы не коннектиться повторно и не путать старую room с новой.
    private var connectedCallId: UUID?

    // Почему добавил: защищаем disconnect от повторного конкурентного вызова.
    private var isDisconnecting = false

    override private init() {
        super.init()
    }

    // MARK: - GraphQL

    func startCall(chatId: UUID, type: String = "video") async throws -> Call {
        if let existing = activeCall {
            let status = existing.status.lowercased()
            if status == "pending" || status == "active" {
                await resetCallState(clearActiveCall: true)
            }
        }

        let variables: [String: Any] = [
            "chatId": chatId.uuidString,
            "type": type
        ]

        struct Response: Decodable {
            let call: StartCallWrapper
        }

        struct StartCallWrapper: Decodable {
            let startCall: Call
        }

        let response: Response = try await graphQL.perform(
            query: GraphQLQueries.startCall,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        )

        let call = response.call.startCall
        applyCallUpdate(call)
        return call
    }

    func acceptCall(callId: UUID) async throws -> Call {
        // Почему поменял: здесь нельзя делать resetCallState(),
        // иначе pending-звонок будет локально уничтожен прямо перед переходом в active.
        let variables = ["callId": callId.uuidString]

        struct Response: Decodable {
            let call: AcceptCallWrapper
        }

        struct AcceptCallWrapper: Decodable {
            let acceptCall: Call
        }

        let response: Response = try await graphQL.perform(
            query: GraphQLQueries.acceptCall,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        )

        let call = response.call.acceptCall
        applyCallUpdate(call)
        NotificationCenter.default.post(name: .callStatusChanged, object: call)
        return call
    }

    func rejectCall(callId: UUID) async throws {
        let variables = ["callId": callId.uuidString]

        struct Response: Decodable {
            let call: RejectCallWrapper
        }

        struct RejectCallWrapper: Decodable {
            let rejectCall: Bool
        }

        _ = try await graphQL.perform(
            query: GraphQLQueries.rejectCall,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        ) as Response

        if activeCall?.callId == callId {
            await finalizeCallLocally(callId: callId, finalStatus: "declined")
        }
    }

    func endCall(callId: UUID) async throws {
        guard let call = activeCall, call.callId == callId else {
            print("endCall ignored: no activeCall or mismatched id")
            return
        }

        let status = call.status.lowercased()

        // Почему поменял: активный звонок тоже должен завершаться этим методом.
        guard status == "pending" || status == "active" else {
            print("endCall ignored: invalid local status \(call.status)")
            return
        }

        let variables = ["callId": callId.uuidString]

        struct Response: Decodable {
            let call: EndCallWrapper
        }

        struct EndCallWrapper: Decodable {
            let endCall: Bool
        }

        _ = try await graphQL.perform(
            query: GraphQLQueries.endCall,
            variables: variables,
            responseType: Response.self,
            authToken: TokenManager.shared.accessToken
        ) as Response

        await finalizeCallLocally(callId: callId, finalStatus: "completed")
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

    func connectToRoom(
        callId: UUID,
        token: String,
        wsUrl: String,
        publishTracks: Bool = true
    ) async throws {
        if connectedCallId == callId,
           let existingRoom = room,
           existingRoom.connectionState == .connected {
            print("Already connected to room for this call, skipping duplicate connection")
            return
        }

        if isConnectingToRoom {
            print("connectToRoom skipped: already connecting")
            return
        }

        connectionError = nil
        isConnectingToRoom = true
        defer { isConnectingToRoom = false }

        if let existingRoom = room {
            if existingRoom.connectionState == .connected || existingRoom.connectionState == .connecting {
                if connectedCallId != callId {
                    print("Disconnecting old room before new call connect")
                    await existingRoom.disconnect()
                    room = nil
                    connectedCallId = nil
                }
            } else {
                room = nil
                connectedCallId = nil
            }
        }

        guard activeCall?.callId == callId else {
            print("connectToRoom aborted: activeCall changed while preparing connection")
            return
        }

        let newRoom = Room(delegate: self)
        room = newRoom

        do {
            try await newRoom.connect(url: wsUrl, token: token)
            try await newRoom.localParticipant.setMicrophone(enabled: true)

            if publishTracks {
                try await newRoom.localParticipant.setCamera(enabled: true)
            } else {
                try? await newRoom.localParticipant.setCamera(enabled: false)
            }

            connectedCallId = callId
            reconnectAttempts = 0
            print("Connected to room and published local tracks. callId=\(callId)")
        } catch {
            connectionError = error.localizedDescription
            room = nil
            connectedCallId = nil
            throw error
        }
    }

    func disconnect(clearActiveCall: Bool = false) async {
        if isDisconnecting {
            return
        }

        isDisconnecting = true
        defer { isDisconnecting = false }

        print("disconnect called")

        endCallTask?.cancel()
        reconnectTask?.cancel()

        if let room {
            await room.disconnect()
        }

        self.room = nil
        self.connectedCallId = nil
        self.isConnectingToRoom = false

        if clearActiveCall {
            self.activeCall = nil
        }
    }

    func resetCallState(clearActiveCall: Bool = true) async {
        print("resetCallState called")
        await disconnect(clearActiveCall: clearActiveCall)
        connectionError = nil
        reconnectAttempts = 0
    }

    func toggleCamera(enabled: Bool) async throws {
        try await room?.localParticipant.setCamera(enabled: enabled)
    }

    func toggleMicrophone(enabled: Bool) async throws {
        try await room?.localParticipant.setMicrophone(enabled: enabled)
    }

    func switchCamera() async throws {
        guard let room else { return }

        if let localVideoTrack = room.localParticipant.videoTracks.first(where: { $0.kind == .video })?.track as? LocalVideoTrack,
           let capturer = localVideoTrack.capturer as? CameraCapturer {
            try await capturer.switchCameraPosition()
        }
    }

    // MARK: - Public sync point for WebSocketService

    func handleRemoteCallUpdated(_ updatedCall: Call) async {
        applyCallUpdate(updatedCall)

        let status = updatedCall.status.lowercased()
        if status == "ended" || status == "declined" || status == "missed" || status == "completed" {
            await finalizeCallLocally(callId: updatedCall.callId, finalStatus: updatedCall.status)
        }
    }

    // MARK: - Private

    private func applyCallUpdate(_ call: Call) {
        if activeCall?.callId == call.callId || activeCall == nil {
            activeCall = call
            return
        }

        let currentStatus = activeCall?.status.lowercased() ?? ""
        if currentStatus == "ended" || currentStatus == "declined" || currentStatus == "missed" || currentStatus == "completed" {
            activeCall = call
        }
    }

    private func finalizeCallLocally(callId: UUID, finalStatus: String) async {
        if activeCall?.callId == callId, var call = activeCall {
            call.status = finalStatus
            activeCall = call
        }

        await disconnect(clearActiveCall: false)

        if activeCall?.callId == callId {
            activeCall = nil
        }

        connectionError = nil
        reconnectAttempts = 0
        NotificationCenter.default.post(name: .callEnded, object: callId)
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("Max reconnect attempts reached")
            Task { [weak self] in
                guard let self else { return }
                if let call = self.activeCall {
                    try? await self.endCall(callId: call.callId)
                }
            }
            return
        }

        guard let call = activeCall else { return }
        let status = call.status.lowercased()
        guard status == "active" else {
            print("Reconnect skipped: call status is \(status)")
            return
        }

        if let currentRoom = room,
           currentRoom.connectionState == .connected || currentRoom.connectionState == .connecting {
            print("Room already connected/connecting, skipping reconnect")
            return
        }

        reconnectAttempts += 1
        let delay = pow(2.0, Double(reconnectAttempts - 1))
        print("Scheduling reconnect attempt \(reconnectAttempts) in \(delay) sec")

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard let liveCall = self.activeCall, liveCall.callId == call.callId else {
                return
            }

            do {
                let tokenData = try await self.getLiveKitToken(callId: liveCall.callId)
                try await self.connectToRoom(
                    callId: liveCall.callId,
                    token: tokenData.token,
                    wsUrl: tokenData.wsUrl,
                    publishTracks: true
                )
                self.reconnectAttempts = 0
            } catch {
                print("Reconnect failed: \(error)")
                self.scheduleReconnect()
            }
        }
    }
}

extension CallService: RoomDelegate {
    nonisolated func room(
        _ room: Room,
        didUpdateConnectionState connectionState: ConnectionState,
        oldState: ConnectionState
    ) {
        print("Room connection state changed: \(oldState) -> \(connectionState)")
    }

    nonisolated func room(_ room: Room, didDisconnectWithError error: Error?) {
        Task { @MainActor in
            print("Room disconnected. error=\(error?.localizedDescription ?? "no error")")
            print("activeCall before disconnect handling: \(self.activeCall?.callId.uuidString ?? "nil")")

            self.room = nil
            self.connectedCallId = nil

            let status = self.activeCall?.status.lowercased() ?? ""

            if let error, status == "active" {
                self.connectionError = error.localizedDescription
                self.scheduleReconnect()
                return
            }

            if status == "ended" || status == "declined" || status == "missed" || status == "completed" {
                self.activeCall = nil
                return
            }

            if status.isEmpty {
                self.activeCall = nil
            }
        }
    }

    nonisolated func room(_ room: Room, participantDidJoin participant: Participant) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    nonisolated func room(
        _ room: Room,
        participant: Participant,
        trackPublication: TrackPublication,
        didSubscribeTrack track: Track
    ) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    nonisolated func room(
        _ room: Room,
        participant: Participant,
        trackPublication: TrackPublication,
        didUnsubscribeTrack track: Track
    ) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}
