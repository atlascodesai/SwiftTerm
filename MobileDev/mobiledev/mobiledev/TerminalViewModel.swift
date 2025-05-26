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
    @Published var userCommands: [String] = []
    @Published var commandResponses: [CommandEntry] = []
    
    private weak var terminal: LocalProcessTerminalView?
    private var claudeDetected = false
    private var outputAnalyzer = ClaudeOutputAnalyzer()
    private var wasGenerating = false
    
    struct CommandEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let command: String
        var rawResponse: String = ""
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
        
        print("📤 Sending command: '\(command)'")
        
        // Focus the terminal first
        terminal.window?.makeFirstResponder(terminal)
        
        // Small delay to ensure focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Try simulating keyboard events
            if let event = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: terminal.window?.windowNumber ?? 0,
                context: nil,
                characters: command,
                charactersIgnoringModifiers: command,
                isARepeat: false,
                keyCode: 0
            ) {
                terminal.keyDown(with: event)
            }
            
            // Then send Enter key event
            if let enterEvent = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: terminal.window?.windowNumber ?? 0,
                context: nil,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: false,
                keyCode: 36 // Enter key code
            ) {
                terminal.keyDown(with: enterEvent)
            }
        }
        
        // Track command
        let entry = CommandEntry(
            timestamp: Date(),
            command: command,
            rawResponse: "",
            isClaudeCommand: isClaudeRunning
        )
        commandHistory.append(entry)
        commandResponses.append(entry)
        userCommands.append(command)
        
        print("✅ Command sent via keyboard events")
    }
    
    // Method 1: CR (13)
    func sendCommandMethod1(_ command: String) {
        guard !command.isEmpty, let terminal = terminal else { 
            print("❌ Cannot send command: terminal is nil or command is empty")
            return 
        }
        
        currentCommand = command
        print("📤 Method 1 (CR): Sending command: '\(command)'")
        
        // Make sure terminal has focus
        terminal.window?.makeFirstResponder(terminal)
        
        // Send each character individually to simulate typing
        for char in command {
            terminal.send(txt: String(char))
        }
        
        // Send Enter key (carriage return) 
        terminal.send([13]) // CR
        print("✅ Command sent with CR (13)")
        
        // Clear the current command after sending
        currentCommand = ""
        
        // Add to history (output will be updated when received)
        let entry = CommandEntry(
            timestamp: Date(),
            command: command,
            rawResponse: "",
            isClaudeCommand: isClaudeRunning
        )
        commandHistory.append(entry)
        commandResponses.append(entry)
        
        // Track all commands sent through the UI
        userCommands.append(command)
        print("📌 Command sent: '\(command)' (Claude running: \(isClaudeRunning))")
    }
    
    // Method 2: LF (10)
    func sendCommandMethod2(_ command: String) {
        guard !command.isEmpty, let terminal = terminal else { return }
        
        print("📤 Method 2 (LF): Sending command: '\(command)'")
        terminal.window?.makeFirstResponder(terminal)
        
        for char in command {
            terminal.send(txt: String(char))
        }
        
        terminal.send([10]) // LF
        print("✅ Command sent with LF (10)")
    }
    
    // Method 3: CRLF (13, 10)
    func sendCommandMethod3(_ command: String) {
        guard !command.isEmpty, let terminal = terminal else { return }
        
        print("📤 Method 3 (CRLF): Sending command: '\(command)'")
        terminal.window?.makeFirstResponder(terminal)
        
        for char in command {
            terminal.send(txt: String(char))
        }
        
        terminal.send([13, 10]) // CRLF
        print("✅ Command sent with CRLF (13, 10)")
    }
    
    // Method 4: Using send(txt:) with \n
    func sendCommandMethod4(_ command: String) {
        guard !command.isEmpty, let terminal = terminal else { return }
        
        print("📤 Method 4 (txt \\n): Sending command: '\(command)'")
        terminal.window?.makeFirstResponder(terminal)
        
        // Send command with newline
        terminal.send(txt: command + "\n")
        print("✅ Command sent with txt + \\n")
    }
    
    // Method 5: Using send(txt:) with \r
    func sendCommandMethod5(_ command: String) {
        guard !command.isEmpty, let terminal = terminal else { return }
        
        print("📤 Method 5 (txt \\r): Sending command: '\(command)'")
        terminal.window?.makeFirstResponder(terminal)
        
        // Send command with return
        terminal.send(txt: command + "\r")
        print("✅ Command sent with txt + \\r")
    }
    
    // Method 6: Ctrl+J (10) - Alternative line feed
    func sendCommandMethod6(_ command: String) {
        guard !command.isEmpty, let terminal = terminal else { return }
        
        print("📤 Method 6 (Ctrl+J): Sending command: '\(command)'")
        terminal.window?.makeFirstResponder(terminal)
        
        for char in command {
            terminal.send(txt: String(char))
        }
        
        terminal.send([10]) // Ctrl+J
        print("✅ Command sent with Ctrl+J")
    }
    
    // Method 7: Escape sequence for Enter
    func sendCommandMethod7(_ command: String) {
        guard !command.isEmpty, let terminal = terminal else { return }
        
        print("📤 Method 7 (ESC seq): Sending command: '\(command)'")
        terminal.window?.makeFirstResponder(terminal)
        
        for char in command {
            terminal.send(txt: String(char))
        }
        
        // Try ESC + Enter sequence
        terminal.send([27, 13]) // ESC + CR
        print("✅ Command sent with ESC + CR")
    }
    
    // Method 8: Using insertText
    func sendCommandMethod8(_ command: String) {
        guard !command.isEmpty, let terminal = terminal else { return }
        
        print("📤 Method 8 (insertText): Sending command: '\(command)'")
        terminal.window?.makeFirstResponder(terminal)
        
        // Use insertText which might handle line endings differently
        terminal.insertText(command + "\n")
        print("✅ Command sent with insertText + \\n")
    }
    
    // Method 9: Send as byte array
    func sendCommandMethod9(_ command: String) {
        guard !command.isEmpty, let terminal = terminal else { return }
        
        print("📤 Method 9 (byte array): Sending command: '\(command)'")
        terminal.window?.makeFirstResponder(terminal)
        
        // Convert to byte array and send with newline
        let fullCommand = command + "\n"
        let bytes = Array(fullCommand.utf8)
        terminal.send(bytes)
        print("✅ Command sent as byte array")
    }
    
    // Method 10: Direct terminal feed
    func sendCommandMethod10(_ command: String) {
        guard !command.isEmpty, let terminal = terminal else { return }
        
        print("📤 Method 10 (feed): Sending command: '\(command)'")
        terminal.window?.makeFirstResponder(terminal)
        
        // Try using feed which might process input differently
        terminal.feed(text: command + "\n")
        print("✅ Command sent with feed")
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
        userCommands.removeAll() // Clear commands when starting new session
        commandResponses.removeAll() // Clear command history
        print("🚀 Claude launched, commands will be tracked")
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
        // Update last command response with new output
        if !commandResponses.isEmpty {
            commandResponses[commandResponses.count - 1].rawResponse += output
        }
        
        // Debug: Show what new content we received
        print("📨 New content (\(output.count) chars): '\(output.prefix(200))'")
        
        // Analyze output
        if currentCommand == "which claude" && output.contains("/claude") {
            claudeDetected = true
        }
        
        // Check for generation pattern in the NEW output
        if output.contains("tokens") && output.contains("esc to interrupt") {
            print("⚡ Found generation pattern in NEW output!")
            claudeState = "Generating response..."
            wasGenerating = true
        }
        
        // Analyze the NEW output directly
        let analysis = outputAnalyzer.analyze(output)
        
        // Check if Claude just started based on patterns in full terminal content
        if !isClaudeRunning && (rawTerminalFeed.contains("Welcome to Claude Code") || rawTerminalFeed.contains("Human:") || rawTerminalFeed.contains("Hi! How can I help")) {
            isClaudeRunning = true
            claudeState = "Ready"
            print("🚀 Claude detected and marked as running")
        }
        
        if isClaudeRunning {
            // Track generation state transitions
            let isCurrentlyGenerating = analysis.type == .working
            
            // If we were generating and now we're not, Claude has finished
            if wasGenerating && !isCurrentlyGenerating && analysis.type == .ready {
                print("✅ Claude finished generating response")
                claudeState = "Ready for input"
            }
            
            wasGenerating = isCurrentlyGenerating
            handleClaudeAnalysis(analysis)
        }
        
        // Check if generation just ended (we see a prompt after generating)
        if wasGenerating && output.contains("> ") && !output.contains("tokens") {
            print("✅ Generation completed, ready for input")
            claudeState = "Ready for input"
            wasGenerating = false
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
            claudeState = "Generating response..."
            print("⚙️ Claude is generating...")
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
        // Debug: Show what we're analyzing
        print("🔍 Analyzing \(output.count) chars of output")
        if output.count < 500 {
            print("   Content: '\(output)'")
        }
        
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
            
            // Claude generation indicator - look for "tokens" and "esc to interrupt"
            // Pattern: "✶ [Word]... (2s · ↑ 0 tokens · esc to interrupt)"
            if lineStr.contains("tokens") && lineStr.contains("esc to interrupt") {
                outputType = .working
                print("⚡ Claude is generating: '\(lineStr)'")
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
            
            // Command execution - look for prompts followed by commands
            if lineStr.hasPrefix(">") && lineStr.count > 2 {
                let command = lineStr.dropFirst().trimmingCharacters(in: .whitespaces)
                if !command.isEmpty {
                    commandsExecuted.append(command)
                    outputType = .commandExecution
                    print("📝 Detected command: '\(command)'")
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
            
            // Also check if the last line shows generation status
            if trimmedLast.contains("tokens") && trimmedLast.contains("esc to interrupt") {
                outputType = .working
                isComplete = false
                print("⚡ Claude is actively generating - last line: '\(trimmedLast)'")
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