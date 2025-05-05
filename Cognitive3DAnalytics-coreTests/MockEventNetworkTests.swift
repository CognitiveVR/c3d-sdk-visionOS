import XCTest
@testable import Cognitive3DAnalytics

final class MockEventNetworkTests: XCTestCase {
    var mockSession: MockURLSession!
    var networkClient: TestNetworkClient!
    let sceneId = "f8dcd680-4f15-4849-99a8-2f618cf5d353"
    let sceneVersion = "1"

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        networkClient = TestNetworkClient(session: mockSession)
    }

    func testEventPostSuccess() {
        let expectation = expectation(description: "Post event")

        let event = Event(
            userId: "test-user",
            timestamp: Date().timeIntervalSince1970,
            sessionId: "test-session",
            part: 1,
            formatVersion: "1.0",
            data: [
                EventData(
                    name: "test-event",
                    time: Date().timeIntervalSince1970,
                    point: [1.0, 2.0, 3.0],
                    properties: ["test": .string("value")],
                    dynamicObjectId: nil
                )
            ]
        )

        let successResponse = HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:8080/event/\(sceneId)?version=\(sceneVersion)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        mockSession.mockResponse = successResponse
        mockSession.mockData = try? JSONEncoder().encode(ServerResponse(status: "success", received: true))

        networkClient.postEvent(event, sceneId: sceneId, version: sceneVersion) { result in
            if case .success = result {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1.0)
    }

    func testEventPostFailure() {
        let expectation = expectation(description: "Post event failure")

        let event = Event(
            userId: "test-user",
            timestamp: Date().timeIntervalSince1970,
            sessionId: "test-session",
            part: 1,
            formatVersion: "1.0",
            data: []
        )

        mockSession.mockError = NSError(domain: "test", code: -1)

        networkClient.postEvent(event, sceneId: sceneId, version: sceneVersion) { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1.0)
    }
}
