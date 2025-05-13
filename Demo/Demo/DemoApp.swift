//
//  DemoApp.swift
//  Demo
//
//  Created by Yuki Kuwashima on 2025/02/14.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

@main
struct DemoApp: App {

    let googleAPIscopes: [String] = [
        "https://www.googleapis.com/auth/youtube",
        "https://www.googleapis.com/auth/youtube.readonly",
        "https://www.googleapis.com/auth/youtube.force-ssl"
    ]

    @State var isLoggedIn = false

    init() {
        GIDSignIn.sharedInstance.configuration = .init(
            clientID: "<your client id>"
        )
        GIDSignIn.sharedInstance.configure()
    }

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                NavigationStack {
                    ContentView()
                        .toolbar {
                            ToolbarItem {
                                Button("SignOut") {
                                    GIDSignIn.sharedInstance.signOut()
                                    isLoggedIn = false
                                }
                            }
                        }
                }
            } else {
                GoogleSignInButton {
                    if GIDSignIn.sharedInstance.currentUser != nil {
                        isLoggedIn = true
                    }
                    guard let presentingviewcontroller = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {return}
                    GIDSignIn.sharedInstance.signIn(
                        withPresenting: presentingviewcontroller,
                        hint: nil,
                        additionalScopes: googleAPIscopes
                    ) { signInResult, error in
                        guard signInResult != nil else {
                            return
                        }
                        isLoggedIn = true
                    }
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                    print("test")
                    if GIDSignIn.sharedInstance.currentUser != nil {
                        isLoggedIn = true
                    }
                }
                .task {
                    let user = try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
                    if user != nil {
                        isLoggedIn = true
                    }
                }
            }
        }
    }
}
