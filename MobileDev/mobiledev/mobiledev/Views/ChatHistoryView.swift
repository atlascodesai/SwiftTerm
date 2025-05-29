import SwiftUI

struct ChatHistoryView: View {
    @StateObject private var chatManager = ChatManager.shared
    @State private var showArchived = false
    @State private var searchText = ""
    
    var filteredChats: [Chat] {
        let chats = showArchived ? chatManager.chats : chatManager.nonArchivedChats
        
        if searchText.isEmpty {
            return chats
        } else {
            return chats.filter { chat in
                chat.title.localizedCaseInsensitiveContains(searchText) ||
                chat.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Search bar
                searchBar
                
                // Chat list
                if filteredChats.isEmpty {
                    emptyStateView
                } else {
                    chatListView
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private var headerView: some View {
        HStack {
            Text("Chats")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // Archive toggle
            Button(action: { showArchived.toggle() }) {
                HStack {
                    Image(systemName: showArchived ? "archivebox.fill" : "archivebox")
                    Text(showArchived ? "Hide Archived" : "Show Archived")
                }
            }
            .buttonStyle(.bordered)
            
            // New chat button
            Button(action: createNewChat) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New Chat")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding()
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search chats...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
    
    private var chatListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filteredChats) { chat in
                    ChatRowView(chat: chat, onSelect: {
                        openChat(chat)
                    })
                    .contextMenu {
                        contextMenuItems(for: chat)
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "No chats yet" : "No chats found")
                .font(.title2)
                .foregroundColor(.secondary)
            
            if searchText.isEmpty {
                Button("Create your first chat", action: createNewChat)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func contextMenuItems(for chat: Chat) -> some View {
        if chat.state != .archived {
            Button(action: { archiveChat(chat) }) {
                Label("Archive", systemImage: "archivebox")
            }
        } else {
            Button(action: { unarchiveChat(chat) }) {
                Label("Unarchive", systemImage: "tray.and.arrow.up")
            }
        }
        
        Divider()
        
        Button(role: .destructive, action: { deleteChat(chat) }) {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func createNewChat() {
        let chat = chatManager.createNewChat()
        openChatWindows(for: chat)
    }
    
    private func openChat(_ chat: Chat) {
        if chat.state == .active {
            // Focus existing windows
            if let chatWindow = chatManager.getChatWindow(for: chat.id) {
                chatWindow.makeKeyAndOrderFront(nil)
            }
            if let terminalWindow = chatManager.getTerminalWindow(for: chat.id) {
                terminalWindow.orderFront(nil)
            }
        } else {
            // Open chat in read-only mode
            openChatWindow(for: chat, readOnly: true)
        }
    }
    
    private func openChatWindows(for chat: Chat) {
        // Open terminal window first
        openTerminalWindow(for: chat)
        
        // Then open chat window with a small delay to ensure terminal is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.openChatWindow(for: chat, readOnly: false)
        }
    }
    
    private func openChatWindow(for chat: Chat, readOnly: Bool) {
        let chatView = ChatView(chat: chat, isReadOnly: readOnly)
        let hostingController = NSHostingController(rootView: chatView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = chat.title
        window.setContentSize(NSSize(width: 600, height: 800))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        
        chatManager.registerChatWindow(window, for: chat.id)
        window.makeKeyAndOrderFront(nil)
        
        // Position window
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let origin = NSPoint(
                x: screenFrame.minX + 50,
                y: screenFrame.midY - window.frame.height / 2
            )
            window.setFrameOrigin(origin)
        }
    }
    
    private func openTerminalWindow(for chat: Chat) {
        let terminalView = ContentView(chatID: chat.id)
        let hostingController = NSHostingController(rootView: terminalView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "\(chat.title) - Terminal"
        window.setContentSize(NSSize(width: 1200, height: 800))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        
        chatManager.registerTerminalWindow(window, for: chat.id)
        window.orderFront(nil)
        
        // Position to the right of chat window
        if let chatWindow = chatManager.getChatWindow(for: chat.id) {
            let chatFrame = chatWindow.frame
            let origin = NSPoint(
                x: chatFrame.maxX + 20,
                y: chatFrame.minY
            )
            window.setFrameOrigin(origin)
        }
        
        // Set delegate to handle window close
        let delegate = TerminalWindowDelegate(chatID: chat.id)
        window.delegate = delegate
        
        // Keep a strong reference to the delegate
        objc_setAssociatedObject(window, "terminalDelegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    private func archiveChat(_ chat: Chat) {
        chatManager.archiveChat(chat.id)
    }
    
    private func unarchiveChat(_ chat: Chat) {
        var updatedChat = chat
        updatedChat.updateState(.inactive)
        chatManager.updateChat(updatedChat)
    }
    
    private func deleteChat(_ chat: Chat) {
        chatManager.closeAllWindows(for: chat.id)
        chatManager.deleteChat(chat.id)
    }
}

// MARK: - Chat Row View

struct ChatRowView: View {
    let chat: Chat
    let onSelect: () -> Void
    
    private var lastMessagePreview: String {
        if let lastMessage = chat.messages.last {
            return lastMessage.content
        } else {
            return "No messages yet"
        }
    }
    
    private var stateColor: Color {
        switch chat.state {
        case .active: return .green
        case .inactive: return .yellow
        case .archived: return .gray
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // State indicator
                Image(systemName: chat.state.symbolName)
                    .foregroundColor(stateColor)
                    .font(.system(size: 12))
                
                // Chat info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(chat.title)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(chat.lastActiveAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(lastMessagePreview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Arrow
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Terminal Window Delegate

class TerminalWindowDelegate: NSObject, NSWindowDelegate {
    let chatID: UUID
    
    init(chatID: UUID) {
        self.chatID = chatID
    }
    
    func windowWillClose(_ notification: Notification) {
        ChatManager.shared.terminalWindowClosed(for: chatID)
    }
}

// MARK: - Preview

struct ChatHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ChatHistoryView()
    }
}