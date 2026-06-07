import Foundation

struct AppConfig {
    static let baseURL = "http://192.168.100.247:8002"
    static let graphqlPath = "/graphql"
    static let websocketPath = "/ws/chat"
    
    static var graphqlURL: URL {
        URL(string: baseURL + graphqlPath)!
    }
    
    static var websocketURL: URL {
        URL(string: "ws://192.168.100.247:8000" + websocketPath)!
    }
}
