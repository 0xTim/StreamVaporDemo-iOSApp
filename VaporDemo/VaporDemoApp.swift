//
//  VaporDemoApp.swift
//  VaporDemo
//
//  Created by Tim Condon on 20/04/2022.
//

import SwiftUI
import StreamChat
import StreamChatSwiftUI

@main
struct VaporDemoApp: App {
    
    static let apiHostname = "http://localhost:8080"
    
    @StateObject
    var auth = Auth(apiHostname: VaporDemoApp.apiHostname)
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        return WindowGroup {
            if auth.isLoggedIn {
                ChatChannelListView()
                    .environmentObject(auth)
            } else {
                LoginView(apiHostname: VaporDemoApp.apiHostname).environmentObject(auth)
            }
        }
    }
}
