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
    private var outputBuffer = ""
    private var outputHandlers: [(String) -> Void] = []
    
    @Published var isClaudeRunning = false
    @Published var lastResponse = ""
    
    init(chatID: UUID, terminalViewModel: TerminalViewModel) {
        self.chatID = chatID
        self.terminalViewModel = terminalViewModel
        setupObservation()
    }
    
    // MARK: - Commands
    
    @MainActor
    func launchClaude() {
        terminalViewModel?.launchClaude()
        isClaudeRunning = true
    }
    
    @MainActor
    func sendCommand(_ command: String) {
        terminalViewModel?.sendCommand(command)
    }
    
    func addOutputHandler(_ handler: @escaping (String) -> Void) {
        outputHandlers.append(handler)
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
        
        let currentOutput = viewModel.terminalOutput
        
        // Check if there's new output
        if currentOutput != outputBuffer {
            let newContent = String(currentOutput.dropFirst(outputBuffer.count))
            outputBuffer = currentOutput
            
            // Process new output
            if !newContent.isEmpty {
                processOutput(newContent)
            }
        }
        
        // Update Claude running state
        isClaudeRunning = viewModel.isClaudeRunning
    }
    
    private func processOutput(_ output: String) {
        // Clean up the output
        let cleanedOutput = cleanOutput(output)
        
        // Notify handlers
        for handler in outputHandlers {
            handler(cleanedOutput)
        }
        
        // Update last response
        if isClaudeResponse(output) {
            lastResponse = cleanedOutput
        }
    }
    
    private func cleanOutput(_ output: String) -> String {
        // Remove ANSI escape codes
        let ansiRegex = try! NSRegularExpression(pattern: "\\x1B\\[[0-9;]*m")
        let range = NSRange(location: 0, length: output.utf16.count)
        var cleaned = ansiRegex.stringByReplacingMatches(in: output, range: range, withTemplate: "")
        
        // Remove terminal control characters
        cleaned = cleaned.replacingOccurrences(of: "\r", with: "")
        
        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func isClaudeResponse(_ output: String) -> Bool {
        // Simple heuristic to detect Claude responses
        let lowerOutput = output.lowercased()
        return lowerOutput.contains("claude") ||
               lowerOutput.contains("i'll") ||
               lowerOutput.contains("i can") ||
               lowerOutput.contains("let me") ||
               output.count > 50  // Longer outputs are likely Claude responses
    }
}