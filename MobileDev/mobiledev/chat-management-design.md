# Chat Management System Design

## Overview
This document outlines the design for a chat management system that provides a modern messaging interface for Claude Code terminal sessions. Each chat session has a paired terminal window, creating a dual-window experience where users interact through a friendly chat UI while seeing raw terminal output in a separate window.

## Architecture

### Core Components

1. **ChatManager** (Singleton)
   - Manages all chat sessions
   - Tracks chat-terminal window pairs
   - Handles session lifecycle
   - Persists chat history

2. **Chat Model**
   ```swift
   struct Chat: Identifiable, Codable {
       let id: UUID
       var title: String
       var state: ChatState
       var messages: [ChatMessage]
       var createdAt: Date
       var lastActiveAt: Date
       var terminalWindowID: NSWindow.WindowNumber?
   }
   
   enum ChatState: String, Codable {
       case active    // Has live terminal window
       case inactive  // Terminal closed, history preserved
       case archived  // User marked as completed/discarded
   }
   ```

3. **ChatMessage Model**
   ```swift
   struct ChatMessage: Identifiable, Codable {
       let id: UUID
       let content: String
       let sender: MessageSender
       let timestamp: Date
       let isComplete: Bool  // For streaming responses
   }
   
   enum MessageSender: String, Codable {
       case user
       case claude
       case system  // For status messages like "Terminal closed"
   }
   ```

### Views

1. **ChatHistoryView** (Main Landing)
   - Lists all chats with status indicators
   - "New Chat" button
   - Search/filter functionality
   - Shows chat title, last message preview, timestamp
   - Color-coded state indicators:
     - 🟢 Green: Active
     - 🟡 Yellow: Inactive
     - 📁 Gray: Archived

2. **ChatView** (Messaging Interface)
   - Modern bubble UI (user right/blue, Claude left/gray)
   - Input field at bottom
   - Suggested actions (e.g., "Launch Claude" button)
   - Copy message functionality
   - Read-only mode for inactive chats
   - Shows "Terminal Closed" banner for inactive

3. **TerminalWindowController**
   - Manages terminal window lifecycle
   - Notifies ChatManager on window close
   - Maintains reference to paired chat

## User Flows

### Creating a New Chat
1. User clicks "New Chat" in ChatHistoryView
2. System creates new Chat instance
3. Opens ChatView window
4. Opens paired TerminalView window
5. Suggests "Launch Claude" action in chat
6. User interaction begins

### Chat Lifecycle
```
Active (🟢) → User interacts normally
     ↓
     ├── Terminal window closed by user
     ├── Terminal process crashes
     └── All windows closed
     ↓
Inactive (🟡) → Read-only chat history
     ↓
     └── User archives chat
     ↓
Archived (📁) → Hidden from main view
```

### Multi-Session Management
- Each "New Chat" creates independent session
- Multiple active chats can run simultaneously
- Each has its own Claude process and working directory
- Windows are positioned intelligently (cascade/tile)

## Implementation Details

### Window Pairing
```swift
class ChatWindowPair {
    let chatWindow: NSWindow
    let terminalWindow: NSWindow
    let chatID: UUID
    
    func positionWindows() {
        // Position terminal to right of chat
        // Or use cascade positioning
    }
}
```

### State Management
- Active → Inactive: Automatic on terminal close
- Inactive → Active: Not possible (start new chat)
- Any → Archived: Manual user action
- Archived → Any: Manual restore to inactive

### Quit Warning
```swift
func applicationShouldTerminate() -> NSApplication.TerminateReply {
    let activeCount = ChatManager.shared.activeChatsCount
    if activeCount > 0 {
        // Show alert: "You have X active sessions. Quit anyway?"
        // Options: [Cancel] [Quit]
    }
}
```

### Data Persistence
- Chats saved to: `~/Library/Application Support/MobileDev/chats.json`
- Auto-save on state changes
- Migration support for future schema changes

### Terminal Integration
- Reuse existing TerminalViewModel
- Bridge pattern for chat↔terminal communication
- Command queue for reliability
- Response parsing for chat display

## UI/UX Guidelines

### Chat Bubbles
- User messages: Right-aligned, blue background
- Claude messages: Left-aligned, gray background
- System messages: Center-aligned, italic, muted
- Timestamp on hover/long-press
- Copy on right-click/long-press

### Status Indicators
- Active: Green dot + "Active" label
- Inactive: Yellow dot + "Inactive" label
- Archived: No dot + "Archived" label
- Terminal connecting: Pulsing animation

### Responsive Design
- Minimum window size: 400x600
- Chat bubbles wrap appropriately
- Terminal window: Standard 80x24 minimum
- Support for macOS dark/light mode

## Error Handling

### Terminal Crashes
- Detect unexpected termination
- Mark chat as inactive
- Show error message in chat
- Preserve all history

### Window Management
- Handle window close events
- Prevent accidental data loss
- Graceful degradation
- Recovery suggestions

## Future Enhancements
- Session restore (reconnect to running Claude)
- Chat templates/presets
- Export chat as markdown
- Collaborative sessions
- Voice input/output
- Rich media in chat (images, code blocks)

## Success Metrics
- Window pair creation < 1 second
- State transitions are instant
- No data loss on crashes
- Intuitive navigation
- Clear visual states