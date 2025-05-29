import Foundation
import SwiftUI

class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    @Published var chats: [Chat] = []
    @Published var activeChatsCount: Int = 0
    
    private let saveURL: URL
    private var terminalWindows: [UUID: NSWindow] = [:]
    private var chatWindows: [UUID: NSWindow] = [:]
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("MobileDev", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        self.saveURL = appFolder.appendingPathComponent("chats.json")
        loadChats()
        updateActiveChatCount()
    }
    
    // MARK: - Chat Management
    
    func createNewChat(title: String? = nil) -> Chat {
        let chat = Chat(title: title ?? "Chat \(chats.count + 1)")
        chats.insert(chat, at: 0)
        saveChats()
        updateActiveChatCount()
        return chat
    }
    
    func updateChat(_ chat: Chat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[index] = chat
            saveChats()
            updateActiveChatCount()
        }
    }
    
    func archiveChat(_ chatID: UUID) {
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].updateState(.archived)
            saveChats()
            updateActiveChatCount()
        }
    }
    
    func deleteChat(_ chatID: UUID) {
        chats.removeAll(where: { $0.id == chatID })
        saveChats()
        updateActiveChatCount()
    }
    
    // MARK: - Window Management
    
    func registerTerminalWindow(_ window: NSWindow, for chatID: UUID) {
        terminalWindows[chatID] = window
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].terminalWindowID = Int(window.windowNumber)
        }
    }
    
    func registerChatWindow(_ window: NSWindow, for chatID: UUID) {
        chatWindows[chatID] = window
    }
    
    func terminalWindowClosed(for chatID: UUID) {
        terminalWindows.removeValue(forKey: chatID)
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].updateState(.inactive)
            chats[index].terminalWindowID = nil
            
            // Add system message
            let systemMessage = ChatMessage(
                content: "Terminal session closed",
                sender: .system
            )
            chats[index].addMessage(systemMessage)
            saveChats()
            updateActiveChatCount()
        }
    }
    
    func closeAllWindows(for chatID: UUID) {
        terminalWindows[chatID]?.close()
        chatWindows[chatID]?.close()
        terminalWindows.removeValue(forKey: chatID)
        chatWindows.removeValue(forKey: chatID)
    }
    
    func getTerminalWindow(for chatID: UUID) -> NSWindow? {
        return terminalWindows[chatID]
    }
    
    func getChatWindow(for chatID: UUID) -> NSWindow? {
        return chatWindows[chatID]
    }
    
    // MARK: - Message Management
    
    func addMessage(to chatID: UUID, content: String, sender: MessageSender) {
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            let message = ChatMessage(content: content, sender: sender)
            chats[index].addMessage(message)
            saveChats()
        }
    }
    
    func updateLastMessage(for chatID: UUID, content: String) {
        if let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
           let lastMessageIndex = chats[chatIndex].messages.lastIndex(where: { $0.sender == .claude }) {
            chats[chatIndex].messages[lastMessageIndex] = ChatMessage(
                content: content,
                sender: .claude,
                isComplete: true
            )
            saveChats()
        }
    }
    
    // MARK: - Queries
    
    var activeChats: [Chat] {
        chats.filter { $0.state == .active }
    }
    
    var inactiveChats: [Chat] {
        chats.filter { $0.state == .inactive }
    }
    
    var archivedChats: [Chat] {
        chats.filter { $0.state == .archived }
    }
    
    var nonArchivedChats: [Chat] {
        chats.filter { $0.state != .archived }
    }
    
    // MARK: - Persistence
    
    private func saveChats() {
        do {
            let data = try JSONEncoder().encode(chats)
            try data.write(to: saveURL)
        } catch {
            print("Failed to save chats: \(error)")
        }
    }
    
    private func loadChats() {
        do {
            let data = try Data(contentsOf: saveURL)
            chats = try JSONDecoder().decode([Chat].self, from: data)
            
            // Mark all as inactive on launch (terminals are gone)
            for index in chats.indices {
                if chats[index].state == .active {
                    chats[index].updateState(.inactive)
                }
            }
        } catch {
            print("Failed to load chats: \(error)")
            chats = []
        }
    }
    
    private func updateActiveChatCount() {
        activeChatsCount = activeChats.count
    }
}