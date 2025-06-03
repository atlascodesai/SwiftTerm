import Foundation

/// Cleans terminal content for display in chat messages
struct TerminalContentCleaner {
    
    /// Clean terminal box-drawing and formatting characters
    static func cleanTerminalContent(_ content: String) -> String {
        var cleaned = content
        
        // Remove ANSI escape sequences
        cleaned = stripANSI(cleaned)
        
        // Remove box-drawing characters and terminal UI chrome
        let lines = cleaned.split(separator: "\n", omittingEmptySubsequences: false)
        var cleanedLines: [String] = []
        
        for line in lines {
            var lineStr = String(line)
            
            // Skip lines that are primarily box-drawing
            if isBoxDrawingLine(lineStr) {
                continue
            }
            
            // Remove box characters from content lines
            lineStr = removeBoxCharacters(from: lineStr)
            
            // Skip empty lines that result from cleaning
            if !lineStr.trimmingCharacters(in: .whitespaces).isEmpty {
                cleanedLines.append(lineStr)
            }
        }
        
        return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Strip ANSI escape sequences
    static func stripANSI(_ text: String) -> String {
        // Remove all ANSI escape sequences
        let patterns = [
            "\\x1b\\[[0-9;]*m",        // Color codes
            "\\x1b\\[[0-9]*[A-Za-z]",   // Cursor movement
            "\\x1b\\[\\?[0-9]+[hl]",    // Terminal modes
            "\\x1b\\[[0-9]+;[0-9]+H",   // Cursor position
            "\\x1b\\[[0-9]+J",          // Clear screen
            "\\x1b\\[[0-9]+K",          // Clear line
            "\\x1b\\]0;[^\\x07]*\\x07", // Terminal title
            "\\r"                       // Carriage returns
        ]
        
        var result = text
        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        
        return result
    }
    
    /// Check if a line is primarily box-drawing
    static func isBoxDrawingLine(_ line: String) -> Bool {
        let boxChars = ["╭", "╮", "╰", "╯", "─", "│", "├", "┤", "┬", "┴", "┼"]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Skip lines that are just box borders
        if trimmed.hasPrefix("╭─") && trimmed.hasSuffix("─╮") { return true }
        if trimmed.hasPrefix("╰─") && trimmed.hasSuffix("─╯") { return true }
        if trimmed.hasPrefix("├─") || trimmed.hasPrefix("│─") { return true }
        
        // Count box characters vs content
        let boxCharCount = trimmed.filter { char in
            boxChars.contains(String(char))
        }.count
        
        // If more than 50% of the line is box characters, skip it
        return trimmed.count > 0 && Double(boxCharCount) / Double(trimmed.count) > 0.5
    }
    
    /// Remove box-drawing characters from content lines
    static func removeBoxCharacters(from line: String) -> String {
        var cleaned = line
        
        // Remove leading/trailing box characters
        cleaned = cleaned.replacingOccurrences(of: "^[│├┤]+\\s*", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\s*[│├┤]+$", with: "", options: .regularExpression)
        
        // Remove other box-drawing characters
        let boxChars = ["╭", "╮", "╰", "╯", "─", "┬", "┴", "┼"]
        for char in boxChars {
            cleaned = cleaned.replacingOccurrences(of: char, with: "")
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    /// Extract just the Claude welcome message content
    static func extractClaudeWelcome(from content: String) -> String {
        let cleaned = cleanTerminalContent(content)
        let lines = cleaned.split(separator: "\n")
        
        var welcomeLines: [String] = []
        var foundWelcome = false
        
        for line in lines {
            let lineStr = String(line).trimmingCharacters(in: .whitespaces)
            
            if lineStr.contains("Welcome to Claude Code!") {
                foundWelcome = true
                welcomeLines.append(lineStr)
            } else if foundWelcome && !lineStr.isEmpty {
                // Continue capturing welcome message lines
                welcomeLines.append(lineStr)
                
                // Stop at cwd line
                if lineStr.starts(with: "cwd:") {
                    break
                }
            }
        }
        
        return welcomeLines.joined(separator: "\n")
    }
    
    /// Extract the core message content (for "hi" response, etc)
    static func extractMessageContent(from content: String) -> String {
        // First strip ANSI codes
        let strippedContent = stripANSI(content)
        
        // Remove progress indicators and UI chrome
        let lines = strippedContent.split(separator: "\n", omittingEmptySubsequences: false)
        var messageLines: [String] = []
        var inResponse = false
        
        for line in lines {
            let lineStr = String(line)
            let trimmed = lineStr.trimmingCharacters(in: .whitespaces)
            
            // Skip progress indicators
            if lineStr.contains("⏺") || lineStr.contains("⣾") || 
               lineStr.contains("⣽") || lineStr.contains("⣻") || 
               lineStr.contains("⣷") {
                // But if there's text after the indicator, capture it
                if let textStart = lineStr.firstIndex(where: { !["⏺", "⣾", "⣽", "⣻", "⣷", " "].contains(String($0)) }) {
                    let messageText = String(lineStr[textStart...])
                    if !messageText.isEmpty {
                        messageLines.append(messageText)
                        inResponse = true
                    }
                }
                continue
            }
            
            // Skip "? for shortcuts"
            if trimmed == "? for shortcuts" || trimmed == "?" {
                continue
            }
            
            // Skip standalone prompts
            if trimmed == ">" {
                continue
            }
            
            // Skip box drawing lines
            if isBoxDrawingLine(lineStr) {
                continue
            }
            
            // Remove box characters from content lines
            let cleaned = removeBoxCharacters(from: lineStr)
            
            // Add non-empty content lines
            if !cleaned.trimmingCharacters(in: .whitespaces).isEmpty {
                messageLines.append(cleaned)
                inResponse = true
            }
        }
        
        return messageLines.joined(separator: "\n")
    }
}