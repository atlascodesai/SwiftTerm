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
        // Will be set to true when we detect Claude has actually started
    }
    
    @MainActor
    func sendCommand(_ command: String) {
        terminalViewModel?.sendCommand(command)
        // Track the command index so we can get its response later
        if let vm = terminalViewModel {
            lastCommandIndex = vm.commandResponses.count - 1
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
        isClaudeThinking = viewModel.claudeState.contains("Generating") || viewModel.claudeState.contains("thinking")
        claudeState = viewModel.claudeState
        detectedOptions = viewModel.detectedOptions
        
        // Check if we have a response for our last command
        if lastCommandIndex >= 0 && lastCommandIndex < viewModel.commandResponses.count {
            let commandEntry = viewModel.commandResponses[lastCommandIndex]
            
            // If the command is complete and has a response, send it to chat
            if commandEntry.isComplete && !commandEntry.rawResponse.isEmpty {
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