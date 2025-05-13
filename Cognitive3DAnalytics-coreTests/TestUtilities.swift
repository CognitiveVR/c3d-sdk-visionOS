import Foundation

/// Response model used for testing network responses
struct ServerResponse: Codable {
    let status: String
    let received: Bool
}
