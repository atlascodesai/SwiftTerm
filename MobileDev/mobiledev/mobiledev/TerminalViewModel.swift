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
    @Published var claudeState: String = "Not running"
    @Published var lastAnalysis: ClaudeOutputAnalyzer.Analysis?
    @Published var rawTerminalFeed: String = ""
    
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
        guard !command.isEmpty, let terminal = terminal else { 
            print("❌ Cannot send command: terminal is nil or command is empty")
            return 
        }
        
        currentCommand = command
        print("📤 Sending command: '\(command)'")
        
        // Make sure terminal has focus
        terminal.window?.makeFirstResponder(terminal)
        
        // Send each character individually to simulate typing
        for char in command {
            terminal.send(txt: String(char))
        }
        
        // Send Enter key (carriage return) 
        terminal.send([13]) // CR
        print("✅ Command sent with Enter key")
        
        // Clear the current command after sending
        currentCommand = ""
        
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
        claudeState = "Starting..."
    }
    
    func exitClaude() {
        // Send Ctrl+C twice to exit Claude
        sendInterrupt()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sendInterrupt()
        }
        isClaudeRunning = false
        claudeState = "Not running"
    }
    
    // MARK: - Output Processing
    
    private func getVisibleTerminalContent() -> String {
        // Get last 100 lines of terminal for analysis (avoids analyzing old content)
        let lines = rawTerminalFeed.split(separator: "\n", omittingEmptySubsequences: false)
        let visibleLines = lines.suffix(100)
        return visibleLines.joined(separator: "\n")
    }
    
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
        
        // Analyze the visible terminal content for better state detection
        let visibleContent = getVisibleTerminalContent()
        let analysis = outputAnalyzer.analyze(visibleContent)
        
        // Check if Claude just started based on patterns in full terminal content
        if !isClaudeRunning && (rawTerminalFeed.contains("Welcome to Claude Code") || rawTerminalFeed.contains("Human:")) {
            isClaudeRunning = true
            claudeState = "Ready"
            print("🚀 Claude detected and marked as running")
        }
        
        if isClaudeRunning {
            handleClaudeAnalysis(analysis)
        }
        
        // Debug: Show last few lines of terminal
        let lines = rawTerminalFeed.split(separator: "\n")
        if lines.count > 0 {
            let lastLine = lines.last ?? ""
            print("📍 Last line: '\(lastLine)'")
        }
    }
    
    private func handleClaudeAnalysis(_ analysis: ClaudeOutputAnalyzer.Analysis) {
        // Update last analysis
        lastAnalysis = analysis
        
        // Update Claude state based on analysis
        switch analysis.type {
        case .codeEdit:
            claudeState = "Editing files..."
            print("📝 Claude edited files:")
            for file in analysis.filesModified {
                print("  - Modified: \(file)")
            }
            for file in analysis.filesCreated {
                print("  - Created: \(file)")
            }
        case .thinking:
            claudeState = "Thinking..."
            print("🤔 Claude is thinking...")
        case .explanation:
            claudeState = "Explaining..."
            print("💡 Claude provided explanation")
        case .error:
            claudeState = "Error occurred"
            print("❌ Error: \(analysis.error ?? "Unknown error")")
        case .buildOutput:
            claudeState = analysis.buildSuccessful ? "Build succeeded" : "Build failed"
            if analysis.buildSuccessful {
                print("✅ Build succeeded!")
            } else {
                print("❌ Build failed")
            }
            if analysis.testsRun {
                print("🧪 Tests were run")
            }
        case .commandExecution:
            claudeState = "Executing commands..."
            print("🔧 Commands executed:")
            for cmd in analysis.commandsExecuted {
                print("  $ \(cmd)")
            }
        case .ready:
            claudeState = "Ready for input"
            print("✨ Claude is ready for the next command")
        case .working:
            claudeState = "Processing..."
            print("⚙️ Claude is working...")
        }
        
        if analysis.isComplete {
            claudeState = "Ready"
            print("✓ Operation completed")
        }
        
        // You can add additional handling here, such as:
        // - Showing alerts for errors
        // - Updating UI to show file changes
        // - Triggering follow-up actions based on the analysis
    }
}

// MARK: - Claude Output Analyzer

struct ClaudeOutputAnalyzer {
    enum OutputType {
        case codeEdit
        case thinking
        case explanation
        case error
        case buildOutput
        case commandExecution
        case ready
        case working
    }
    
    struct Analysis {
        let type: OutputType
        let filesModified: [String]
        let filesCreated: [String]
        let filesRead: [String]
        let buildSuccessful: Bool
        let testsRun: Bool
        let error: String?
        let commandsExecuted: [String]
        let isComplete: Bool
        let rawOutput: String
    }
    
    func analyze(_ output: String) -> Analysis {
        var filesModified: [String] = []
        var filesCreated: [String] = []
        var filesRead: [String] = []
        var buildSuccessful = false
        var testsRun = false
        var error: String? = nil
        var commandsExecuted: [String] = []
        var outputType: OutputType = .working
        var isComplete = false
        let rawOutput = output
        
        // Parse output for various patterns
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        
        for (index, line) in lines.enumerated() {
            let lineStr = String(line).trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if lineStr.isEmpty { continue }
            
            // Claude thinking/working indicators
            if lineStr.contains("Thinking...") || lineStr.contains("Working...") {
                outputType = .thinking
            }
            
            // File operations
            if lineStr.contains("Reading ") && lineStr.contains(".") {
                if let filename = extractFilePath(from: lineStr, after: "Reading") {
                    filesRead.append(filename)
                }
            }
            
            if lineStr.contains("Creating ") && lineStr.contains(".") {
                if let filename = extractFilePath(from: lineStr, after: "Creating") {
                    filesCreated.append(filename)
                    outputType = .codeEdit
                }
            }
            
            if lineStr.contains("Modifying ") || lineStr.contains("Updating ") || lineStr.contains("Editing ") {
                if let filename = extractFilePath(from: lineStr, after: nil) {
                    filesModified.append(filename)
                    outputType = .codeEdit
                }
            }
            
            // Command execution
            if lineStr.hasPrefix("$") || lineStr.hasPrefix(">") {
                let command = lineStr.dropFirst().trimmingCharacters(in: .whitespaces)
                if !command.isEmpty {
                    commandsExecuted.append(command)
                    outputType = .commandExecution
                }
            }
            
            // Build/test status
            if lineStr.contains("BUILD SUCCEEDED") || lineStr.contains("Build succeeded") || lineStr.contains("✅ Build") {
                buildSuccessful = true
                outputType = .buildOutput
            } else if lineStr.contains("BUILD FAILED") || lineStr.contains("Build failed") || lineStr.contains("❌ Build") {
                buildSuccessful = false
                outputType = .buildOutput
            }
            
            if lineStr.contains("Test Suite") && lineStr.contains("passed") {
                testsRun = true
            }
            
            if lineStr.contains("tests passed") || lineStr.contains("test(s) passed") {
                testsRun = true
            }
            
            // Errors
            if lineStr.contains("error:") || lineStr.contains("Error:") || lineStr.contains("ERROR:") {
                error = lineStr
                outputType = .error
            }
            
            // Check for completion indicators
            if lineStr.contains("Done!") || lineStr.contains("Completed") || lineStr.contains("Finished") {
                isComplete = true
            }
            
            // Ready state - Claude is waiting for input
            if lineStr.contains("How can I help") || lineStr.contains("What would you like") || lineStr.contains("Human:") {
                outputType = .ready
                isComplete = true
            }
            
            // Check for Claude-specific patterns
            if lineStr.contains("Claude Code") || lineStr.contains("claude-code") || lineStr.contains("Human:") || lineStr.contains("Welcome to Claude Code") {
                outputType = .ready
            }
            
            // Check for Claude prompt patterns
            if lineStr.contains("Human:") || lineStr.contains("> ") && lineStr.count < 10 {
                outputType = .ready
                isComplete = true
            }
            
            // Check if we're at a prompt (indicates command completion)
            if index == lines.count - 1 {
                if lineStr.hasSuffix("$") || lineStr.hasSuffix(">") || lineStr.hasSuffix("%") {
                    isComplete = true
                }
            }
        }
        
        // Special handling for Claude prompt detection - check last non-empty line
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if let lastNonEmptyLine = nonEmptyLines.last {
            let trimmedLast = lastNonEmptyLine.trimmingCharacters(in: .whitespaces)
            
            // Claude's input prompt is typically just "> "
            if trimmedLast == ">" || trimmedLast.hasPrefix("> ") {
                outputType = .ready
                isComplete = true
                print("🎯 Detected Claude prompt: '\(trimmedLast)'")
            }
        }
        
        return Analysis(
            type: outputType,
            filesModified: filesModified,
            filesCreated: filesCreated,
            filesRead: filesRead,
            buildSuccessful: buildSuccessful,
            testsRun: testsRun,
            error: error,
            commandsExecuted: commandsExecuted,
            isComplete: isComplete,
            rawOutput: rawOutput
        )
    }
    
    private func extractFilePath(from line: String, after marker: String?) -> String? {
        var searchLine = line
        
        // If marker provided, look for text after it
        if let marker = marker {
            if let range = line.range(of: marker) {
                searchLine = String(line[range.upperBound...])
            }
        }
        
        // Look for file paths - matches paths like /path/to/file.ext or just file.ext
        let patterns = [
            #"(?:/[\w\-./]+)+\.\w+"#,  // Full paths starting with /
            #"(?:[\w\-./]+/)+[\w\-]+\.\w+"#,  // Relative paths with directories
            #"[\w\-]+\.\w+"#  // Just filenames
        ]
        
        for pattern in patterns {
            if let range = searchLine.range(of: pattern, options: .regularExpression) {
                return String(searchLine[range]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return nil
    }
}