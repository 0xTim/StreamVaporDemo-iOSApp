import StreamChat
import StreamChatSwiftUI
import UIKit
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    
    // This is the `StreamChat` reference we need to add
    var streamChat: StreamChat?
    
    // This is the `chatClient`, with config we need to add
    var chatClient: ChatClient = {
        //For the tutorial we use a hard coded api key and application group identifier
        var config = ChatClientConfig(apiKey: .init("uykdzqamca7z"))
        
        // The resulting config is passed into a new `ChatClient` instance.
        let client = ChatClient(config: config)
        return client
    }()
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
                     [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // The `StreamChat` instance we need to assign
        LogConfig.level = .debug
        LogConfig.formatters = [
            PrefixLogFormatter(prefixes: [.info: "ℹ️", .debug: "🛠", .warning: "⚠️", .error: "🚨"])
        ]
        streamChat = StreamChat(chatClient: chatClient)
        return true
    }
    
    func connectUser(token: String, username: String, name: String) {
        let tokenObject = try! Token(rawValue: token)
        
        // Call `connectUser` on our SDK to get started.
        chatClient.connectUser(
            userInfo: .init(id: username,
                            name: name,
                            imageURL: URL(string: "https://vignette.wikia.nocookie.net/starwars/images/2/20/LukeTLJ.jpg")!),
            token: tokenObject
        ) { error in
            if let error = error {
                // Some very basic error handling only logging the error.
                log.error("connecting the user failed \(error)")
                return
            }
        }
    }
}
