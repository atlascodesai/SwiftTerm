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
    
    func addMessage(to chatID: UUID, content: String, sender: MessageSender, messageType: MessageType = .text, metadata: MessageMetadata? = nil) {
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            let message = ChatMessage(content: content, sender: sender, messageType: messageType, metadata: metadata)
            chats[index].addMessage(message)
            saveChats()
        }
    }
    
    func addMessage(to chatID: UUID, message: ChatMessage) {
        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].addMessage(message)
            saveChats()
        }
    }
    
    func updateMessage(in chatID: UUID, messageId: UUID, content: String, messageType: MessageType? = nil, isStreaming: Bool? = nil) {
        if let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
           let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == messageId }) {
            
            var updatedMessage = chats[chatIndex].messages[messageIndex]
            updatedMessage.content = content
            
            if let type = messageType {
                updatedMessage.messageType = type
            }
            
            if let streaming = isStreaming {
                updatedMessage.isStreaming = streaming
            }
            
            chats[chatIndex].messages[messageIndex] = updatedMessage
            
            // Don't save while streaming to avoid excessive disk writes
            if !(isStreaming ?? false) {
                saveChats()
            }
        }
    }
    
    /// Add a structured message from streaming parser
    func addStreamMessage(to chatID: UUID, streamMessage: StreamMessage, sender: MessageSender) {
        let (messageType, metadata) = convertStreamMessageType(streamMessage)
        let formattedContent = formatStreamMessage(streamMessage)
        
        print("📋 ChatManager: Adding stream message - Type: \(messageType), Tool: \(metadata?.toolName ?? "none")")
        print("   Content: '\(formattedContent.prefix(100))...'")
        
        addMessage(to: chatID, content: formattedContent, sender: sender, messageType: messageType, metadata: metadata)
    }
    
    private func convertStreamMessageType(_ message: StreamMessage) -> (MessageType, MessageMetadata?) {
        switch message.type {
        case .text:
            return (.text, nil)
        case .bashCommand:
            return (.toolUse, MessageMetadata(toolName: "bash"))
        case .fileOperation:
            return (.toolUse, MessageMetadata(toolName: "file"))
        case .codeBlock:
            return (.code, MessageMetadata(language: "swift"))  // Would need to parse language
        case .error:
            return (.error, nil)
        case .success, .warning, .progress:
            return (.status, MessageMetadata(statusType: String(describing: message.type)))
        default:
            return (.text, nil)
        }
    }
    
    private func formatStreamMessage(_ message: StreamMessage) -> String {
        switch message.type {
        case .bashCommand:
            return "$ " + message.cleanContent
        case .fileOperation:
            return "📄 " + message.cleanContent
        case .success:
            return "✅ " + message.cleanContent
        case .error:
            return "❌ " + message.cleanContent
        case .warning:
            return "⚠️ " + message.cleanContent
        default:
            return message.content  // Keep ANSI codes for text
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