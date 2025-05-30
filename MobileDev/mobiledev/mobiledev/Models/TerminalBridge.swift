import Foundation
import SwiftUI

// Bridge between ChatView and Terminal functionality
class TerminalBridge {
    static let shared = TerminalBridge()
    
    private var bridges: [UUID: ChatTerminalBridge] = [:]
    
    private init() {}
    
    func createBridge(for chatID: UUID, terminalViewModel: TerminalViewModel) -> ChatTerminalBridge {
        let bridge = ChatTerminalBridge(chatID: chatID, terminalViewModel: terminalViewModel)
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
    private weak var terminalViewModel: TerminalViewModel?
    private var lastCommandIndex = -1
    
    @Published var isClaudeRunning = false
    @Published var isClaudeThinking = false
    @Published var claudeState = ""
    @Published var detectedOptions: [String] = []
    
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
        if let vm = terminalViewModel {
            lastCommandIndex = vm.commandResponses.count - 1
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
    private func checkTerminalOutput() {
        guard let viewModel = terminalViewModel else { return }
        
        // Update state from terminal
        isClaudeRunning = viewModel.isClaudeRunning
        claudeState = viewModel.claudeState
        
        // More precise detection of thinking state
        isClaudeThinking = viewModel.claudeState.lowercased().contains("generating") || 
                          viewModel.claudeState.lowercased().contains("thinking") ||
                          viewModel.claudeState.lowercased().contains("starting")
        
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
            print("🎯 TerminalBridge: Options updated: \(detectedOptions)")
            
            // Force UI update by triggering objectWillChange
            self.objectWillChange.send()
        }
        
        // If Claude was generating and is now ready, extract pending responses
        if !isClaudeThinking && viewModel.isClaudeRunning {
            viewModel.extractPendingResponses()
        }
        
        // Debug: Show all commands
        print("📊 TerminalBridge: Total commands: \(viewModel.commandResponses.count)")
        for (idx, cmd) in viewModel.commandResponses.enumerated() {
            if cmd.isComplete && !cmd.rawResponse.isEmpty {
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
                // Send the response to chat
                ChatManager.shared.addMessage(to: chatID, content: commandEntry.rawResponse, sender: .claude)
                
                // Reset the index so we don't send it again
                lastCommandIndex = -1
            }
        }
    }
    
    @MainActor
    func selectOption(_ optionNumber: Int) {
        terminalViewModel?.selectOption(optionNumber)
    }
    
    
}