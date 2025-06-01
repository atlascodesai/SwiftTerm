import SwiftUI
import Combine

struct ChatView: View {
    let chatID: UUID
    let isReadOnly: Bool
    
    @StateObject private var chatManager = ChatManager.shared
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var isClaudeRunning = false
    @State private var isClaudeThinking = false
    @State private var claudeState = ""
    @State private var detectedOptions: [String] = []
    @State private var optionsRequireTextInput = false
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
            
            // Option buttons when detected
            if !detectedOptions.isEmpty && isClaudeRunning && !isClaudeThinking {
                Divider()
                optionButtonsView
            }
            
            // Debug: Show current state
            if !detectedOptions.isEmpty {
                Text("DEBUG: Options=\(detectedOptions.count), Claude=\(isClaudeRunning), Thinking=\(isClaudeThinking)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(2)
            }
            
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
            
            // Set up bridge observation
            setupBridgeObservation()
            
            // Update Claude states with initial polling and fallback
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                let states = viewModel.getBridgeStates()
                isClaudeRunning = states.isRunning
                isClaudeThinking = states.isThinking
                claudeState = states.state
                
                // Check for option changes
                if detectedOptions != states.options {
                    detectedOptions = states.options
                    optionsRequireTextInput = states.optionsRequireText
                    print("🎯 ChatView: Options updated: \(detectedOptions)")
                    print("📝 ChatView: Options require text: \(optionsRequireTextInput)")
                }
            }
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
                    if isClaudeThinking {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(claudeState)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        Text(claudeState.isEmpty ? "Claude is ready" : claudeState)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
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
                        if !isClaudeRunning {
                            // Show launch button
                            initialSuggestionView
                        }
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
    
    private var optionButtonsView: some View {
        VStack(spacing: 8) {
            // Show hint about selection method
            if optionsRequireTextInput {
                Text("Click an option to send as text response:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                ForEach(Array(detectedOptions.enumerated()), id: \.offset) { index, option in
                    Button(action: {
                        selectOption(index + 1)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Option \(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                if optionsRequireTextInput {
                                    Text("(sends '\(index + 1)')")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(option)
                                .font(.caption2)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var inputView: some View {
        HStack(spacing: 12) {
            TextField(!detectedOptions.isEmpty ? "Please select an option above..." : "Type a message...", text: $messageText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }
                .disabled(isClaudeThinking || chat?.state != .active || !detectedOptions.isEmpty)
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
            .disabled(messageText.isEmpty || isClaudeThinking || chat?.state != .active || !detectedOptions.isEmpty)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func launchClaude() {
        viewModel.sendSystemAction(.launchClaude)
        
        // Add a message to show Claude is launching
        let launchMessage = ChatMessage(
            content: "Launching Claude Code...",
            sender: .system
        )
        viewModel.addSystemMessage(launchMessage)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let message = messageText
        messageText = ""
        viewModel.sendMessage(message)
    }
    
    private func selectOption(_ optionNumber: Int) {
        viewModel.selectOption(optionNumber)
    }
    
    private func copyMessage(_ message: ChatMessage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
    }
    
    private func setupBridgeObservation() {
        // Set up direct observation of the bridge from the view level
        let chatID = self.chatID
        let viewModel = self.viewModel
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let bridge = TerminalBridge.shared.getBridge(for: chatID) {
                // Subscribe to bridge changes for immediate updates
                let cancellable = bridge.objectWillChange.sink { _ in
                    print("🔄 Bridge state changed - triggering UI update")
                    // The actual state updates will happen via the polling timer
                }
                viewModel.addCancellable(cancellable)
            }
        }
    }
    
    private func updateFromBridge() {
        // Get the current bridge state
        if let bridge = TerminalBridge.shared.getBridge(for: chatID) {
            // Update view state from bridge
            isClaudeRunning = bridge.isClaudeRunning
            isClaudeThinking = bridge.isClaudeThinking
            claudeState = bridge.claudeState
            
            // Check for option changes and update immediately
            if detectedOptions != bridge.detectedOptions {
                detectedOptions = bridge.detectedOptions
                print("🎯 ChatView: Options updated via direct observation: \(detectedOptions)")
            }
        }
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
    private var terminalBridge: ChatTerminalBridge?
    private var cancellables = Set<AnyCancellable>()
    
    init(chatID: UUID) {
        self.chatID = chatID
        loadMessages()
    }
    
    func startObserving() {
        // Set up terminal bridge observation
        // Wait a bit for the terminal window to be created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            if let bridge = TerminalBridge.shared.getBridge(for: self.chatID) {
                self.terminalBridge = bridge
                
                // Observe messages from ChatManager
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    self?.loadMessages()
                }
            }
        }
    }
    
    func stopObserving() {
        cancellables.removeAll()
    }
    
    func sendMessage(_ text: String) {
        // Add user message
        let userMessage = ChatMessage(content: text, sender: .user)
        messages.append(userMessage)
        ChatManager.shared.addMessage(to: chatID, content: text, sender: .user)
        
        // Try to get bridge if we don't have it yet
        if terminalBridge == nil {
            terminalBridge = TerminalBridge.shared.getBridge(for: chatID)
        }
        
        // Send to terminal
        if let bridge = terminalBridge {
            Task { @MainActor in
                bridge.sendCommand(text)
            }
            isWaitingForResponse = true
        } else {
            // Bridge not ready, show error
            let errorMessage = ChatMessage(
                content: "Terminal not ready. Please wait a moment and try again.",
                sender: .system
            )
            messages.append(errorMessage)
            ChatManager.shared.addMessage(to: chatID, content: errorMessage.content, sender: .system)
        }
    }
    
    func selectOption(_ optionNumber: Int) {
        // Try to get bridge if we don't have it yet
        if terminalBridge == nil {
            terminalBridge = TerminalBridge.shared.getBridge(for: chatID)
        }
        
        if let bridge = terminalBridge {
            Task { @MainActor in
                bridge.selectOption(optionNumber)
            }
            
            // Add a message to show the selection
            let optionText = optionNumber <= bridge.detectedOptions.count ? 
                bridge.detectedOptions[optionNumber - 1] : "Option \(optionNumber)"
            let selectionMessage = ChatMessage(
                content: "Selected: \(optionText)",
                sender: .user
            )
            messages.append(selectionMessage)
            ChatManager.shared.addMessage(to: chatID, content: selectionMessage.content, sender: .user)
        }
    }
    
    func sendSystemAction(_ action: SystemAction) {
        switch action {
        case .launchClaude:
            // Try to get bridge if we don't have it yet
            if terminalBridge == nil {
                terminalBridge = TerminalBridge.shared.getBridge(for: chatID)
            }
            
            if let bridge = terminalBridge {
                Task { @MainActor in
                    bridge.launchClaude()
                }
            } else {
                // Bridge not ready yet, retry after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.sendSystemAction(action)
                }
            }
        }
    }
    
    private func loadMessages() {
        if let chat = ChatManager.shared.chats.first(where: { $0.id == chatID }) {
            messages = chat.messages
        }
    }
    
    func addSystemMessage(_ message: ChatMessage) {
        messages.append(message)
        ChatManager.shared.addMessage(to: chatID, content: message.content, sender: .system)
    }
    
    func getBridgeStates() -> (isRunning: Bool, isThinking: Bool, state: String, options: [String], optionsRequireText: Bool) {
        // Try to get bridge if we don't have it yet
        if terminalBridge == nil {
            terminalBridge = TerminalBridge.shared.getBridge(for: chatID)
        }
        
        guard let bridge = terminalBridge else {
            return (false, false, "Terminal not connected", [], false)
        }
        return (bridge.isClaudeRunning, bridge.isClaudeThinking, bridge.claudeState, bridge.detectedOptions, bridge.optionsRequireTextInput)
    }
    
    func addCancellable(_ cancellable: AnyCancellable) {
        cancellables.insert(cancellable)
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