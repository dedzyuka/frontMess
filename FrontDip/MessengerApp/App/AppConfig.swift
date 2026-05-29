
// App/AppConfig.swift
import Foundation

struct AppConfig {
    static let baseURL = "http://localhost:8002"
    static let graphqlPath = "/graphql"
    static let websocketPath = "/ws/chat"
    
    static var graphqlURL: URL {
        URL(string: baseURL + graphqlPath)!
    }
    
    static var websocketURL: URL {
        URL(string: "ws://localhost:8000" + websocketPath)!
    }
}
