import Foundation
import SwiftUI

class ActiveVideoManager: ObservableObject {
    static let shared = ActiveVideoManager()
    
    @Published var activeVideoId: UUID? = nil
    
    private init() {}
    
    func activate(videoId: UUID) {
        if activeVideoId != videoId {
            activeVideoId = videoId
        }
    }
    
    func deactivate(videoId: UUID) {
        if activeVideoId == videoId {
            activeVideoId = nil
        }
    }
}
