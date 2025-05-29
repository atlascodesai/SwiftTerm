import SwiftUI

struct ChatView: View {
    let chatID: UUID
    let isReadOnly: Bool
    
    @StateObject private var chatManager = ChatManager.shared
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var isClaudeRunning = false
    @FocusState private var isInputFocused: Bool
    
    private var chat: Chat? {
        chatManager.chats.first(where: { $0.id == chatID })
    }
    
    init(chat: Chat, isReadOnly: Bool) {
        self.chatID = chat.id
        self.isReadOnly = isReadOnly
        self._viewModel = StateObject(wrappedValue: ChatViewModel(chatID: chat.id))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Messages
            messagesView
            
            // Input area (if not read-only)
            if !isReadOnly {
                Divider()
                inputView
            }
        }
        .frame(minWidth: 400, minHeight: 600)
        .onAppear {
            viewModel.startObserving()
            isInputFocused = true
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chat?.title ?? "Chat")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    if let chat = chat {
                        Image(systemName: chat.state.symbolName)
                            .foregroundColor(Color(chat.state.color))
                            .font(.system(size: 12))
                        
                        Text(chat.state.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if isReadOnly {
                        Text("• Read Only")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            if isClaudeRunning {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Claude is thinking...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Initial suggestion for new chats
                    if viewModel.messages.isEmpty && !isReadOnly {
                        initialSuggestionView
                    }
                    
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                            .contextMenu {
                                Button(action: { copyMessage(message) }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation {
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
            }
        }
    }
    
    private var initialSuggestionView: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text("Ready to start coding with Claude!")
                .font(.title2)
                .fontWeight(.medium)
            
            Button(action: launchClaude) {
                HStack {
                    Image(systemName: "terminal.fill")
                    Text("Launch Claude")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var inputView: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $messageText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }
                .disabled(isClaudeRunning || chat?.state != .active)
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
            .disabled(messageText.isEmpty || isClaudeRunning || chat?.state != .active)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func launchClaude() {
        viewModel.sendSystemAction(.launchClaude)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let message = messageText
        messageText = ""
        viewModel.sendMessage(message)
    }
    
    private func copyMessage(_ message: ChatMessage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage
    
    private var bubbleColor: Color {
        switch message.sender {
        case .user: return .accentColor
        case .claude: return Color(.systemGray).opacity(0.2)
        case .system: return .clear
        }
    }
    
    private var textColor: Color {
        switch message.sender {
        case .user: return .white
        case .claude: return .primary
        case .system: return .secondary
        }
    }
    
    private var alignment: HorizontalAlignment {
        message.sender == .user ? .trailing : .leading
    }
    
    var body: some View {
        HStack {
            if message.sender == .user { Spacer(minLength: 60) }
            
            VStack(alignment: alignment, spacing: 4) {
                if message.sender == .system {
                    // System messages are centered and italic
                    Text(message.content)
                        .font(.caption)
                        .italic()
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    // Regular message bubble
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(textColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(bubbleColor)
                        .cornerRadius(18)
                        .textSelection(.enabled)
                    
                    // Timestamp
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                }
            }
            
            if message.sender != .user { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Chat View Model

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isWaitingForResponse = false
    
    private let chatID: UUID
    private var terminalObserver: TerminalOutputObserver?
    
    init(chatID: UUID) {
        self.chatID = chatID
        loadMessages()
    }
    
    func startObserving() {
        // Set up terminal output observation
        terminalObserver = TerminalOutputObserver(chatID: chatID) { [weak self] output in
            self?.handleTerminalOutput(output)
        }
    }
    
    func stopObserving() {
        terminalObserver = nil
    }
    
    func sendMessage(_ text: String) {
        // Add user message
        let userMessage = ChatMessage(content: text, sender: .user)
        messages.append(userMessage)
        ChatManager.shared.addMessage(to: chatID, content: text, sender: .user)
        
        // Send to terminal
        if let terminalBridge = TerminalBridge.shared.getBridge(for: chatID) {
            Task { @MainActor in
                terminalBridge.sendCommand(text)
            }
            isWaitingForResponse = true
        }
    }
    
    func sendSystemAction(_ action: SystemAction) {
        switch action {
        case .launchClaude:
            if let terminalBridge = TerminalBridge.shared.getBridge(for: chatID) {
                Task { @MainActor in
                    terminalBridge.launchClaude()
                }
                
                let systemMessage = ChatMessage(
                    content: "Launching Claude...",
                    sender: .system
                )
                messages.append(systemMessage)
                ChatManager.shared.addMessage(to: chatID, content: systemMessage.content, sender: .system)
            }
        }
    }
    
    private func loadMessages() {
        if let chat = ChatManager.shared.chats.first(where: { $0.id == chatID }) {
            messages = chat.messages
        }
    }
    
    private func handleTerminalOutput(_ output: String) {
        // Parse Claude responses and update chat
        if output.contains("Claude:") || isWaitingForResponse {
            let claudeMessage = ChatMessage(content: output, sender: .claude)
            messages.append(claudeMessage)
            ChatManager.shared.addMessage(to: chatID, content: output, sender: .claude)
            isWaitingForResponse = false
        }
    }
}

enum SystemAction {
    case launchClaude
}

// MARK: - Terminal Output Observer

class TerminalOutputObserver {
    let chatID: UUID
    let onOutput: (String) -> Void
    
    init(chatID: UUID, onOutput: @escaping (String) -> Void) {
        self.chatID = chatID
        self.onOutput = onOutput
        // This would connect to the actual terminal output stream
    }
}

// MARK: - Preview

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(chat: Chat(title: "Test Chat"), isReadOnly: false)
    }
}