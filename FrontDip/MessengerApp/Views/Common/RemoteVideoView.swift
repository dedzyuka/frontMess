//
//  RemoteVideoView.swift
//  FrontDip
//
//  Created by Bogdan Sakhno on 8.06.26.
//


// RemoteVideoView.swift
import SwiftUI
import LiveKit

struct RemoteVideoView: UIViewRepresentable {
    let participant: RemoteParticipant
    
    func makeUIView(context: Context) -> LiveKit.VideoView {
        let view = LiveKit.VideoView()
        if let track = participant.videoTracks.first?.track as? VideoTrack {
            track.add(videoRenderer: view)
        }
        return view
    }
    
    func updateUIView(_ uiView: LiveKit.VideoView, context: Context) {}
}

// LocalVideoView.swift
import SwiftUI
import LiveKit

struct LocalVideoView: UIViewRepresentable {
    let participant: LocalParticipant
    
    func makeUIView(context: Context) -> LiveKit.VideoView {
        let view = LiveKit.VideoView()
        if let track = participant.videoTracks.first?.track as? VideoTrack {
            track.add(videoRenderer: view)
        }
        return view
    }
    
    func updateUIView(_ uiView: LiveKit.VideoView, context: Context) {}
}