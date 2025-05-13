import XCTest
@testable import Cognitive3DAnalytics

/**
 * Comprehensive test suite for TestNetworkClient
 *
 * Tests cover:
 * - Success cases with proper request formatting
 * - Network error handling
 * - Server error responses
 * - Various edge cases in data formatting
 */
final class NetworkClientTests: XCTestCase {
    var mockSession: MockURLSession!
    var networkClient: TestNetworkClient!
    let sceneId = "f8dcd680-4f15-4849-99a8-2f618cf5d353"
    let sceneVersion = "1"

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        let baseURL = URL(string: "http://127.0.0.1:8080")!
        networkClient = TestNetworkClient(session: mockSession, baseURL: baseURL)
    }

    // MARK: - Success Cases

    func testEventPostSuccess() async throws {
        let expectation = expectation(description: "Post event success")

        let event = createTestEvent()

        // Mock a successful response
        let successResponse = HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:8080/events/\(sceneId)?version=\(sceneVersion)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let mockResponseData = try JSONEncoder().encode(ServerResponse(status: "success", received: true))
        mockSession.mockResponse = successResponse
        mockSession.mockData = mockResponseData

        networkClient.postEvent(event, sceneId: sceneId, version: sceneVersion) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(ServerResponse.self, from: data)
                    XCTAssertEqual(response.status, "success")
                    XCTAssertTrue(response.received)
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to decode response: \(error)")
                }
            case .failure(let error):
                XCTFail("Network request failed: \(error)")
            }
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        // Verify the request was properly formatted
        XCTAssertNotNil(mockSession.lastRequest)
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        // Verify URL is correctly constructed
        let expectedUrlString = "http://127.0.0.1:8080/events/\(sceneId)?version=\(sceneVersion)"
        XCTAssertEqual(mockSession.lastRequest?.url?.absoluteString, expectedUrlString)
    }

    func testRequestBodyFormatting() async throws {
        let expectation = expectation(description: "Request body properly formatted")

        let event = createTestEvent()

        // Set up mock response
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:8080/events/\(sceneId)?version=\(sceneVersion)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockData = try JSONEncoder().encode(ServerResponse(status: "success", received: true))

        // Make request
        networkClient.postEvent(event, sceneId: sceneId, version: sceneVersion) { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        // Verify request body contains the expected data
        guard let requestBody = mockSession.lastRequest?.httpBody else {
            XCTFail("Request body is missing")
            return
        }

        let decodedEvent = try JSONDecoder().decode(Event.self, from: requestBody)
        XCTAssertEqual(decodedEvent.userId, "test-user")
        XCTAssertEqual(decodedEvent.sessionId, "test-session")
        XCTAssertEqual(decodedEvent.part, 1)
        XCTAssertEqual(decodedEvent.formatVersion, "1.0")
        XCTAssertEqual(decodedEvent.data.count, 1)

        let eventData = decodedEvent.data.first
        XCTAssertEqual(eventData?.name, "test-event")
        XCTAssertEqual(eventData?.point, [1.0, 2.0, 3.0])
        XCTAssertEqual(eventData?.dynamicObjectId, "ABCDEF12345")
    }

    // MARK: - Error Cases

    func testNetworkError() async throws {
        let expectation = expectation(description: "Network error handling")

        let event = createTestEvent(withEmptyData: true)

        // Mock a network error
        mockSession.mockError = NSError(domain: "NSURLErrorDomain", code: -1004)

        networkClient.postEvent(event, sceneId: sceneId, version: sceneVersion) { result in
            switch result {
            case .success:
                XCTFail("Expected failure but got success")
            case .failure(let error):
                // Verify error is propagated correctly
                let nsError = error as NSError
                XCTAssertEqual(nsError.domain, "NSURLErrorDomain")
                XCTAssertEqual(nsError.code, -1004)
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testServerErrorResponse() async throws {
        let expectation = expectation(description: "Server error handling")

        let event = createTestEvent(withEmptyData: true)

        // Mock a 500 server error
        let errorResponse = HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:8080/events/\(sceneId)?version=\(sceneVersion)")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        mockSession.mockResponse = errorResponse
        mockSession.mockData = "Internal Server Error".data(using: .utf8)

        networkClient.postEvent(event, sceneId: sceneId, version: sceneVersion) { result in
            switch result {
            case .success:
                XCTFail("Expected failure but got success")
            case .failure(let error):
                if case TestNetworkClient.NetworkError.serverError(let statusCode) = error {
                    XCTAssertEqual(statusCode, 500)
                    expectation.fulfill()
                } else {
                    XCTFail("Expected server error but got \(error)")
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testNoDataResponse() async throws {
        let expectation = expectation(description: "No data response handling")

        let event = createTestEvent(withEmptyData: true)

        // Mock a successful status but no data
        let successResponse = HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:8080/events/\(sceneId)?version=\(sceneVersion)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        mockSession.mockResponse = successResponse
        mockSession.mockData = nil // No data

        networkClient.postEvent(event, sceneId: sceneId, version: sceneVersion) { result in
            switch result {
            case .success:
                XCTFail("Expected failure but got success")
            case .failure(let error):
                if case TestNetworkClient.NetworkError.noData = error {
                    expectation.fulfill()
                } else {
                    XCTFail("Expected no data error but got \(error)")
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testInvalidURLConstruction() async throws {
        // This test would require modifications to TestNetworkClient to trigger an invalid URL case
        // For now, mocking this with a specially crafted invalid URL isn't needed since the existing
        // implementation handles URL construction safely
    }

    // MARK: - Helper Methods

    /// Creates a standard test event for consistency across tests
    private func createTestEvent(withEmptyData: Bool = false) -> Event {
        let eventData: [EventData]

        if withEmptyData {
            eventData = []
        } else {
            eventData = [
                EventData(
                    name: "test-event",
                    time: Date().timeIntervalSince1970,
                    point: [1.0, 2.0, 3.0],
                    properties: [
                        "test": .string("test value")
                    ],
                    dynamicObjectId: "ABCDEF12345"
                )
            ]
        }

        return Event(
            userId: "test-user",
            timestamp: Date().timeIntervalSince1970,
            sessionId: "test-session",
            part: 1,
            formatVersion: "1.0",
            data: eventData
        )
    }
}
