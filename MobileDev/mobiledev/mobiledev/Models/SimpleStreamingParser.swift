import Foundation

// Simplified streaming parser that can be easily integrated
// This version focuses on the core parsing logic without complex delegate patterns

class SimpleStreamingParser {
    
    // MARK: - Public Interface
    
    /// Parse a chunk of terminal output and return structured messages
    static func parseChunk(_ text: String) -> [StreamMessage] {
        var messages: [StreamMessage] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        
        for line in lines {
            let lineStr = String(line)
            if let message = parseLine(lineStr) {
                messages.append(message)
            }
        }
        
        return messages
    }
    
    /// Extract ANSI codes for display purposes
    static func preserveANSI(_ text: String) -> String {
        return text // Keep ANSI codes intact for terminal display
    }
    
    /// Strip ANSI codes for pattern detection
    static func stripANSI(_ text: String) -> String {
        return text.replacingOccurrences(
            of: "\\x1b\\[[0-9;]*m",
            with: "",
            options: .regularExpression
        )
    }
    
    // MARK: - Message Types
    
    static func parseLine(_ line: String) -> StreamMessage? {
        let cleanLine = stripANSI(line)
        guard !cleanLine.isEmpty else { return nil }
        
        // Status indicators
        if cleanLine.hasPrefix("⣾") || cleanLine.hasPrefix("⣽") || 
           cleanLine.hasPrefix("⣻") || cleanLine.hasPrefix("⣷") {
            return StreamMessage(
                type: .progress,
                content: line,
                cleanContent: cleanLine,
                timestamp: Date()
            )
        }
        
        if cleanLine.hasPrefix("✓") {
            return StreamMessage(
                type: .success,
                content: line,
                cleanContent: cleanLine,
                timestamp: Date()
            )
        }
        
        if cleanLine.hasPrefix("✗") {
            return StreamMessage(
                type: .error,
                content: line,
                cleanContent: cleanLine,
                timestamp: Date()
            )
        }
        
        if cleanLine.hasPrefix("⚠") {
            return StreamMessage(
                type: .warning,
                content: line,
                cleanContent: cleanLine,
                timestamp: Date()
            )
        }
        
        // Tool use detection
        if cleanLine.hasPrefix("!") {
            return StreamMessage(
                type: .bashCommand,
                content: line,
                cleanContent: cleanLine,
                timestamp: Date()
            )
        }
        
        if cleanLine.hasPrefix("Reading file:") || 
           cleanLine.hasPrefix("Writing file:") ||
           cleanLine.hasPrefix("Editing file:") {
            return StreamMessage(
                type: .fileOperation,
                content: line,
                cleanContent: cleanLine,
                timestamp: Date()
            )
        }
        
        // Code blocks
        if cleanLine.hasPrefix("```") {
            return StreamMessage(
                type: .codeBlock,
                content: line,
                cleanContent: cleanLine,
                timestamp: Date()
            )
        }
        
        // Claude state detection
        if cleanLine.contains("Welcome to Claude Code!") {
            return StreamMessage(
                type: .claudeReady,
                content: line,
                cleanContent: cleanLine,
                timestamp: Date()
            )
        }
        
        if cleanLine.contains("esc to interrupt") {
            return StreamMessage(
                type: .claudeThinking,
                content: line,
                cleanContent: cleanLine,
                timestamp: Date()
            )
        }
        
        // Regular text
        return StreamMessage(
            type: .text,
            content: line,
            cleanContent: cleanLine,
            timestamp: Date()
        )
    }
    
    // MARK: - Option Detection
    
    static func detectOptions(in text: String) -> [String] {
        let lines = text.split(separator: "\n")
        var options: [String] = []
        
        for line in lines {
            let cleanLine = stripANSI(String(line)).trimmingCharacters(in: .whitespaces)
            
            // Look for numbered options
            if cleanLine.matches("^\\d+\\.\\s+") {
                options.append(cleanLine)
            }
            
            // Look for UI-based options with ❯ marker
            if cleanLine.contains("❯") && cleanLine.matches("\\d+\\.") {
                let cleaned = cleanLine.replacingOccurrences(of: "│", with: "")
                                      .replacingOccurrences(of: "❯", with: "")
                                      .trimmingCharacters(in: .whitespaces)
                options.append(cleaned)
            }
        }
        
        return options
    }
    
    // MARK: - State Detection
    
    static func detectClaudeState(in text: String) -> ClaudeStreamState {
        let cleanText = stripANSI(text)
        
        if cleanText.contains("Welcome to Claude Code!") {
            return .ready
        }
        
        if cleanText.contains("Starting Claude...") {
            return .starting
        }
        
        if cleanText.contains("esc to interrupt") || cleanText.contains("⏺") {
            return .thinking
        }
        
        if cleanText.contains("> ") && cleanText.contains("? for shortcuts") {
            return .ready
        }
        
        return .unknown
    }
}

// MARK: - Supporting Types

struct StreamMessage: Identifiable {
    let id = UUID()
    let type: StreamMessageType
    let content: String      // Original with ANSI
    let cleanContent: String // Stripped for processing
    let timestamp: Date
    
    init(type: StreamMessageType, content: String, cleanContent: String, timestamp: Date) {
        self.type = type
        self.content = content
        self.cleanContent = cleanContent
        self.timestamp = timestamp
    }
}

enum StreamMessageType {
    case text
    case progress
    case success
    case error
    case warning
    case bashCommand
    case fileOperation
    case codeBlock
    case claudeReady
    case claudeThinking
}

enum ClaudeStreamState {
    case unknown
    case starting
    case ready
    case thinking
}

// MARK: - String Extension

extension String {
    func matches(_ pattern: String) -> Bool {
        return self.range(of: pattern, options: .regularExpression) != nil
    }
}