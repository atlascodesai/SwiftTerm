//
//  mobiledevApp.swift
//  mobiledev
//
//  Created by 🍋💻 on 25/05/2025.
//

import SwiftUI

@main
struct mobiledevApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ChatHistoryView()
        }
        
        // Additional window groups for chat and terminal windows
        WindowGroup("Chat", for: UUID.self) { $chatID in
            if let chatID = chatID,
               let chat = ChatManager.shared.chats.first(where: { $0.id == chatID }) {
                ChatView(chat: chat, isReadOnly: chat.state != .active)
            }
        }
        
        WindowGroup("Terminal", for: UUID.self) { $chatID in
            if let chatID = chatID {
                ContentView(chatID: chatID)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let activeCount = ChatManager.shared.activeChatsCount
        
        if activeCount > 0 {
            let alert = NSAlert()
            alert.messageText = "Active Sessions"
            alert.informativeText = "You have \(activeCount) active terminal session\(activeCount > 1 ? "s" : ""). Are you sure you want to quit?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
        }
        
        return .terminateNow
    }
}
