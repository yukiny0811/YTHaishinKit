//
//  ContentView.swift
//  Demo
//
//  Created by Yuki Kuwashima on 2025/02/14.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import YTHaishinKit

struct ContentView: View {

    @State var broadcastId: String?
    @State var rtmpId: String?
    @State var privacyStatus: YTHaishinKit.PrivacyStatus = .unlisted
    @State var title = "Title"
    @State var description = "Description"

    @State var comments: [YTHaishinKit.Comment] = []

    var body: some View {
        List {
            if broadcastId == nil {
                Section("作成") {
                    TextField("title", text: $title)
                    TextField("description", text: $description)
                    Picker("Picker", selection: $privacyStatus) {
                        ForEach(YTHaishinKit.PrivacyStatus.allCases, id: \.rawValue) { status in
                            Text(status.rawValue)
                                .tag(status)
                        }
                    }
                    Button("new youtube live") {
                        Task {
                            do {
                                let result = try await YTHaishinKit.createBroadcastAndBind(
                                    token: GIDSignIn.sharedInstance.currentUser!.accessToken.tokenString,
                                    title: title,
                                    description: description,
                                    privacyStatus: privacyStatus
                                )
                                self.broadcastId = result.broadcastId
                                self.rtmpId = result.rtmpId
                                print("BROADCAST ID", broadcastId ?? "")
                                print("RTMP ID", rtmpId ?? "")
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }
                }
            }
            if let broadcastId {
                Section("Broadcast Settings") {
                    Button("test") {
                        Task {
                            do {
                                try await YTHaishinKit.testLiveStream(broadcastId: broadcastId, accessToken: GIDSignIn.sharedInstance.currentUser!.accessToken.tokenString)
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }
                    Button("live") {
                        Task {
                            do {
                                try await YTHaishinKit.startLiveStream(broadcastId: broadcastId, accessToken: GIDSignIn.sharedInstance.currentUser!.accessToken.tokenString)
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }
                    Button("Stop stream", role: .destructive) {
                        Task {
                            do {
                                try await YTHaishinKit.stopLiveStream(broadcastId: broadcastId, accessToken: GIDSignIn.sharedInstance.currentUser!.accessToken.tokenString)
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }
                    Button("fetch state") {
                        Task {
                            do {
                                let result = try await YTHaishinKit.fetchBroadcastState(broadcastId: broadcastId, accessToken: GIDSignIn.sharedInstance.currentUser!.accessToken.tokenString)
                                print(result)
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }
                }
                Section("Comments") {
                    Button("Poll comments") {
                        Task {
                            do {
                                try await YTHaishinKit.pollLiveChat(broadcastId: broadcastId, accessToken: GIDSignIn.sharedInstance.currentUser!.accessToken.tokenString, comments: $comments)
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }
                    ForEach(comments, id: \.hashValue) { comment in
                        HStack {
                            Text(comment.author)
                            Text(comment.message)
                        }
                    }
                }
            }
        }
    }
}
