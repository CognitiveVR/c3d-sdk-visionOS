//
//  TestNetworkClient.swift
//
//  Created by Manjit Bedi
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Network client for testing - this may get replaced with the production network client.
class TestNetworkClient {
    private let session: URLSessionProtocol
    private let baseURL: URL

    init(session: URLSessionProtocol = URLSession.shared, baseURL: URL = URL(string: "http://127.0.0.1:8080")!) {
        self.session = session
        self.baseURL = baseURL
    }

    func postEvent(
        _ event: Event, sceneId: String, version: String, completion: @escaping (Result<Data, Error>) -> Void
    ) {
        // Construct URL with format: [baseURL]/event/[sceneid]?version=[sceneversion]
        var components = URLComponents(
            url: baseURL.appendingPathComponent("events").appendingPathComponent(sceneId), resolvingAgainstBaseURL: true
        )
        components?.queryItems = [URLQueryItem(name: "version", value: version)]

        guard let url = components?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(event)

            // Debug prints
            print("Sending request to URL: \(url.absoluteString)")
            print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
            if let body = request.httpBody, let str = String(data: body, encoding: .utf8) {
                print("Request body: \(str)")
            }

        } catch {
            completion(.failure(error))
            return
        }

        session.dataTask(with: request) { data, response, error in
            // Debug response
            print("Received response: \(String(describing: response))")
            if let error = error {
                print("Network error received: \(error)")
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type received")
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            print("Response status code: \(httpResponse.statusCode)")

            if let data = data, let str = String(data: data, encoding: .utf8) {
                print("Response body: \(str)")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NetworkError.serverError(statusCode: httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }

            completion(.success(data))
        }.resume()
    }

    enum NetworkError: Error {
        case invalidURL
        case invalidResponse
        case serverError(statusCode: Int)
        case noData
    }
}
