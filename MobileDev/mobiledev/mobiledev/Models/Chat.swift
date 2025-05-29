import Foundation

struct Chat: Identifiable, Codable {
    let id: UUID
    var title: String
    var state: ChatState
    var messages: [ChatMessage]
    var createdAt: Date
    var lastActiveAt: Date
    var terminalWindowID: Int?
    
    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.state = .active
        self.messages = []
        self.createdAt = Date()
        self.lastActiveAt = Date()
        self.terminalWindowID = nil
    }
    
    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        lastActiveAt = Date()
    }
    
    mutating func updateState(_ newState: ChatState) {
        state = newState
        lastActiveAt = Date()
    }
}

enum ChatState: String, Codable, CaseIterable {
    case active    // Has live terminal window
    case inactive  // Terminal closed, history preserved
    case archived  // User marked as completed/discarded
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .archived: return "Archived"
        }
    }
    
    var symbolName: String {
        switch self {
        case .active: return "circle.fill"
        case .inactive: return "circle.fill"
        case .archived: return "archivebox.fill"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "green"
        case .inactive: return "yellow"
        case .archived: return "gray"
        }
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let sender: MessageSender
    let timestamp: Date
    var isComplete: Bool
    
    init(content: String, sender: MessageSender, isComplete: Bool = true) {
        self.id = UUID()
        self.content = content
        self.sender = sender
        self.timestamp = Date()
        self.isComplete = isComplete
    }
}

enum MessageSender: String, Codable {
    case user
    case claude
    case system
    
    var isUser: Bool {
        self == .user
    }
}