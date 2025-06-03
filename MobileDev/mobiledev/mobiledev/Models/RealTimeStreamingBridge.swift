import Foundation
import SwiftUI
import Combine

/// Real-time streaming bridge that captures terminal output as it arrives
class RealTimeStreamingBridge: ChatTerminalBridge {
    
    // MARK: - Streaming State
    private var activeStreamingMessage: ChatMessage?
    private var streamingContent = ""
    private var streamingTimer: Timer?
    private var lastUpdateTime = Date()
    private var isCurrentlyStreaming = false
    
    // MARK: - Command Tracking
    private var pendingCommand: String?
    private var awaitingResponse = false
    
    override init(chatID: UUID, terminalViewModel: TerminalViewModel) {
        super.init(chatID: chatID, terminalViewModel: terminalViewModel)
        setupRealTimeStreaming()
    }
    
    // Override parent's polling to prevent duplicates
    @MainActor
    override func checkTerminalOutput() {
        // Only update state, don't process messages
        guard let viewModel = terminalViewModel else { return }
        isClaudeRunning = viewModel.isClaudeRunning
        claudeState = viewModel.claudeState
        detectedOptions = viewModel.detectedOptions
        optionsRequireTextInput = viewModel.optionsRequireTextInput
    }
    
    private func setupRealTimeStreaming() {
        // Monitor terminal output changes more frequently
        streamingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForStreamingData()
            }
        }
    }
    
    @MainActor
    private func checkForStreamingData() {
        guard let viewModel = terminalViewModel,
              awaitingResponse else { return }
        
        let currentOutput = viewModel.rawTerminalFeed
        
        // Check if we have new content
        if let lastCommand = pendingCommand,
           let commandRange = currentOutput.range(of: lastCommand),
           commandRange.upperBound < currentOutput.endIndex {
            
            // Extract everything after the command
            let responseContent = String(currentOutput[commandRange.upperBound...])
            
            // Debug logging
            if responseContent.count > 10 && !responseContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("🔍 RealTimeStreaming: Found response content (\(responseContent.count) chars)")
                print("   Raw: '\(responseContent.prefix(100))...'")
            }
            
            // Clean up the response (remove command echo and initial newlines)
            let cleanedResponse = cleanStreamingResponse(responseContent)
            
            if !cleanedResponse.isEmpty {
                print("✅ RealTimeStreaming: Cleaned response: '\(cleanedResponse.prefix(50))...'")
                processStreamingContent(cleanedResponse)
            }
        }
    }
    
    private func cleanStreamingResponse(_ response: String) -> String {
        // Return raw response to preserve terminal formatting
        return response
    }
    
    @MainActor
    private func processStreamingContent(_ content: String) {
        // Check if Claude is still generating
        let isGenerating = claudeState.lowercased().contains("generating") || 
                          content.contains("esc to interrupt")
        
        print("🎯 ProcessStreamingContent: isGenerating=\(isGenerating), isCurrentlyStreaming=\(isCurrentlyStreaming)")
        print("   ClaudeState: '\(claudeState)'")
        print("   Content preview: '\(content.prefix(50))...'")
        
        if isGenerating && !isCurrentlyStreaming {
            // Start a new streaming message
            startStreaming()
        }
        
        if isCurrentlyStreaming && activeStreamingMessage != nil {
            // Update the streaming message
            updateStreamingMessage(with: content)
        }
        
        if !isGenerating && isCurrentlyStreaming {
            // Complete the streaming
            completeStreaming()
        } else if !isGenerating && !content.isEmpty && activeStreamingMessage == nil {
            // If we have content but never started streaming, send it directly
            print("⚠️ Content found but streaming never started, sending directly")
            sendDirectMessage(content)
        }
    }
    
    @MainActor
    private func startStreaming() {
        isCurrentlyStreaming = true
        streamingContent = ""
        
        // Create a new message that will be updated as content streams
        let streamingMessage = ChatMessage(
            content: "⏺ ",
            sender: .claude,
            isComplete: false,
            isStreaming: true,
            messageType: .text
        )
        
        activeStreamingMessage = streamingMessage
        ChatManager.shared.addMessage(to: chatID, message: streamingMessage)
        
        print("🎬 Started streaming response")
    }
    
    @MainActor
    private func updateStreamingMessage(with content: String) {
        guard let messageId = activeStreamingMessage?.id else { return }
        
        // Only update if content has changed
        if content != streamingContent {
            streamingContent = content
            
            // Parse the content to determine type
            let messageType = detectMessageType(content)
            let formattedContent = formatStreamingContent(content, type: messageType)
            
            // Update the message in ChatManager
            ChatManager.shared.updateMessage(
                in: chatID,
                messageId: messageId,
                content: formattedContent,
                messageType: messageType,
                isStreaming: true
            )
            
            lastUpdateTime = Date()
        }
    }
    
    @MainActor
    private func completeStreaming() {
        guard let messageId = activeStreamingMessage?.id else { return }
        
        isCurrentlyStreaming = false
        awaitingResponse = false
        pendingCommand = nil
        
        // Final update to remove streaming indicator
        let finalType = detectMessageType(streamingContent)
        let finalContent = formatStreamingContent(streamingContent, type: finalType)
        
        ChatManager.shared.updateMessage(
            in: chatID,
            messageId: messageId,
            content: finalContent,
            messageType: finalType,
            isStreaming: false
        )
        
        activeStreamingMessage = nil
        streamingContent = ""
        
        print("✅ Completed streaming response")
    }
    
    @MainActor
    private func sendDirectMessage(_ content: String) {
        // Send message directly without streaming
        let messageType = detectMessageType(content)
        let formattedContent = formatStreamingContent(content, type: messageType)
        
        if !formattedContent.isEmpty {
            let message = ChatMessage(
                content: formattedContent,
                sender: .claude,
                messageType: messageType
            )
            
            ChatManager.shared.addMessage(to: chatID, message: message)
            awaitingResponse = false
            pendingCommand = nil
            
            print("📤 Sent direct message: '\(formattedContent.prefix(50))...'")
        }
    }
    
    private func detectMessageType(_ content: String) -> MessageType {
        // Check for tool use patterns
        if content.contains("```bash") || content.hasPrefix("$ ") {
            return .toolUse
        }
        
        if content.contains("```") {
            return .code
        }
        
        if content.contains("✅") || content.contains("✓") {
            return .status
        }
        
        if content.contains("❌") || content.contains("✗") {
            return .error
        }
        
        return .text
    }
    
    private func formatStreamingContent(_ content: String, type: MessageType) -> String {
        // Keep raw content to preserve terminal formatting
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add streaming indicator if still streaming
        if isCurrentlyStreaming && !trimmed.isEmpty {
            return trimmed + " ▌"
        }
        
        return trimmed
    }
    
    // MARK: - Command Handling
    
    @MainActor
    override func sendCommand(_ command: String) {
        super.sendCommand(command)
        
        // Track the command for response detection
        pendingCommand = command
        awaitingResponse = true
        
        print("📤 Tracking command for streaming: '\(command)'")
    }
    
    @MainActor
    override func launchClaude() {
        super.launchClaude()
        
        // Don't track claude command for streaming - let parent handle welcome message
        // pendingCommand = "claude"
        // awaitingResponse = true
    }
    
    deinit {
        streamingTimer?.invalidate()
    }
}