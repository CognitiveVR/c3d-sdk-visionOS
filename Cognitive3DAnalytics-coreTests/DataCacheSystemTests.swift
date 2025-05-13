import XCTest
@testable import Cognitive3DAnalytics

/// Mock DataCacheDelegate implementation for testing
class MockDataCacheDelegate: DataCacheDelegate {
    var requestCount = 0
    var lastRequestUrl: URL?
    var lastRequestBody: Data?
    var shouldSucceed = true

    func uploadCachedRequest(url: URL, body: Data, completion: @escaping (Bool) -> Void) {
        requestCount += 1
        lastRequestUrl = url
        lastRequestBody = body

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion(self.shouldSucceed)
        }
    }

    func isValidResponse(_ response: HTTPURLResponse) -> Bool {
        // Check for the cvr-request-time header
        return response.allHeaderFields["cvr-request-time"] != nil
    }
}

/// Unit tests for the DataCacheSystem architecture
final class DataCacheSystemTests: XCTestCase {

    // Test components
    var cacheSystem: DataCacheSystem!
    var mockDelegate: MockDataCacheDelegate!
    var tempDirectory: String!

    override func setUp() {
        super.setUp()
        // Create a temporary directory for cache files
        tempDirectory = createTempDirectory(prefix: "CacheTest")
    }

    override func tearDown() {
        // Clean up temporary directory
        cleanupDirectory(tempDirectory)
        super.tearDown()
    }

    // MARK: - Async Setup Helper

    func setupCacheSystem() async throws -> (DataCacheSystem, MockDataCacheDelegate) {
        // Initialize the cache system with proper await
        let system = DataCacheSystem()

        // Set up cache path
        try await system.setCachePath(tempDirectory)

        // Create delegate
        let delegate = MockDataCacheDelegate()

        // Set the delegate with proper await
        await system.setDelegate(delegate)

        return (system, delegate)
    }

    // MARK: - Basic Tests

    func testInitialization() async throws {
        // Set up system with proper await
        (cacheSystem, _) = try await setupCacheSystem()

        // Verify system is initialized correctly
        // Properly await access to actor-isolated properties
        let cacheExists = await cacheSystem.cache != nil
        XCTAssertTrue(cacheExists)

        if let cache = await cacheSystem.cache {
            let hasContent = cache.hasContent()
            XCTAssertFalse(hasContent)
        }
    }

    func testInvalidCachePath() async throws {
        // Create system without setting path
        let system = DataCacheSystem()

        // Try invalid path
        do {
            try await system.setCachePath("/nonexistent/directory/")
            XCTFail("Should have thrown error for invalid path")
        } catch {
            XCTAssertTrue(error is DataCacheSystemError)
        }
    }

    // MARK: - Caching Tests

    func testCacheRequest() async throws {
        // Set up system
        (cacheSystem, _) = try await setupCacheSystem()

        // Create test data
        let url = URL(string: "https://data.c3ddev.com/v0/events/1234-1234-1234-1234?version=0")!
        let testData = createTestEventPayload()

        // Cache the request
        await cacheSystem.cacheRequest(url: url, body: testData)

        // Verify content was cached
        if let cache = await cacheSystem.cache {
            let hasContent = cache.hasContent()
            XCTAssertTrue(hasContent)

            let batchCount = cache.numberOfBatches()
            XCTAssertEqual(batchCount, 1)

            // Verify content is correct
            var cachedUrl = ""
            var cachedBody = ""
            let success = cache.peekContent(destination: &cachedUrl, body: &cachedBody)

            XCTAssertTrue(success)
            XCTAssertEqual(cachedUrl, url.absoluteString)
            XCTAssertTrue(cachedBody.contains("test_event"))
        }
    }

    // MARK: - Request Handling Tests

    func testHandleRequest() async throws {
        // Set up system
        (cacheSystem, mockDelegate) = try await setupCacheSystem()

        // Configure delegate
        mockDelegate.shouldSucceed = true

        // Create test data
        let url = URL(string: "https://data.c3ddev.com/v0/events/1234-1234-1234-1234?version=0")!
        let testData = createTestEventPayload()

        // Handle request
        let success = await cacheSystem.handleRequest(url: url, body: testData)

        // Verify results
        XCTAssertTrue(success)
        XCTAssertEqual(mockDelegate.requestCount, 1)
        XCTAssertEqual(mockDelegate.lastRequestUrl, url)

        // Properly await access to actor-isolated properties
        if let cache = await cacheSystem.cache {
            let hasContent = cache.hasContent()
            XCTAssertFalse(hasContent)
        }
    }

    func testHandleRequestFailure() async throws {
        // Set up system
        (cacheSystem, mockDelegate) = try await setupCacheSystem()

        // Configure delegate to fail
        mockDelegate.shouldSucceed = false

        // Create test data
        let url = URL(string: "https://data.c3ddev.com/v0/events/1234-1234-1234-1234?version=0")!
        let testData = createTestEventPayload()

        // Handle request
        let success = await cacheSystem.handleRequest(url: url, body: testData)

        // Verify results
        XCTAssertFalse(success)
        XCTAssertEqual(mockDelegate.requestCount, 1)

        // Properly await access to actor-isolated properties
        if let cache = await cacheSystem.cache {
            let hasContent = cache.hasContent()
            XCTAssertTrue(hasContent)
        }
    }

    // MARK: - Specific Data Type Tests
    // TODO:  this test is not complete
    func testSendExitPollAnswers() async throws {
        // Set up system
        (cacheSystem, mockDelegate) = try await setupCacheSystem()

        // Configure delegate
        mockDelegate.shouldSucceed = true

        // Create test data
        let testData = createTestEventPayload()

        // Send exit poll answers
        let success = await cacheSystem.sendExitPollAnswers(questionSetName: "basic", version: 0, pollData: testData)

        // Verify results
        XCTAssertTrue(success)
        XCTAssertEqual(mockDelegate.requestCount, 1)

        // Get the exit poll URL from your actual code
        let actualUrlString = mockDelegate.lastRequestUrl?.absoluteString
        XCTAssertNotNil(actualUrlString)

        // Use the actual URL from your code
        // Commented out to avoid making up a URL
        // XCTAssertEqual(actualUrlString, "your_actual_url_here")
    }

    // MARK: - Upload Cached Content Tests

    func testUploadCachedContent() async throws {
        // Set up system
        (cacheSystem, mockDelegate) = try await setupCacheSystem()

        // Configure delegate
        mockDelegate.shouldSucceed = true

        // Cache some data
        let url = URL(string: "https://data.c3ddev.com/v0/events/1234-1234-1234-1234?version=0")!
        let testData = createTestEventPayload()
        await cacheSystem.cacheRequest(url: url, body: testData)

        // Verify content was cached
        var initialHasContent = false
        if let cache = await cacheSystem.cache {
            initialHasContent = cache.hasContent()
        }
        XCTAssertTrue(initialHasContent)

        // Upload cached content
        await cacheSystem.uploadCachedContent()

        // Wait a bit for the async operations to finish
        try await Task.sleep(nanoseconds: 500_000_000)

        // Verify results
        XCTAssertEqual(mockDelegate.requestCount, 1)

        var finalHasContent = true
        if let cache = await cacheSystem.cache {
            finalHasContent = cache.hasContent()
        }
        XCTAssertFalse(finalHasContent)
    }
}
