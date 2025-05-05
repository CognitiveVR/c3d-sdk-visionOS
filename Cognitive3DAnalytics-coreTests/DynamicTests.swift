//
//  DynamicTests.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import XCTest
@testable import Cognitive3DAnalytics

final class DynamicTests: XCTestCase {
    // MARK: - Test Constants
    private enum Constants {
        static let timestamp = 1581442899.0
        static let userId = "6f89ecadc3a44ea3748f380552d608b1e911d074"
        static let formatVersion = "1.0"
    }
    
    // MARK: - Test Properties
    private var encoder: JSONEncoder!
    private var decoder: JSONDecoder!
    
    // MARK: - Setup and Teardown
    override func setUp() {
        super.setUp()
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }
    
    override func tearDown() {
        encoder = nil
        decoder = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    private func createTestMesh(name: String = "Table", mesh: String = "table", fileType: String = "gltf") -> ManifestEntry {
        ManifestEntry(name: name, mesh: mesh, fileType: fileType)
    }
    
    private func createTestDynamicEventData(
        id: String,
        time: Double = Constants.timestamp,
        p: [Double] = [0.0, 0.0, 0.0],
        r: [Double] = [0.0, 0.0, 0.0, 1.0],
        properties: [[String: AnyCodable]]? = nil,
        buttons: Buttons? = nil
    ) -> DynamicEventData {
        DynamicEventData(id: id, time: time, p: p, r: r, s: nil, properties: properties, buttons: buttons)
    }
    
    // MARK: - Tests
    func testBasicDynamicDecoding() throws {
        // Given
        let jsonString = """
        {
            "userid": "\(Constants.userId)",
            "timestamp": \(Constants.timestamp),
            "sessionid": "\(Int(Constants.timestamp))_\(Constants.userId)",
            "part": 9,
            "formatversion": "1.0",
            "manifest": {
                "editor_1": {
                    "name": "Table",
                    "mesh": "table",
                    "fileType": "gltf"
                }
            },
            "data": [{
                "id": "editor_1",
                "time": \(Constants.timestamp),
                "p": [1.0, 2.0, 3.0],
                "r": [0.0, 0.0, 0.0, 1.0],
                "properties": [{"enabled": true}]
            }]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        // When
        let dynamic = try decoder.decode(DynamicSession.self, from: jsonData)
        
        // Then
        XCTAssertEqual(dynamic.userId, Constants.userId)
        XCTAssertEqual(dynamic.timestamp, Constants.timestamp)
        XCTAssertEqual(dynamic.sessionId, "\(Int(Constants.timestamp))_\(Constants.userId)")
        XCTAssertEqual(dynamic.part, 9)
        XCTAssertEqual(dynamic.formatVersion, "1.0")
        
        // Verify manifest
        XCTAssertEqual(dynamic.manifest.count, 1)
        let mesh = dynamic.manifest["editor_1"]
        XCTAssertEqual(mesh?.name, "Table")
        XCTAssertEqual(mesh?.mesh, "table")
        XCTAssertEqual(mesh?.fileType, "gltf")
        
        // Verify data
        XCTAssertEqual(dynamic.data.count, 1)
        let eventData = dynamic.data[0]
        XCTAssertEqual(eventData.id, "editor_1")
        XCTAssertEqual(eventData.p, [1.0, 2.0, 3.0])
        XCTAssertEqual(eventData.r, [0.0, 0.0, 0.0, 1.0])
        XCTAssertEqual(eventData.properties?.first?["enabled"]?.value as? Bool, true)
    }
    
    func testDynamicWithButtonsData() throws {
        // Given
        let jsonString = """
        {
            "userid": "\(Constants.userId)",
            "timestamp": \(Constants.timestamp),
            "sessionid": "\(Int(Constants.timestamp))_\(Constants.userId)",
            "part": 9,
            "formatversion": "1.0",
            "manifest": {
                "editor_1": {
                    "name": "Controller",
                    "mesh": "controller",
                    "fileType": "gltf"
                }
            },
            "data": [{
                "id": "editor_1",
                "time": \(Constants.timestamp),
                "p": [1.0, 2.0, 3.0],
                "r": [0.0, 0.0, 0.0, 1.0],
                "properties": [{"enabled": true}],
                "buttons": {
                    "vive_touchpad": {
                        "buttonPercent": 50.0,
                        "x": -0.394,
                        "y": -0.827
                    }
                }
            }]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        // When
        let dynamic = try decoder.decode(DynamicSession.self, from: jsonData)
        
        // Then
        let eventData = dynamic.data[0]
        let touchpadState = eventData.buttons?["vive_touchpad"]
        XCTAssertNotNil(touchpadState)
        XCTAssertEqual(touchpadState?.buttonPercent, 50.0)
        XCTAssertEqual(touchpadState?.x, -0.394)
        XCTAssertEqual(touchpadState?.y, -0.827)
    }
    
    func testRealWorldExample() throws {
        // Given
        let jsonString = """
        {
            "userid": "6f89ecadc3a44ea3748f380552d608b1e911d074",
            "timestamp": 1581442899,
            "sessionid": "1581442899_6f89ecadc3a44ea3748f380552d608b1e911d074",
            "part": 9,
            "formatversion": "1.0",
            "manifest": {
                "editor_68afe8a4-c1e2-4633-991a-f18fab3195f5": {
                    "name": "Supervisor",
                    "mesh": "supervisor",
                    "fileType": "gltf"
                }
            },
            "data": [{
                "id": "editor_68afe8a4-c1e2-4633-991a-f18fab3195f5",
                "time": 1581442904.28293,
                "p": [-5.335, 0.955, -3.00999],
                "r": [0, -0.99706, 0, -0.07657],
                "properties": [{"enabled": true}]
            }]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        // When
        let dynamic = try decoder.decode(DynamicSession.self, from: jsonData)
        
        // Then
        XCTAssertEqual(dynamic.userId, "6f89ecadc3a44ea3748f380552d608b1e911d074")
        XCTAssertEqual(dynamic.timestamp, 1581442899)
        XCTAssertEqual(dynamic.part, 9)
        
        let mesh = dynamic.manifest["editor_68afe8a4-c1e2-4633-991a-f18fab3195f5"]
        XCTAssertEqual(mesh?.name, "Supervisor")
        XCTAssertEqual(mesh?.mesh, "supervisor")
        
        let eventData = dynamic.data[0]
        XCTAssertEqual(eventData.time, 1581442904.28293)
        XCTAssertEqual(eventData.p, [-5.335, 0.955, -3.00999])
        XCTAssertEqual(eventData.r, [0, -0.99706, 0, -0.07657])
    }
}