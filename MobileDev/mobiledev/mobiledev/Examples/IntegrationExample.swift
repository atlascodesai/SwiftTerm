import SwiftUI

// Example showing how to integrate the simple streaming parser
// into your existing TerminalViewModel without breaking changes

extension TerminalViewModel {
    
    /// Enhanced method to process terminal output with streaming parsing
    /// Call this instead of the basic captureResponse for better message detection
    func processTerminalOutputWithStreaming() {
        let currentOutput = rawTerminalFeed
        
        // Parse the output for structured messages
        let messages = SimpleStreamingParser.parseChunk(currentOutput)
        
        // Detect Claude's current state
        let claudeState = SimpleStreamingParser.detectClaudeState(in: currentOutput)
        
        // Detect options if present
        let detectedOptions = SimpleStreamingParser.detectOptions(in: currentOutput)
        
        // Update your existing properties
        updateStateFromStreaming(messages: messages, state: claudeState, options: detectedOptions)
    }
    
    private func updateStateFromStreaming(messages: [StreamMessage], state: ClaudeStreamState, options: [String]) {
        // Update Claude state
        switch state {
        case .starting:
            self.claudeState = "Starting Claude..."
        case .ready:
            self.claudeState = "Ready for input"
            setGenerating(false)
        case .thinking:
            self.claudeState = "Generating response..."
            setGenerating(true)
        case .unknown:
            break // Keep current state
        }
        
        // Update options
        if !options.isEmpty {
            self.detectedOptions = options
            self.showOptionButtons = true
            self.optionsRequireTextInput = !options.contains { $0.contains("❯") }
        }
        
        // Process messages for chat
        for message in messages {
            processStreamMessage(message)
        }
    }
    
    private func processStreamMessage(_ message: StreamMessage) {
        // Enhanced processing based on message type
        switch message.type {
        case .bashCommand:
            print("🔧 Detected bash command: \(message.cleanContent)")
            // Could format this specially for chat
            
        case .fileOperation:
            print("📄 Detected file operation: \(message.cleanContent)")
            // Could show file operation status
            
        case .success:
            print("✅ Success: \(message.cleanContent)")
            // Could show success notification
            
        case .error:
            print("❌ Error: \(message.cleanContent)")
            // Could highlight errors
            
        case .progress:
            print("⏳ Progress: \(message.cleanContent)")
            // Could show progress indicator
            
        case .codeBlock:
            print("💻 Code block detected")
            // Could format code specially
            
        default:
            break
        }
    }
}

// MARK: - Enhanced ChatView Integration

extension ChatManager {
    
    /// Add a message with enhanced formatting based on stream parsing
    func addStreamMessage(to chatID: UUID, message: StreamMessage, sender: MessageSender) {
        let formattedContent = formatStreamMessage(message)
        addMessage(to: chatID, content: formattedContent, sender: sender)
    }
    
    private func formatStreamMessage(_ message: StreamMessage) -> String {
        switch message.type {
        case .bashCommand:
            return "```bash\n\(message.cleanContent)\n```"
            
        case .fileOperation:
            return "📄 \(message.cleanContent)"
            
        case .success:
            return "✅ \(message.cleanContent)"
            
        case .error:
            return "❌ \(message.cleanContent)"
            
        case .warning:
            return "⚠️ \(message.cleanContent)"
            
        case .codeBlock:
            return message.content // Keep ANSI for syntax highlighting
            
        default:
            return message.content // Regular text with ANSI preserved
        }
    }
}

// MARK: - Usage Example

struct StreamingIntegrationDemo: View {
    @StateObject private var terminalViewModel = TerminalViewModel()
    @StateObject private var chatManager = ChatManager.shared
    
    var body: some View {
        VStack {
            Text("Streaming Integration Demo")
                .font(.title)
                .padding()
            
            HStack {
                Button("Test Streaming Parse") {
                    testStreamingParsing()
                }
                
                Button("Test State Detection") {
                    testStateDetection()
                }
                
                Button("Test Option Detection") {
                    testOptionDetection()
                }
            }
            .padding()
            
            Text("Check console for streaming parse results")
                .foregroundColor(.secondary)
        }
    }
    
    private func testStreamingParsing() {
        let sampleOutput = """
        ⣾ Processing your request...
        I'll help you create a file.
        ! echo 'print("Hello!")' > test.py
        ✅ File created successfully
        ```python
        print("Hello!")
        ```
        """
        
        let messages = SimpleStreamingParser.parseChunk(sampleOutput)
        print("🔍 Parsed \(messages.count) messages:")
        for message in messages {
            print("  - \(message.type): \(message.cleanContent)")
        }
    }
    
    private func testStateDetection() {
        let samples = [
            "Welcome to Claude Code!",
            "esc to interrupt",
            "Starting Claude...",
            "> ? for shortcuts"
        ]
        
        for sample in samples {
            let state = SimpleStreamingParser.detectClaudeState(in: sample)
            print("🎯 '\(sample)' → \(state)")
        }
    }
    
    private func testOptionDetection() {
        let sampleWithOptions = """
        Do you want to create this file?
        1. Yes
        2. Yes, and don't ask again
        3. No
        """
        
        let options = SimpleStreamingParser.detectOptions(in: sampleWithOptions)
        print("📋 Detected \(options.count) options:")
        for option in options {
            print("  - \(option)")
        }
    }
}

#Preview {
    StreamingIntegrationDemo()
}