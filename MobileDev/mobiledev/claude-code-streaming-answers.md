# Claude Code CLI Streaming Protocol - Complete Analysis

Based on deep analysis of the Claude Code CLI source code, here are the answers to your questions about parsing the streaming output:

## 1. Stream Format & Protocol

### Output Format
Claude Code uses **line-by-line streaming** through stdout with ANSI escape sequences for formatting. The format is:
- **NOT JSON lines** - It's formatted text with ANSI codes
- **NOT SSE** - It's direct terminal output
- Messages are streamed as formatted text chunks with embedded terminal control sequences

### Stream Structure
```
[ANSI codes for formatting]Text content[ANSI reset]
[Progress indicators during processing]
[Tool execution output with formatting]
```

### Delimiters and Markers
- **No explicit delimiters** between chunks - output flows continuously
- Line breaks (`\n`) separate logical lines
- ANSI escape sequences mark formatting changes
- Progress indicators use specific Unicode characters: `⣾ ⣽ ⣻ ⣷`

### Complete Response Indication
- No explicit "end of response" marker
- Response is complete when Claude stops outputting and returns to the prompt
- Tool executions have implicit boundaries (start of tool use → tool output → continuation)

## 2. Message Types & Structure

### Terminal Output Components

1. **Status/Progress Messages**
   ```
   ⣾ Processing...     (cyan, animated spinner)
   ✓ Success message    (green)
   ✗ Error message      (red)
   ⚠ Warning message    (yellow)
   ```

2. **Claude's Response Text**
   - Regular text with potential ANSI formatting
   - Code blocks with syntax highlighting
   - Markdown-style formatting rendered for terminal

3. **Tool Use Output**
   ```
   [Tool execution indicators]
   Tool: [tool_name]
   [Tool output/results]
   ```

4. **System Messages**
   ```
   ◉ IDE connected/disconnected
   ⧉ N lines selected
   Context usage indicators
   ```

### ANSI Color Codes Used
- Reset: `\x1b[0m`
- Bold: `\x1b[1m`
- Dim: `\x1b[2m`
- Colors: `\x1b[31m` (red), `\x1b[32m` (green), `\x1b[33m` (yellow), `\x1b[34m` (blue), `\x1b[35m` (magenta), `\x1b[36m` (cyan)

## 3. Tool Use Patterns

### Tool Execution Format
```
# For bash commands (prefix: !)
! command_here
[command output]

# For file operations
Reading file: /path/to/file
[file content or operation result]

# For memory operations (prefix: #)
# memory content
[confirmation]
```

### Tool Boundaries
- **Start**: Identified by specific prefixes or tool indicators
- **End**: When regular text resumes or another tool starts
- No explicit XML-style tags, just contextual formatting

## 4. Terminal Control Sequences

### Cursor Control
- `\x1b[2K` - Clear entire line
- `\x1b[0G` - Move cursor to start of line
- Used for updating progress indicators without scrolling

### Interactive Elements
- File diffs use color coding (additions in green, deletions in red)
- Progress spinners update in place using cursor control
- Multi-line selections preserve formatting

## 5. Error Handling

### Error Format
```
\x1b[31m✗ Error message here\x1b[0m
[Additional error details]
[Stack trace if applicable]
```

### Stream Interruption Detection
- Check for incomplete ANSI sequences
- Monitor for sudden stream termination
- No explicit "interrupted" marker

## 6. Implementation Example

Here's a Swift implementation for parsing Claude Code output:

```swift
import Foundation

// MARK: - Models
enum MessageSender {
    case user
    case claude
    case system
}

enum MessageType {
    case text(String)
    case toolUse(tool: String, output: String)
    case status(type: StatusType, message: String)
    case error(String)
}

enum StatusType {
    case progress  // ⣾ spinner
    case success   // ✓
    case error     // ✗
    case warning   // ⚠
    case info      // ◉
}

struct ChatMessage {
    let sender: MessageSender
    let content: MessageType
    let timestamp: Date
}

// MARK: - Parser
class ClaudeCodeStreamParser {
    private var buffer = ""
    private var isInToolUse = false
    private var currentToolName = ""
    private var toolOutputBuffer = ""
    private var messages: [ChatMessage] = []
    
    // ANSI code regex
    private let ansiRegex = try! NSRegularExpression(
        pattern: "\\x1b\\[[0-9;]*m",
        options: []
    )
    
    // Status indicators
    private let statusIndicators: [String: StatusType] = [
        "⣾": .progress, "⣽": .progress, "⣻": .progress, "⣷": .progress,
        "✓": .success,
        "✗": .error,
        "⚠": .warning,
        "◉": .info
    ]
    
    func parseStreamChunk(_ chunk: String) -> [ChatMessage] {
        var newMessages: [ChatMessage] = []
        
        // Add chunk to buffer
        buffer += chunk
        
        // Process complete lines
        while let lineBreak = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<lineBreak])
            buffer.removeSubrange(...lineBreak)
            
            if let message = parseLine(line) {
                newMessages.append(message)
                messages.append(message)
            }
        }
        
        return newMessages
    }
    
    private func parseLine(_ line: String) -> ChatMessage? {
        // Strip ANSI codes for analysis
        let cleanLine = stripANSI(line)
        
        // Skip empty lines
        guard !cleanLine.isEmpty else { return nil }
        
        // Check for status messages
        if let status = parseStatusMessage(line, cleanLine) {
            return ChatMessage(
                sender: .system,
                content: status,
                timestamp: Date()
            )
        }
        
        // Check for tool use patterns
        if cleanLine.hasPrefix("!") {
            // Bash command
            startToolUse(tool: "bash", command: String(cleanLine.dropFirst()).trimmingCharacters(in: .whitespaces))
            return nil
        }
        
        if cleanLine.hasPrefix("Reading file:") || 
           cleanLine.hasPrefix("Writing file:") ||
           cleanLine.hasPrefix("Editing file:") {
            let tool = cleanLine.components(separatedBy: ":")[0]
            startToolUse(tool: tool, command: cleanLine)
            return nil
        }
        
        // Handle tool output collection
        if isInToolUse {
            toolOutputBuffer += line + "\n"
            
            // Simple heuristic: tool use ends when we see Claude's text resume
            // This would need refinement based on actual patterns
            if shouldEndToolUse(cleanLine) {
                let message = ChatMessage(
                    sender: .claude,
                    content: .toolUse(tool: currentToolName, output: toolOutputBuffer),
                    timestamp: Date()
                )
                endToolUse()
                return message
            }
            return nil
        }
        
        // Regular Claude response text
        return ChatMessage(
            sender: .claude,
            content: .text(line), // Keep ANSI for formatting
            timestamp: Date()
        )
    }
    
    private func stripANSI(_ text: String) -> String {
        let range = NSRange(location: 0, length: text.utf16.count)
        return ansiRegex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: ""
        )
    }
    
    private func parseStatusMessage(_ line: String, _ cleanLine: String) -> MessageType? {
        // Check first character for status indicator
        let firstChar = String(cleanLine.prefix(1))
        if let statusType = statusIndicators[firstChar] {
            let message = String(cleanLine.dropFirst()).trimmingCharacters(in: .whitespaces)
            return .status(type: statusType, message: message)
        }
        
        // Check for error patterns
        if cleanLine.contains("Error:") || cleanLine.contains("error:") {
            return .error(cleanLine)
        }
        
        return nil
    }
    
    private func startToolUse(tool: String, command: String) {
        isInToolUse = true
        currentToolName = tool
        toolOutputBuffer = command + "\n"
    }
    
    private func endToolUse() {
        isInToolUse = false
        currentToolName = ""
        toolOutputBuffer = ""
    }
    
    private func shouldEndToolUse(_ line: String) -> Bool {
        // Heuristics to detect end of tool output
        // This needs refinement based on actual patterns
        return line.isEmpty || 
               (!line.hasPrefix(" ") && !line.hasPrefix("\t") && line.count > 10)
    }
}

// MARK: - Usage Example
class ClaudeCodeInterface {
    private let parser = ClaudeCodeStreamParser()
    
    func handleOutput(from process: LocalProcess) {
        // Capture stdout line by line
        process.onStdout = { [weak self] data in
            guard let self = self,
                  let output = String(data: data, encoding: .utf8) else { return }
            
            let messages = self.parser.parseStreamChunk(output)
            
            for message in messages {
                self.processMessage(message)
            }
        }
    }
    
    private func processMessage(_ message: ChatMessage) {
        switch message.content {
        case .text(let content):
            // Display formatted text (with ANSI codes)
            displayFormattedText(content)
            
        case .toolUse(let tool, let output):
            // Handle tool execution display
            displayToolUse(tool: tool, output: output)
            
        case .status(let type, let message):
            // Handle status messages
            displayStatus(type: type, message: message)
            
        case .error(let error):
            // Handle errors
            displayError(error)
        }
    }
    
    private func displayFormattedText(_ text: String) {
        // Pass through to SwiftTerm with ANSI codes intact
        // SwiftTerm will handle the formatting
    }
    
    private func displayToolUse(tool: String, output: String) {
        // Format tool use for display
        let formatted = """
        [Tool: \(tool)]
        \(output)
        """
        // Display in SwiftTerm
    }
    
    private func displayStatus(type: StatusType, message: String) {
        // Handle different status types with appropriate formatting
    }
    
    private func displayError(_ error: String) {
        // Display error with red formatting
    }
}
```

## Key Implementation Considerations

1. **ANSI Preservation**: Keep ANSI codes in the text for SwiftTerm to render colors
2. **Line Buffering**: Buffer incomplete lines until newline is received
3. **Tool Detection**: Use contextual clues (prefixes, patterns) to detect tool use
4. **State Management**: Track whether currently in tool output or regular text
5. **Error Recovery**: Handle incomplete sequences and unexpected stream termination

## Additional Notes

- Claude Code uses React-like components internally but outputs formatted terminal text
- The exact tool boundary detection may need refinement based on testing
- Progress indicators update in-place using cursor control sequences
- Multi-line code blocks are handled through proper line buffering

This implementation provides a foundation for parsing Claude Code output in your SwiftUI terminal app. You may need to adjust the heuristics based on actual output patterns observed during testing.