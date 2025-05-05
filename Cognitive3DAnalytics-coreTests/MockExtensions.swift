import Foundation
import XCTest
@testable import Cognitive3DAnalytics

// MARK: - Test Utility Extensions
extension XCTestCase {
    /// Creates a temporary directory for testing
    func createTempDirectory(prefix: String = "TempDir") -> String {
        let tempDir = NSTemporaryDirectory()
        let testDirectory = tempDir + "\(prefix)-\(UUID().uuidString)/"

        try? FileManager.default.createDirectory(atPath: testDirectory, withIntermediateDirectories: true)

        return testDirectory
    }

    /// Removes a directory
    func cleanupDirectory(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Creates a test event payload
    func createTestEventPayload() -> Data {
        let payload: [String: Any] = [
            "data": [
                [
                    "name": "test_event",
                    "timestamp": Date().timeIntervalSince1970,
                    "properties": ["test": "value"]
                ]
            ],
            "userId": "test_user",
            "timestamp": Date().timeIntervalSince1970,
            "sessionId": "test_session",
            "part": 0,
            "hmdType": "visionOS",
            "interval": 0.1,
            "formatVersion": "1.0",
            "properties": [
                "c3d.app.name": "TestApp"
            ]
        ]

        return try! JSONSerialization.data(withJSONObject: payload)
    }
}
