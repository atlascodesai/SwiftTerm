import Foundation
import SwiftUI

// Bridge between ChatView and Terminal functionality
class TerminalBridge {
    static let shared = TerminalBridge()
    
    private var bridges: [UUID: ChatTerminalBridge] = [:]
    
    private init() {}
    
    func createBridge(for chatID: UUID, terminalViewModel: TerminalViewModel) -> ChatTerminalBridge {
        // Always use real-time streaming bridge for best experience
        let bridge = RealTimeStreamingBridge(chatID: chatID, terminalViewModel: terminalViewModel)
        bridges[chatID] = bridge
        return bridge
    }
    
    func getBridge(for chatID: UUID) -> ChatTerminalBridge? {
        return bridges[chatID]
    }
    
    func removeBridge(for chatID: UUID) {
        bridges.removeValue(forKey: chatID)
    }
}

class ChatTerminalBridge: ObservableObject {
    let chatID: UUID
    internal weak var terminalViewModel: TerminalViewModel?
    private var lastCommandIndex = -1
    
    @Published var isClaudeRunning = false
    @Published var isClaudeThinking = false
    @Published var claudeState = ""
    @Published var detectedOptions: [String] = []
    @Published var optionsRequireTextInput = false
    
    init(chatID: UUID, terminalViewModel: TerminalViewModel) {
        self.chatID = chatID
        self.terminalViewModel = terminalViewModel
        setupObservation()
    }
    
    // MARK: - Commands
    
    @MainActor
    func launchClaude() {
        terminalViewModel?.launchClaude()
        // Track this as a command so we can capture the welcome message
        // Wait longer to ensure the command has been added to commandResponses
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            if let self = self, let vm = self.terminalViewModel {
                // Find the claude command specifically
                if let claudeIndex = vm.commandResponses.lastIndex(where: { $0.command == "claude" }) {
                    self.lastCommandIndex = claudeIndex
                    print("📝 TerminalBridge: Tracking 'claude' launch command at index \(self.lastCommandIndex)")
                } else {
                    print("⚠️ TerminalBridge: Could not find 'claude' command in responses")
                }
            }
        }
    }
    
    @MainActor
    func sendCommand(_ command: String) {
        terminalViewModel?.sendCommand(command)
        // Wait a bit for the command to be added to commandResponses
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if let self = self, let vm = self.terminalViewModel {
                self.lastCommandIndex = vm.commandResponses.count - 1
                print("📝 TerminalBridge: Tracking command '\(command)' at index \(self.lastCommandIndex)")
                
                // Debug: Show the command entry details
                if self.lastCommandIndex >= 0 && self.lastCommandIndex < vm.commandResponses.count {
                    let entry = vm.commandResponses[self.lastCommandIndex]
                    print("   - Command: '\(entry.command)'")
                    print("   - Selected Option: \(entry.selectedOption ?? "none")")
                    print("   - Is Complete: \(entry.isComplete)")
                }
            }
        }
    }
    
    
    // MARK: - Private
    
    private func setupObservation() {
        // Observe terminal output
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkTerminalOutput()
            }
        }
    }
    
    @MainActor
    internal func checkTerminalOutput() {
        guard let viewModel = terminalViewModel else { return }
        
        // Update state from terminal
        isClaudeRunning = viewModel.isClaudeRunning
        claudeState = viewModel.claudeState
        
        // More precise detection of thinking state
        isClaudeThinking = viewModel.claudeState.lowercased().contains("generating") || 
                          viewModel.claudeState.lowercased().contains("thinking")
        // Note: "starting" is not the same as thinking - it's just launching
        
        // Special case: Starting Claude is not thinking
        if viewModel.claudeState == "Starting Claude..." {
            isClaudeThinking = false
        }
        
        // If we have the "Ready" state or are waiting for input, we're definitely not thinking
        if viewModel.claudeState.lowercased().contains("ready") || 
           viewModel.claudeState.lowercased().contains("waiting") ||
           viewModel.claudeState == "Ready" {
            isClaudeThinking = false
        }
        
        // Special case: when options are detected, Claude is waiting for selection, not thinking
        if !viewModel.detectedOptions.isEmpty && viewModel.isClaudeRunning {
            isClaudeThinking = false
            // Override the state to make it clear
            if !claudeState.contains("option") {
                claudeState = "Waiting for option selection"
            }
        }
        
        // Debug state changes
        print("🔍 TerminalBridge state: claudeState='\(claudeState)', isThinking=\(isClaudeThinking), options=\(detectedOptions.count)")
        
        // Check for option changes
        if detectedOptions != viewModel.detectedOptions {
            detectedOptions = viewModel.detectedOptions
            optionsRequireTextInput = viewModel.optionsRequireTextInput
            print("🎯 TerminalBridge: Options updated: \(detectedOptions)")
            print("📝 TerminalBridge: Options require text: \(optionsRequireTextInput)")
            
            // Force UI update by triggering objectWillChange
            self.objectWillChange.send()
        }
        
        // If Claude was generating and is now ready, extract pending responses
        if !isClaudeThinking && viewModel.isClaudeRunning {
            viewModel.extractPendingResponses()
        }
        
        // Safety check: if all commands are complete but we think we're generating, fix the state
        if viewModel.isClaudeRunning && isClaudeThinking {
            let allComplete = viewModel.commandResponses.allSatisfy { $0.isComplete }
            if allComplete && viewModel.commandResponses.count > 0 {
                print("🔧 Safety fix: All commands complete but state shows generating - resetting")
                viewModel.claudeState = "Ready for input"
                isClaudeThinking = false
            }
        }
        
        // Special handling for Claude startup - extract welcome message
        if viewModel.claudeState == "Starting Claude..." && viewModel.rawTerminalFeed.contains("Welcome to Claude Code!") {
            print("🎆 TerminalBridge: Claude welcome detected, extracting responses")
            viewModel.extractPendingResponses()
            
            // Update state to ready after welcome is shown
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if viewModel.claudeState == "Starting Claude..." {
                    viewModel.claudeState = "Ready for input"
                }
            }
        }
        
        // Check if terminal shows Claude is at a prompt
        let terminalContent = viewModel.rawTerminalFeed
        if viewModel.isClaudeRunning && claudeState.contains("Generating") {
            // Look for the prompt at the end of the terminal content
            let lastLines = terminalContent.split(separator: "\n").suffix(5)
            for line in lastLines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == ">" || (trimmed.hasPrefix("> ") && trimmed.count < 10) {
                    print("🎯 Bridge detected prompt in terminal - updating state")
                    viewModel.claudeState = "Ready for input"
                    // Force a refresh
                    viewModel.processCommandCompletion("> ")
                    break
                }
            }
        }
        
        // Debug: Show all commands
        print("📊 TerminalBridge: Total commands: \(viewModel.commandResponses.count)")
        for (idx, cmd) in viewModel.commandResponses.enumerated() {
            if cmd.command == "claude" {
                print("   [\(idx)] CLAUDE COMMAND - Complete: \(cmd.isComplete), Response: \(!cmd.rawResponse.isEmpty)")
                if !cmd.rawResponse.isEmpty {
                    print("      Response preview: \(cmd.rawResponse.prefix(100))...")
                    print("      Full response length: \(cmd.rawResponse.count) chars")
                } else {
                    print("      ⚠️ Response is empty!")
                }
            } else if cmd.isComplete && !cmd.rawResponse.isEmpty {
                print("   [\(idx)] '\(cmd.command)' - Has response: \(cmd.rawResponse.prefix(50))...")
            }
        }
        
        // Check if we have a response for our last command
        if lastCommandIndex >= 0 && lastCommandIndex < viewModel.commandResponses.count {
            let commandEntry = viewModel.commandResponses[lastCommandIndex]
            
            print("🔍 TerminalBridge: Checking command at index \(lastCommandIndex)")
            print("   - Command: '\(commandEntry.command)'")
            print("   - Is Complete: \(commandEntry.isComplete)")
            print("   - Has Response: \(!commandEntry.rawResponse.isEmpty)")
            print("   - Response Length: \(commandEntry.rawResponse.count)")
            
            // If the command is complete and has a response, send it to chat
            if commandEntry.isComplete && !commandEntry.rawResponse.isEmpty {
                print("✅ TerminalBridge: Sending response to chat")
                
                // For claude command, ensure we send the welcome message properly
                if commandEntry.command == "claude" {
                    print("🎆 TerminalBridge: Sending Claude welcome message to chat")
                    // Send raw terminal output for authentic look
                    ChatManager.shared.addMessage(to: chatID, content: commandEntry.rawResponse, sender: .claude)
                } else {
                    // Send raw response to preserve terminal formatting
                    ChatManager.shared.addMessage(to: chatID, content: commandEntry.rawResponse, sender: .claude)
                }
                
                // Reset the index so we don't send it again
                lastCommandIndex = -1
            } else if commandEntry.command == "claude" && !commandEntry.isComplete {
                // Special case: If claude command exists but isn't complete yet, keep checking
                print("⏳ TerminalBridge: Claude command not complete yet, will check again...")
            }
        }
    }
    
    @MainActor
    func selectOption(_ optionNumber: Int) {
        terminalViewModel?.selectOption(optionNumber)
        
        // Track the selection command so we can capture Claude's response
        if let vm = terminalViewModel {
            lastCommandIndex = vm.commandResponses.count - 1
            print("📝 TerminalBridge: Tracking option selection at index \(lastCommandIndex)")
        }
    }
    
    
}