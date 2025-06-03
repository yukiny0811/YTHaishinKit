//
//  File.swift
//  YTHaishinKit
//
//  Created by Yuki Kuwashima on 2025/05/13.
//

import Foundation
import SwiftUI

public enum YTHaishinKit {

    public enum PrivacyStatus: String, Codable, CaseIterable {
        case `private` = "private"
        case unlisted
        case `public` = "public"
    }

    public struct Comment: Codable, Hashable, Equatable {
        public var author: String
        public var message: String
        public init(author: String, message: String) {
            self.author = author
            self.message = message
        }
    }

    public static func fetchBroadcastState(
        broadcastId: String,
        accessToken: String
    ) async throws -> [String: Any] {
        var comp = URLComponents(string: "https://www.googleapis.com/youtube/v3/liveBroadcasts")!
        comp.queryItems = [
            URLQueryItem(name: "part", value: "snippet,status"),
            URLQueryItem(name: "id", value: broadcastId)
        ]
        var req = URLRequest(url: comp.url!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String:Any] else {
            throw NSError()
        }
        return json
    }

    public static func testLiveStream(
        broadcastId: String,
        accessToken: String
    ) async throws {
        try await transitionBroadcast(broadcastId: broadcastId, to: "testing", accessToken: accessToken)
        print("test done!")
    }

    /// required to call testLiveStream and wait for a few seconds.
    public static func startLiveStream(
        broadcastId: String,
        accessToken: String
    ) async throws {
        try await transitionBroadcast(broadcastId: broadcastId, to: "live", accessToken: accessToken)
        print("live start!")
    }

    public static func stopLiveStream(
        broadcastId: String,
        accessToken: String
    ) async throws {
        try await transitionBroadcast(broadcastId: broadcastId, to: "complete", accessToken: accessToken)
        print("live stopped!")
    }

    public static func createBroadcastAndBind(token: String, title: String, description: String, privacyStatus: PrivacyStatus) async throws -> (broadcastId: String, rtmpId: String) {
        let streamData = try await createLiveStream(title: title, description: description, accessToken: token)
        let start = Date().addingTimeInterval(1)
        let end   = Date().addingTimeInterval(3600 + 60)
        let broadcastData = try await createLiveBroadcast(
            title: title, description: description,
            scheduledStart: start, scheduledEnd: end,
            privacyStatus: privacyStatus.rawValue,
            accessToken: token
        )
        try await bindBroadcastToStream(
            broadcastId: broadcastData["id"] as! String,
            streamId: streamData["id"] as! String,
            accessToken: token
        )
        print("配信準備完了！")
        guard let broadcastId = broadcastData["id"] as? String else {
            throw NSError()
        }
        guard let cdn = streamData["cdn"] as? [String: Any] else {
            throw NSError()
        }
        guard let ingestionInfo = cdn["ingestionInfo"] as? [String: Any] else {
            throw NSError()
        }
        guard let streamName = ingestionInfo["streamName"] as? String else {
            throw NSError()
        }
        print("broadcast created")
        return (broadcastId, streamName)
    }

    public static func pollLiveChat(
        broadcastId: String,
        accessToken: String,
        comments: Binding<[Comment]>
    ) async throws {
        print("chat poll start!")
        let liveChatId = try await fetchLiveChatId(
            broadcastId: broadcastId,
            accessToken: accessToken
        )
        var nextPageToken: String? = nil
        while true {
            let resp = try await fetchLiveChatMessages(
                liveChatId: liveChatId,
                pageToken: nextPageToken,
                accessToken: accessToken
            )
            for msg in resp.items {
                comments.wrappedValue.append(Comment(author: msg.authorDetails.displayName, message: msg.snippet.displayMessage))
                print("[\(msg.authorDetails.displayName)] \(msg.snippet.displayMessage)")
            }
            nextPageToken = resp.nextPageToken
            let intervalMs = resp.pollingIntervalMillis ?? 5000
            try await Task.sleep(nanoseconds: UInt64(intervalMs) * 1_000_000)
        }
    }
}

// private functions
extension YTHaishinKit {
    private static func transitionBroadcast(
        broadcastId: String,
        to status: String,
        accessToken: String
    ) async throws {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/liveBroadcasts/transition")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "status"),
            URLQueryItem(name: "broadcastStatus", value: status),
            URLQueryItem(name: "id", value: broadcastId)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "YouTubeAPI",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    private static func makeJSONRequest(
        url: URL,
        httpMethod: String,
        accessToken: String,
        jsonBody: [String: Any]?
    ) throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = httpMethod
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = jsonBody {
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        return req
    }

    private static func createLiveStream(
        title: String,
        description: String,
        resolution: String = "variable",
        frameRate: String = "variable",
        accessToken: String
    ) async throws -> [String: Any] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/liveStreams")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,cdn")
        ]

        let body: [String: Any] = [
            "snippet": [
                "title": title,
                "description": description
            ],
            "cdn": [
                "ingestionType": "rtmp",
                "resolution": resolution,
                "frameRate": frameRate
            ]
        ]
        let req = try makeJSONRequest(
            url: components.url!,
            httpMethod: "POST",
            accessToken: accessToken,
            jsonBody: body
        )
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "YouTubeAPI",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "parseerror", code: -1)
        }
        return parsed
    }

    private static func createLiveBroadcast(
        title: String,
        description: String,
        scheduledStart: Date,
        scheduledEnd: Date,
        privacyStatus: String,
        accessToken: String
    ) async throws -> [String: Any] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/liveBroadcasts")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,status")
        ]

        let body: [String: Any] = [
            "snippet": [
                "title": title,
                "description": description,
                "scheduledStartTime": ISO8601DateFormatter().string(from: scheduledStart),
                "scheduledEndTime":   ISO8601DateFormatter().string(from: scheduledEnd)
            ],
            "status": [
                "privacyStatus": privacyStatus,
                "selfDeclaredMadeForKids": false
            ]
        ]
        let req = try makeJSONRequest(
            url: components.url!,
            httpMethod: "POST",
            accessToken: accessToken,
            jsonBody: body
        )
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "YouTubeAPI",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "parseerror", code: -1)
        }
        return parsed
    }

    private static func bindBroadcastToStream(
        broadcastId: String,
        streamId: String,
        accessToken: String
    ) async throws {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/liveBroadcasts/bind")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "id"),
            URLQueryItem(name: "id", value: broadcastId),
            URLQueryItem(name: "streamId", value: streamId)
        ]

        let req = try makeJSONRequest(
            url: components.url!,
            httpMethod: "POST",
            accessToken: accessToken,
            jsonBody: nil
        )
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "YouTubeAPI",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    private static func makeAuthorizedRequest(url: URL, accessToken: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return req
    }

    private static func fetchLiveChatId(
        broadcastId: String,
        accessToken: String
    ) async throws -> String {
        var comp = URLComponents(string: "https://www.googleapis.com/youtube/v3/liveBroadcasts")!
        comp.queryItems = [
            .init(name: "part", value: "snippet"),
            .init(name: "id",   value: broadcastId)
        ]
        let (data, resp) = try await URLSession.shared.data(
            for: makeAuthorizedRequest(url: comp.url!, accessToken: accessToken)
        )
        let http = resp as! HTTPURLResponse
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw NSError(domain: "YouTubeAPI", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        let res = try JSONDecoder().decode(LiveBroadcastListResponse.self, from: data)
        guard let id = res.items.first?.snippet.liveChatId else {
            throw NSError(domain: "YouTubeAPI", code: -1,
                          userInfo: [NSLocalizedDescriptionKey:"liveChatId not found"])
        }
        return id
    }

    private struct LiveBroadcastListResponse: Codable {
        struct Item: Codable {
            struct Snippet: Codable { let liveChatId: String? }
            let snippet: Snippet
        }
        let items: [Item]
    }

    private struct LiveChatMessageListResponse: Codable {
        struct Message: Codable {
            let id: String
            struct Snippet: Codable {
                let displayMessage: String
                let publishedAt: String
            }
            let snippet: Snippet
            struct AuthorDetails: Codable {
                let displayName: String
            }
            let authorDetails: AuthorDetails
        }
        let items: [Message]
        let nextPageToken: String?
        let pollingIntervalMillis: Int?
    }

    private static func fetchLiveChatMessages(
        liveChatId: String,
        pageToken: String?,
        accessToken: String
    ) async throws -> LiveChatMessageListResponse {
        var comp = URLComponents(string: "https://www.googleapis.com/youtube/v3/liveChat/messages")!
        var qs = [
            URLQueryItem(name: "part",          value: "snippet,authorDetails"),
            URLQueryItem(name: "liveChatId",    value: liveChatId),
            URLQueryItem(name: "maxResults",    value: "200")
        ]
        if let token = pageToken {
            qs.append(.init(name: "pageToken", value: token))
        }
        comp.queryItems = qs

        let (data, resp) = try await URLSession.shared.data(
            for: makeAuthorizedRequest(url: comp.url!, accessToken: accessToken)
        )
        let http = resp as! HTTPURLResponse
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw NSError(domain: "YouTubeAPI", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return try JSONDecoder().decode(LiveChatMessageListResponse.self, from: data)
    }
}
