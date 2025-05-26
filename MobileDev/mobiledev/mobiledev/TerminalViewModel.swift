import SwiftUI
import SwiftTerm
import Combine

@MainActor
class TerminalViewModel: ObservableObject {
    @Published var terminalOutput: String = ""
    @Published var currentDirectory: String = ""
    @Published var isClaudeRunning: Bool = false
    @Published var commandHistory: [CommandEntry] = []
    @Published var currentCommand: String = ""
    
    private weak var terminal: LocalProcessTerminalView?
    private var claudeDetected = false
    private var outputAnalyzer = ClaudeOutputAnalyzer()
    
    struct CommandEntry {
        let id = UUID()
        let timestamp: Date
        let command: String
        let output: String
        let isClaudeCommand: Bool
    }
    
    // MARK: - Terminal Management
    
    func setTerminal(_ terminal: LocalProcessTerminalView) {
        self.terminal = terminal
    }
    
    func sendCommand(_ command: String) {
        guard !command.isEmpty, let terminal = terminal else { return }
        
        currentCommand = command
        
        // Make sure terminal has focus
        terminal.window?.makeFirstResponder(terminal)
        
        // Send each character individually to simulate typing
        for char in command {
            terminal.send(txt: String(char))
        }
        
        // Send Enter key (carriage return)
        terminal.send([13]) // CR
        
        // Add to history (output will be updated when received)
        let entry = CommandEntry(
            timestamp: Date(),
            command: command,
            output: "", // Will be updated
            isClaudeCommand: isClaudeRunning
        )
        commandHistory.append(entry)
    }
    
    func sendInterrupt() {
        guard let terminal = terminal else { return }
        // Send Ctrl+C
        terminal.send([0x03])
    }
    
    // MARK: - Claude Integration
    
    func checkForClaude() {
        // Check if claude is available
        sendCommand("which claude")
    }
    
    func launchClaude() {
        sendCommand("claude")
        isClaudeRunning = true
    }
    
    func exitClaude() {
        // Send Ctrl+C twice to exit Claude
        sendInterrupt()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sendInterrupt()
        }
        isClaudeRunning = false
    }
    
    // MARK: - Output Processing
    
    func processCommandCompletion(_ output: String) {
        // Update last command entry with output
        if !commandHistory.isEmpty {
            var lastEntry = commandHistory[commandHistory.count - 1]
            lastEntry = CommandEntry(
                timestamp: lastEntry.timestamp,
                command: lastEntry.command,
                output: output,
                isClaudeCommand: lastEntry.isClaudeCommand
            )
            commandHistory[commandHistory.count - 1] = lastEntry
        }
        
        // Analyze output
        if currentCommand == "which claude" && output.contains("/claude") {
            claudeDetected = true
        }
        
        if isClaudeRunning {
            let analysis = outputAnalyzer.analyze(output)
            handleClaudeAnalysis(analysis)
        }
    }
    
    private func handleClaudeAnalysis(_ analysis: ClaudeOutputAnalyzer.Analysis) {
        // Handle different types of Claude responses
        switch analysis.type {
        case .codeEdit:
            print("Claude edited files: \(analysis.filesModified)")
        case .explanation:
            print("Claude provided explanation")
        case .error:
            print("Claude encountered error: \(analysis.error ?? "")")
        case .buildOutput:
            print("Build status: \(analysis.buildSuccessful ? "Success" : "Failed")")
        case .ready:
            print("Claude is ready for next command")
        }
    }
}

// MARK: - Claude Output Analyzer

struct ClaudeOutputAnalyzer {
    enum OutputType {
        case codeEdit
        case explanation
        case error
        case buildOutput
        case ready
    }
    
    struct Analysis {
        let type: OutputType
        let filesModified: [String]
        let buildSuccessful: Bool
        let testsRun: Bool
        let error: String?
    }
    
    func analyze(_ output: String) -> Analysis {
        var filesModified: [String] = []
        var buildSuccessful = false
        var testsRun = false
        var error: String? = nil
        var outputType: OutputType = .ready
        
        // Parse output for various patterns
        let lines = output.split(separator: "\n")
        for line in lines {
            let lineStr = String(line)
            
            // File modifications
            if lineStr.contains("Editing:") || lineStr.contains("Modified:") {
                if let filename = extractFilename(from: lineStr) {
                    filesModified.append(filename)
                    outputType = .codeEdit
                }
            }
            
            // Build status
            if lineStr.contains("Build succeeded") || lineStr.contains("✅") {
                buildSuccessful = true
                outputType = .buildOutput
            } else if lineStr.contains("Build failed") || lineStr.contains("❌") {
                buildSuccessful = false
                outputType = .buildOutput
            }
            
            // Test status
            if lineStr.contains("Tests passed") || lineStr.contains("test(s) passed") {
                testsRun = true
            }
            
            // Errors
            if lineStr.contains("Error:") || lineStr.contains("error:") {
                error = lineStr
                outputType = .error
            }
            
            // Ready state
            if lineStr.contains("claude>") || lineStr.contains("Ready") {
                outputType = .ready
            }
        }
        
        return Analysis(
            type: outputType,
            filesModified: filesModified,
            buildSuccessful: buildSuccessful,
            testsRun: testsRun,
            error: error
        )
    }
    
    private func extractFilename(from line: String) -> String? {
        // Simple extraction - can be improved
        if let range = line.range(of: #"[\w/]+\.\w+"#, options: .regularExpression) {
            return String(line[range])
        }
        return nil
    }
}