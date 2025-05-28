# MobileDev Todo List

## Phase 1: Chat Management & Interface Foundation

### 1. Create Chat Management View (Entry Point)
- [ ] Create `ChatListView.swift` as the new app entry point
- [ ] Design chat list item component showing:
  - Chat title (auto-generated or custom)
  - Workspace/folder path
  - Last message preview
  - Timestamp
  - Active/Archived status indicator
- [ ] Implement "In Progress" section for active terminal sessions
- [ ] Implement "History" section for archived chats
- [ ] Add "New Chat" button/action
- [ ] Make view adaptive for iOS, iPadOS, and macOS

### 2. Create Chat Data Models
- [ ] Create `Chat` model:
  - ID, title, workspace path
  - Creation date, last updated
  - Status (active/archived)
  - Terminal session ID
- [ ] Create `ChatMessage` model:
  - Text content
  - Sender (user/claude)
  - Timestamp
  - Message type (text/option/status)
  - Optional interactive options
- [ ] Create `ChatStore` for managing multiple chats

### 3. Build Unified Chat Interface
- [ ] Create `ChatView.swift` that works across all platforms
- [ ] Implement message list with:
  - Message bubbles (user right, Claude left)
  - Timestamp display
  - Auto-scrolling to latest
- [ ] Add message input area:
  - Multi-line text field
  - Send button
  - Keyboard handling
- [ ] Integrate Claude state indicators (generating/ready/waiting)
- [ ] Add interactive option buttons (1, 2, 3) when detected

### 4. Terminal Integration Layer
- [ ] Create `ChatTerminalBridge` to connect chat with terminal
- [ ] Map chat messages to terminal commands
- [ ] Parse terminal output into chat messages
- [ ] Handle option selection → terminal input
- [ ] Sync Claude state to chat UI

## Phase 2: macOS-Specific Implementation

### 5. macOS Split View Layout
- [ ] Create `MacChatContainerView.swift`
- [ ] Implement split view:
  - Left: Chat interface
  - Right: Terminal view (existing SwiftUITerminalView)
- [ ] Add resizable divider
- [ ] Ensure terminal view updates reflect in chat

### 6. Multi-Session Support
- [ ] Modify `TerminalViewModel` to support multiple instances
- [ ] Create session management system
- [ ] Map each chat to its terminal instance
- [ ] Handle concurrent terminal operations

### 7. Chat Lifecycle Management
- [ ] Detect when Claude Code exits/terminal closes
- [ ] Auto-archive chat when session ends
- [ ] Prevent sending messages to archived chats
- [ ] Update UI to show archived state
- [ ] Clean up terminal resources

## Phase 3: Navigation & Polish

### 8. Navigation Structure
- [ ] Update `ContentView.swift` to use ChatListView as root
- [ ] Implement navigation from list to chat
- [ ] Add proper navigation stack handling
- [ ] Support deep linking to specific chats

### 9. Workspace Management
- [ ] Add manual workspace path setting
- [ ] Display workspace in chat header
- [ ] Group chats by workspace in list view
- [ ] Add workspace filtering/search

### 10. UI Polish & Testing
- [ ] Add loading states
- [ ] Implement error handling
- [ ] Add empty states
- [ ] Test on iOS, iPadOS, and macOS
- [ ] Ensure consistent behavior across platforms

## Phase 4: Data Persistence

### 11. Local Storage
- [ ] Implement chat persistence (CoreData or SwiftData)
- [ ] Save message history
- [ ] Preserve chat metadata
- [ ] Handle app termination/restart

### 12. State Restoration
- [ ] Restore active chats on app launch
- [ ] Reconnect to existing terminal sessions (if possible)
- [ ] Show appropriate state for disconnected sessions

## Backlog (Future Enhancements)

### iOS-Specific Features
- [ ] Remove terminal view for iOS
- [ ] Implement Firebase integration for message streaming
- [ ] Add push notification support
- [ ] Create remote terminal execution system

### Chat Continuity
- [ ] Generate chat summaries using Claude API
- [ ] "Continue from summary" feature
- [ ] Link archived chats to new sessions
- [ ] Preserve context between sessions

### Advanced Features
- [ ] Custom chat naming
- [ ] Chat search functionality
- [ ] Export chat history
- [ ] Workspace auto-detection
- [ ] Rich message formatting (code blocks, etc.)
- [ ] File attachment support
- [ ] Share chat transcripts

### Quality of Life
- [ ] Keyboard shortcuts
- [ ] Quick actions (swipe to archive, etc.)
- [ ] Chat templates
- [ ] Favorite/pin important chats
- [ ] Tags and categories

## Success Criteria
- ✅ App launches to chat list view
- ✅ Can create new chats that spawn terminals
- ✅ Chat interface controls terminal seamlessly
- ✅ Multiple concurrent sessions work properly
- ✅ Chats auto-archive when terminal closes
- ✅ UI works consistently across iOS, iPadOS, and macOS
- ✅ macOS shows both chat and terminal views
- ✅ All existing terminal functionality preserved