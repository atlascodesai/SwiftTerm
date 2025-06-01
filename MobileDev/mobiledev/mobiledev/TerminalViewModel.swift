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
    @Published var detectedOptions: [String] = []
    @Published var showOptionButtons: Bool = false
    @Published var optionsRequireTextInput: Bool = false  // Track if options need text response vs arrow selection

    private weak var terminal: LocalProcessTerminalView?
    private var claudeDetected = false
    private var outputAnalyzer = ClaudeOutputAnalyzer()
    private var wasGenerating = false
    private var lastPromptPosition = 0
    private var waitingForResponse = false
    private var capturedContent = ""  // Accumulate content separately
    private var lastTerminalContent = ""  // Track terminal state

    struct CommandEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let command: String
        var rawResponse: String = ""
        let isClaudeCommand: Bool
        var isComplete: Bool = false
        var claudeGenerating: Bool = false
        var terminalSnapshotBefore: String = ""
        var terminalSnapshotAfter: String = ""
        var selectedOption: String?  // Track which option was selected
    }

    // MARK: - Terminal Management

    func setTerminal(_ terminal: LocalProcessTerminalView) {
        self.terminal = terminal
    }

    func sendCommand(_ command: String, selectedOption: String? = nil) {
        guard !command.isEmpty else {
            print("❌ Cannot send command: command is empty")
            return
        }

        guard let terminal = terminal else {
            print("❌ Cannot send command: terminal is nil")
            return
        }

        print("📤 Sending command: '\(command)'")
        if let option = selectedOption {
            print("📝 This is a selection for: \(option)")
        }
        print("🔍 Terminal: \(terminal)")
        print("🔍 Terminal window: \(String(describing: terminal.window))")
        print("🔍 Terminal accepts first responder: \(terminal.acceptsFirstResponder)")

        // Focus the terminal first
        if let window = terminal.window {
            window.makeFirstResponder(terminal)
            print("✅ Made terminal first responder")
        } else {
            print("⚠️ Terminal has no window")
        }

        // Capture terminal state before sending command
        let snapshotBefore = rawTerminalFeed

        // Send the command
        print("🔄 Sending command text...")
        terminal.send(txt: command)

        // Mark that we're waiting for a response
        waitingForResponse = true
        lastPromptPosition = rawTerminalFeed.count

        // Small delay to ensure the text is processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            print("🔄 Sending Enter key...")
            terminal.send([13]) // CR (carriage return)

            // Track command after sending
            let entry = CommandEntry(
                timestamp: Date(),
                command: command,
                rawResponse: "",
                isClaudeCommand: self.isClaudeRunning,
                isComplete: false,
                claudeGenerating: false,
                terminalSnapshotBefore: snapshotBefore,
                terminalSnapshotAfter: "",
                selectedOption: selectedOption
            )
            self.commandHistory.append(entry)
            self.commandResponses.append(entry)
            self.userCommands.append(command)

            print("✅ Command sent with CR (13)")
        }
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

    func sendArrowUp() {
        guard let terminal = terminal else { return }
        // Send ESC [ A (up arrow)
        terminal.send([0x1B, 0x5B, 0x41])
    }

    func sendArrowDown() {
        guard let terminal = terminal else { return }
        // Send ESC [ B (down arrow)
        terminal.send([0x1B, 0x5B, 0x42])
    }

    func sendEnter() {
        guard let terminal = terminal else { return }
        terminal.send([13]) // CR
    }

    func selectOption(_ optionNumber: Int) {
        guard terminal != nil else { return }

        // Record the selection in command history
        let selectedOptionText = optionNumber <= detectedOptions.count ? detectedOptions[optionNumber - 1] : "Option \(optionNumber)"

        print("📝 User selected option \(optionNumber): \(selectedOptionText)")
        
        // Clear options after selection
        let requiresText = optionsRequireTextInput
        detectedOptions = []
        showOptionButtons = false
        optionsRequireTextInput = false
        
        // Mark that we're waiting for a response
        waitingForResponse = true

        // If options require text input, send the number as text
        if requiresText {
            // For text-based options, send the number directly
            let commandText = String(optionNumber)
            print("🔄 Sending option as text: '\(commandText)'")
            
            // Use sendCommand to properly track the command
            sendCommand(commandText, selectedOption: selectedOptionText)
            claudeState = "Generating response..."
        } else {
            // For arrow-based options, create an entry to track the selection
            let entry = CommandEntry(
                timestamp: Date(),
                command: "Selected: \(selectedOptionText)",
                rawResponse: "",
                isClaudeCommand: isClaudeRunning,
                isComplete: false,
                claudeGenerating: false,
                terminalSnapshotBefore: rawTerminalFeed,
                terminalSnapshotAfter: "",
                selectedOption: selectedOptionText
            )
            commandHistory.append(entry)
            commandResponses.append(entry)
            
            // Use arrow navigation for UI-based options
            if optionNumber == 2 {
                sendArrowDown()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.sendEnter()
                    // Options 1 & 2: Claude will continue generating
                    self.claudeState = "Generating response..."
                }
            } else if optionNumber == 3 {
                sendArrowDown()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.sendArrowDown()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.sendEnter()
                        // Option 3 means Claude is waiting for input
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.claudeState = "Waiting for input"
                        }
                    }
                }
            } else {
                // Option 1 - just press enter
                sendEnter()
                // Options 1 & 2: Claude will continue generating
                claudeState = "Generating response..."
            }
        }
    }

    // MARK: - Claude Integration

    func checkForClaude() {
        // Check if claude is available
        sendCommand("which claude")
    }

    func launchClaude() {
        sendCommand("claude")
        isClaudeRunning = true
        claudeState = "Starting Claude..."
        wasGenerating = false  // Not generating yet, just starting
        waitingForResponse = true  // Ensure we're waiting for the welcome message
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

    func setGenerating(_ isGenerating: Bool) {
        wasGenerating = isGenerating
        claudeState = isGenerating ? "Generating response..." : "Ready for input"

        if !commandResponses.isEmpty {
            let lastIndex = commandResponses.count - 1
            commandResponses[lastIndex].claudeGenerating = isGenerating
        }
    }

    func extractPendingResponses() {
        // Extract responses for any incomplete commands
        for (index, entry) in commandResponses.enumerated() {
            if !entry.isComplete && entry.rawResponse.isEmpty {
                print("📝 Extracting response for pending command: '\(entry.command)'")
                extractResponseFromRawFeed(for: index)
            } else if !entry.isComplete && !entry.rawResponse.isEmpty {
                // Check if we need to capture more content
                print("📝 Command '\(entry.command)' has partial response, checking for more...")
            }
        }
    }

    private func cleanResponseText(_ text: String) -> String {
        // Remove UI elements from captured responses
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var cleanedLines: [String] = []

        for line in lines {
            let lineStr = String(line)

            // Skip UI chrome elements
            if lineStr.contains("╭─") && lineStr.contains("─╮") {
                continue
            }
            if lineStr.contains("╰─") && lineStr.contains("─╯") {
                continue
            }
            // Skip empty prompt lines
            if lineStr.contains("│") && lineStr.contains(">") && lineStr.contains("│") {
                let trimmed = lineStr.replacingOccurrences(of: "│", with: "").trimmingCharacters(in: .whitespaces)
                if trimmed == ">" || trimmed.isEmpty {
                    continue
                }
            }
            if lineStr.trimmingCharacters(in: .whitespaces) == "? for shortcuts" {
                continue
            }

            // Keep actual content
            cleanedLines.append(lineStr)
        }

        return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func detectOptionsInResponse(_ response: String) {
        // Clear previous options
        detectedOptions = []
        showOptionButtons = false

        // Look for numbered options pattern (1. Yes, 2. Yes..., 3. No...)
        let lines = response.split(separator: "\n")
        var foundOptions: [String] = []

        for line in lines {
            var lineStr = String(line)

            // Remove box characters if present
            lineStr = lineStr.replacingOccurrences(of: "│", with: "")
                            .replacingOccurrences(of: "❯", with: "")
                            .trimmingCharacters(in: .whitespaces)

            // Check for patterns like "1. Yes" or "2. Yes, and don't ask again"
            if lineStr.starts(with: "1.") {
                foundOptions.append(lineStr)
            } else if lineStr.starts(with: "2.") {
                foundOptions.append(lineStr)
            } else if lineStr.starts(with: "3.") {
                foundOptions.append(lineStr)
            }
        }

        // If we found all three options, show the option buttons
        if foundOptions.count >= 2 {
            detectedOptions = foundOptions
            showOptionButtons = true
            print("🎯 Detected \(foundOptions.count) options: \(foundOptions)")

            // Also log the original response for debugging
            print("📝 Original response contained: '\(response.prefix(200))...'")
        }
    }

    func detectOptionsInTerminal(_ terminalContent: String) {
        // Direct detection from terminal content
        let lines = terminalContent.split(separator: "\n")
        var foundOptions: [String] = []
        var foundDoYouWant = false
        var hasUIMarkers = false  // Track if we found ❯ markers
        var foundQuestionPattern = false

        for line in lines {
            let lineStr = String(line)

            // Check for various question patterns
            if lineStr.contains("Do you want to") || 
               lineStr.contains("Would you like") || 
               lineStr.contains("What would you prefer") ||
               lineStr.contains("Please choose") {
                foundQuestionPattern = true
            }

            // Look for option lines with ❯ marker (UI selection)
            if lineStr.contains("❯ 1.") || lineStr.contains("│ ❯ 1.") {
                hasUIMarkers = true
                let cleaned = lineStr.replacingOccurrences(of: "│", with: "")
                                   .replacingOccurrences(of: "❯", with: "")
                                   .trimmingCharacters(in: .whitespaces)
                foundOptions.append(cleaned)
            } else if (lineStr.contains("2.") || lineStr.contains("3.")) && (foundDoYouWant || foundQuestionPattern) {
                let cleaned = lineStr.replacingOccurrences(of: "│", with: "")
                                   .trimmingCharacters(in: .whitespaces)
                if cleaned.starts(with: "2.") || cleaned.starts(with: "3.") {
                    foundOptions.append(cleaned)
                }
            }
        }
        
        // Also check for text-based numbered options (without UI markers)
        if !hasUIMarkers && foundOptions.isEmpty {
            // Look for pattern like "1. Option text" at the start of lines
            for (index, line) in lines.enumerated() {
                let lineStr = String(line).trimmingCharacters(in: .whitespaces)
                
                // Check if this line starts with "1."
                if lineStr.starts(with: "1.") {
                    foundOptions.append(lineStr)
                    
                    // Look for subsequent numbered options
                    if index + 1 < lines.count {
                        let nextLine = String(lines[index + 1]).trimmingCharacters(in: .whitespaces)
                        if nextLine.starts(with: "2.") {
                            foundOptions.append(nextLine)
                        }
                    }
                    if index + 2 < lines.count {
                        let nextLine = String(lines[index + 2]).trimmingCharacters(in: .whitespaces)
                        if nextLine.starts(with: "3.") {
                            foundOptions.append(nextLine)
                        }
                    }
                }
            }
        }

        // If we found options, show them
        if foundOptions.count >= 2 {
            detectedOptions = foundOptions
            showOptionButtons = true
            optionsRequireTextInput = !hasUIMarkers  // Text input needed if no UI markers
            
            print("🎯 Detected \(foundOptions.count) options from terminal: \(foundOptions)")
            print("📝 Options require text input: \(optionsRequireTextInput)")
            
            // When options are shown, Claude is waiting for input, not thinking
            DispatchQueue.main.async {
                self.claudeState = "Waiting for option selection"
            }
        }
    }

    private func extractResponseFromRawFeed(for index: Int) {
        guard index < commandResponses.count else { return }

        let entry = commandResponses[index]
        let command = entry.command
        let content = rawTerminalFeed

        // Special handling for arrow-based selections (command starts with "Selected:")
        if command.starts(with: "Selected:") && entry.selectedOption != nil {
            // For arrow-based selections, we need to find the response after the selection was made
            // Use the snapshot to find where to start looking
            let snapshotBefore = entry.terminalSnapshotBefore
            
            // Find content after the snapshot
            if let snapshotRange = content.range(of: snapshotBefore) {
                let afterSnapshot = String(content[snapshotRange.upperBound...])
                
                // Extract response from after the selection
                var response = ""
                let lines = afterSnapshot.split(separator: "\n", omittingEmptySubsequences: false)
                var foundContent = false
                
                for line in lines {
                    let lineStr = String(line)
                    let trimmed = lineStr.trimmingCharacters(in: .whitespaces)
                    
                    // Skip empty lines at the beginning
                    if !foundContent && trimmed.isEmpty {
                        continue
                    }
                    
                    // Start capturing when we see content
                    if !trimmed.isEmpty && !lineStr.contains("❯") && !lineStr.contains("│ >") {
                        foundContent = true
                    }
                    
                    // Stop at next prompt
                    if foundContent && (lineStr.contains("╭─") && lineStr.contains("─╮")) {
                        break
                    }
                    
                    if foundContent {
                        if !response.isEmpty {
                            response += "\n"
                        }
                        response += lineStr
                    }
                }
                
                // Clean and save
                response = response.trimmingCharacters(in: .whitespacesAndNewlines)
                if !response.isEmpty {
                    let cleanedResponse = cleanResponseText(response)
                    commandResponses[index].rawResponse = cleanedResponse
                    commandResponses[index].isComplete = true
                    print("✅ Extracted response for arrow selection: '\(cleanedResponse.prefix(50))...'")
                }
                return
            }
        }

        // Find the command in the raw feed
        var commandRange: Range<String.Index>?
        
        // For numeric commands, also check without the prompt
        if command.count == 1 && command.first?.isNumber == true {
            commandRange = content.range(of: "> \(command)\n") ?? 
                          content.range(of: "> \(command)") ??
                          content.range(of: "\(command)\n")
        } else {
            commandRange = content.range(of: "> \(command)\n") ?? content.range(of: "> \(command)")
        }
        
        if let commandRange = commandRange {
            let afterCommand = String(content[commandRange.upperBound...])

            // For Claude command, extract welcome box
            if command == "claude" && afterCommand.contains("Welcome to Claude Code!") {
                if let boxStart = afterCommand.range(of: "╭"),
                   let boxEnd = afterCommand.range(of: "╰───") {
                    // Find the end of the first box (welcome box)
                    if let firstNewlineAfterBox = afterCommand[boxEnd.upperBound...].firstIndex(of: "\n") {
                        let welcomeEndIdx = afterCommand.index(firstNewlineAfterBox, offsetBy: 1)
                        let welcomeText = String(afterCommand[boxStart.lowerBound..<welcomeEndIdx])
                        commandResponses[index].rawResponse = welcomeText.trimmingCharacters(in: .whitespacesAndNewlines)
                        commandResponses[index].isComplete = true
                        print("✅ Extracted Claude welcome at index \(index)")
                        print("📝 Welcome message length: \(welcomeText.count) chars")
                        print("📝 First 100 chars: \(welcomeText.prefix(100))...")
                        print("📝 Command is now complete: \(commandResponses[index].isComplete)")
                        print("📝 Response stored: \(!commandResponses[index].rawResponse.isEmpty)")

                        // Claude is now ready
                        DispatchQueue.main.async {
                            self.claudeState = "Ready for input"
                            self.wasGenerating = false
                        }
                        return
                    }
                } else {
                    print("⚠️ Could not find welcome box markers")
                    print("   Looking for ╭ : \(afterCommand.contains("╭"))")
                    print("   Looking for ╰─── : \(afterCommand.contains("╰───"))")
                }
            }

            // For other commands, extract everything until we see the input prompt pattern
            var response = ""
            let lines = afterCommand.split(separator: "\n", omittingEmptySubsequences: false)
            var skipEmptyAtStart = true

            // Look for patterns that indicate the end of response
            for (index, line) in lines.enumerated() {
                let lineStr = String(line)
                let trimmed = lineStr.trimmingCharacters(in: .whitespaces)

                // Check if we've reached the input prompt area
                // Look for the pattern: empty line, then prompt box, or "Enter command..."
                if lineStr.contains("Enter command...") {
                    break
                }

                // Check for prompt box pattern with next line context
                if lineStr.contains("╭─") && lineStr.contains("─╮") {
                    // Check if next line has just "> " (input prompt)
                    if index + 1 < lines.count {
                        let nextLine = String(lines[index + 1])
                        let nextTrimmed = nextLine.replacingOccurrences(of: "│", with: "").trimmingCharacters(in: .whitespaces)
                        if nextTrimmed == ">" {
                            break
                        }
                    }
                }

                // Skip empty lines only at the very beginning
                if skipEmptyAtStart && trimmed.isEmpty {
                    continue
                }
                skipEmptyAtStart = false

                // Add line
                if !response.isEmpty {
                    response += "\n"
                }
                response += lineStr
            }

            // Clean and save
            response = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if !response.isEmpty {
                // Clean the response to remove UI elements
                let cleanedResponse = cleanResponseText(response)
                commandResponses[index].rawResponse = cleanedResponse
                commandResponses[index].isComplete = true
                print("✅ Extracted response for '\(command)': '\(cleanedResponse.prefix(50))...'")

                // Check if this response contains numbered options
                detectOptionsInResponse(cleanedResponse)
            } else {
                print("⚠️ No response found for command '\(command)'")
            }
        } else {
            print("⚠️ Could not find command '\(command)' in terminal feed")
        }
    }

    private func cleanupLastResponse() {
        guard !commandResponses.isEmpty else { return }
        let lastIndex = commandResponses.count - 1

        // Special handling for claude command - keep the welcome box intact
        if commandResponses[lastIndex].command == "claude" &&
           commandResponses[lastIndex].rawResponse.contains("Welcome to Claude Code!") {
            // Don't clean up the welcome box
            return
        }

        // Clean up the response by removing prompt artifacts
        let response = commandResponses[lastIndex].rawResponse
        let lines = response.split(separator: "\n", omittingEmptySubsequences: false)

        var cleanedLines: [String] = []
        for line in lines {
            let lineStr = String(line)

            // Skip prompt-related lines but keep content lines
            if lineStr.contains("│ >") && lineStr.contains("│") && !lineStr.contains("●") && !lineStr.contains("⏺") {
                continue
            }
            if lineStr.contains("╭─") && lineStr.contains("─╮") && !lineStr.contains("Welcome") {
                continue
            }
            if lineStr.contains("╰─") && lineStr.contains("─╯") && !lineStr.contains("Welcome") {
                continue
            }
            if lineStr == "? for shortcuts" || lineStr.trimmingCharacters(in: .whitespaces) == "? for shortcuts" {
                continue
            }

            cleanedLines.append(lineStr)
        }

        commandResponses[lastIndex].rawResponse = cleanedLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateCommandResponses() {
        // This method is no longer needed since we capture in real-time
        // Keeping it empty for compatibility
    }

    private func extractResponseFromTerminal(for index: Int) {
        guard index < commandResponses.count else { return }

        let command = commandResponses[index].command
        let terminal = rawTerminalFeed

        print("🔍 Extracting response for '\(command)' from terminal (\(terminal.count) chars)")

        // Debug: Show what we're searching for
        if terminal.contains(command) {
            print("   ✓ Found command '\(command)' in terminal")
        } else {
            print("   ✗ Command '\(command)' not found in terminal")
            return
        }

        // Try different patterns to find the command
        var commandRange: Range<String.Index>?

        // Pattern 1: "> command\n"
        commandRange = terminal.range(of: "> \(command)\n")
        if commandRange == nil {
            // Pattern 2: "% command\n" (for zsh)
            commandRange = terminal.range(of: "% \(command)\n")
        }
        if commandRange == nil {
            // Pattern 3: just "command\n"
            commandRange = terminal.range(of: "\(command)\n")
        }

        if let commandRange = commandRange {
            print("   ✓ Found command pattern at position \(terminal.distance(from: terminal.startIndex, to: commandRange.lowerBound))")

            // Get everything after the command
            let afterCommand = String(terminal[commandRange.upperBound...])
            print("   After command: \(afterCommand.prefix(100))...")

            // For claude command, look for the welcome box
            if command == "claude" {
                if let boxStart = afterCommand.range(of: "╭"),
                   let boxEnd = afterCommand.range(of: "╰") {
                    let endIndex = afterCommand.index(boxEnd.upperBound, offsetBy: min(afterCommand.distance(from: boxEnd.upperBound, to: afterCommand.endIndex), 50))
                    let welcomeBox = String(afterCommand[boxStart.lowerBound..<endIndex])
                    commandResponses[index].rawResponse = welcomeBox.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("✅ Extracted Claude welcome box")
                    return
                }
            }

            // For all commands, capture everything between command and next prompt
            let lines = afterCommand.split(separator: "\n", omittingEmptySubsequences: false)
            var responseLines: [String] = []
            var skipEmptyLinesAtStart = true

            for line in lines {
                let lineStr = String(line)

                // Stop at next prompt (command input area)
                if lineStr.contains("╭─") && lineStr.contains("─╮") && lineStr.contains(">") {
                    print("   Found prompt box, stopping")
                    break
                }
                if lineStr.contains("│ >") && lineStr.contains("│") {
                    print("   Found prompt line, stopping")
                    break
                }

                // Skip empty lines only at the beginning
                if skipEmptyLinesAtStart && lineStr.trimmingCharacters(in: .whitespaces).isEmpty {
                    continue
                }

                // Once we have content, capture everything
                skipEmptyLinesAtStart = false
                responseLines.append(lineStr)
            }

            if !responseLines.isEmpty {
                let response = responseLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                commandResponses[index].rawResponse = response
                print("✅ Extracted response: '\(response.prefix(50))...'")
            } else {
                print("   ⚠️ No response lines found")
            }
        } else {
            print("   ✗ Could not find command pattern in terminal")
        }
    }

    func processCommandCompletion(_ output: String) {
        // Debug: Show what new content we received (only if not empty)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            print("📨 Processing new content (\(output.count) chars)")
        }

        // Accumulate all content we see
        capturedContent += output
        
        // Update raw terminal feed
        rawTerminalFeed += output

        // If waiting for response and see Claude welcome, extract it
        if waitingForResponse && !commandResponses.isEmpty {
            let lastIndex = commandResponses.count - 1
            let command = commandResponses[lastIndex].command

            if command == "claude" && output.contains("Welcome to Claude Code!") {
                print("📝 Claude welcome detected")
                // Mark that we're no longer waiting
                self.waitingForResponse = false
                
                // Extract after a short delay to ensure full content
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.extractPendingResponses()
                    // Ensure state is set correctly after welcome
                    self.claudeState = "Ready for input"
                    self.wasGenerating = false
                    
                    // Force extraction one more time to ensure it's captured
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.extractPendingResponses()
                    }
                }
            }
            
            // For text-based option selections (commands like "1", "2", "3")
            if command.count == 1 && command.first?.isNumber == true {
                // Claude is responding to our option selection
                print("📝 Processing response to option selection: '\(command)'")
                
                // Wait for Claude to finish generating the response
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🔍 Extracting response for numeric option '\(command)'")
                    self.extractPendingResponses()
                }
            }
        }

        // Analyze output
        if currentCommand == "which claude" && output.contains("/claude") {
            claudeDetected = true
        }

        // Check for generation pattern in the NEW output only
        if output.contains("esc to interrupt") {
            if !wasGenerating {
                print("⚡ Generation started")
                claudeState = "Generating response..."
                wasGenerating = true
            }
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

                // Mark last command as complete
                if !commandResponses.isEmpty {
                    commandResponses[commandResponses.count - 1].isComplete = true
                    commandResponses[commandResponses.count - 1].claudeGenerating = false
                }
            }

            wasGenerating = isCurrentlyGenerating
            handleClaudeAnalysis(analysis)
        }

        // Check if generation just ended (we see a prompt after generating)
        if wasGenerating && output.contains("> ") && !output.contains("tokens") {
            print("✅ Generation completed, ready for input")
            claudeState = "Ready for input"
            wasGenerating = false

            // Mark last command as complete
            if !commandResponses.isEmpty {
                commandResponses[commandResponses.count - 1].isComplete = true
                commandResponses[commandResponses.count - 1].claudeGenerating = false
                
                // Extract the response now that generation is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.extractPendingResponses()
                }
            }
        }
        
        // Additional check: if we see a clean prompt line, Claude is ready
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if isClaudeRunning && (trimmedOutput == ">" || (trimmedOutput.contains("> ") && trimmedOutput.count < 10)) {
            if claudeState.contains("Generating") || claudeState.contains("response") {
                print("✅ Detected prompt - Claude is ready")
                claudeState = "Ready for input"
                wasGenerating = false
                
                // Mark last command as complete
                if !commandResponses.isEmpty {
                    let lastIndex = commandResponses.count - 1
                    if !commandResponses[lastIndex].isComplete {
                        commandResponses[lastIndex].isComplete = true
                        commandResponses[lastIndex].claudeGenerating = false
                        
                        // Extract the response
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.extractPendingResponses()
                        }
                    }
                }
            }
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
        // Debug: Show what we're analyzing (only if significant)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed.count > 5 {
            print("🔍 Analyzing \(output.count) chars of output")
        }

        var filesModified: [String] = []
        var filesCreated: [String] = []
        var filesRead: [String] = []
        var buildSuccessful = false
        var testsRun = false
        var error: String?
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

            // Claude generation indicator - look for specific token pattern
            if lineStr.contains("tokens") && lineStr.contains("esc to interrupt") {
                outputType = .working
                print("⚡ Claude is generating")
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
