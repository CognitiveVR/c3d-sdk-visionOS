import Foundation

/// Environment configuration for network endpoints
internal enum NetworkEnvironment {
    case production
    case staging
    case dev

    /// Current environment determined by build configuration
    static var current: NetworkEnvironment {
        guard let environmentString = Bundle.main.object(forInfoDictionaryKey: "API_ENVIRONMENT") as? String else {
            return .production
        }

        switch environmentString.lowercased() {
        case "staging":
            return .staging
        case "dev", "development":
            return .dev
        default:
            return .production
        }
    }

    /// Base URL for the API endpoints
    var baseURL: String {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String else {
            switch self {
            case .production:
                return "https://data.cognitive3d.com/v0"
            case .staging:
                return "https://data.c3ddev.com/v0"
            case .dev:
                return "https://data.cognitive3d.com/v0"
            }
        }
        return urlString
    }

    func constructExitPollURL(questionSetName: String, version: Int) -> URL? {
        // Ensure baseURL is a valid URL
        guard let baseURL = URL(string: baseURL) else {
            return nil
        }

        // Properly construct URL with path only (no query parameters)
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path += "/questionSets/\(questionSetName)/\(version)/responses"
        return components?.url
    }

    func constructGazeURL(sceneId: String, version: Int) -> URL? {
        guard let baseURL = URL(string: baseURL) else {
            return nil
        }

        // Properly separate path and query parameters
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path += "/gaze/\(sceneId)"
        components?.query = "version=\(version)"
        return components?.url
    }

    func constructSensorsURL(sceneId: String, version: Int) -> URL? {
        guard let baseURL = URL(string: baseURL) else {
            return nil
        }

        // Properly separate path and query parameters
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path += "/sensors/\(sceneId)"
        components?.query = "version=\(version)"
        return components?.url
    }

    func constructDynamicObjectsURL(sceneId: String, version: Int) -> URL? {
        guard let baseURL = URL(string: baseURL) else {
            return nil
        }

        // Properly separate path and query parameters
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path += "/dynamics/\(sceneId)"
        components?.query = "version=\(version)"
        return components?.url
    }

    func constructEventsURL(sceneId: String, version: Int) -> URL? {
        guard let baseURL = URL(string: baseURL) else {
            return nil
        }

        // Properly separate path and query parameters
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path += "/events/\(sceneId)"
        components?.query = "version=\(version)"
        return components?.url
    }
}
