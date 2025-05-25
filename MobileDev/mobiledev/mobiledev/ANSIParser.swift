//
//  ANSIParser.swift
//  mobiledev
//
//  Advanced ANSI escape sequence parser for extracting clean text
//

import Foundation

class ANSIParser {
    // ANSI escape sequence patterns
    private static let escapePatterns: [(name: String, pattern: String)] = [
        ("CSI", "\\x1b\\[[0-9;]*[A-Za-z]"),           // Control Sequence Introducer
        ("OSC", "\\x1b\\][^\\x07]*\\x07"),             // Operating System Command
        ("SGR", "\\x1b\\[[0-9;]*m"),                  // Select Graphic Rendition (colors)
        ("CursorPos", "\\x1b\\[[0-9;]*[HfJ]"),        // Cursor positioning
        ("ClearLine", "\\x1b\\[K"),                   // Clear line
        ("Mode", "\\x1b\\[\\?[0-9]*[hl]"),            // Mode changes
        ("Title", "\\x1b\\][0-2];.*?\\x07"),          // Window title
        ("Charset", "\\x1b[()][AB012]"),              // Character set selection
        ("SaveRestore", "\\x1b[78]"),                 // Save/restore cursor
        ("Alt", "\\x1b\\[[?0-9;]*[a-zA-Z]"),         // Alternative sequences
        ("Bell", "\\x07"),                            // Bell character
        ("Backspace", "\\x08"),                       // Backspace
        ("Tab", "\\x09"),                             // Tab
        ("CarriageReturn", "\\x0d"),                  // Carriage return
        ("FormFeed", "\\x0c"),                        // Form feed
        ("VerticalTab", "\\x0b")                      // Vertical tab
    ]
    
    struct ParsedSegment {
        let text: String
        let isEscapeSequence: Bool
        let sequenceType: String?
    }
    
    // Parse raw terminal output into segments
    static func parseSegments(from input: String) -> [ParsedSegment] {
        var segments: [ParsedSegment] = []
        var remainingText = input
        
        while !remainingText.isEmpty {
            var foundMatch = false
            
            // Try to match escape sequences
            for (name, pattern) in escapePatterns {
                if let regex = try? NSRegularExpression(pattern: "^" + pattern, options: []) {
                    if let match = regex.firstMatch(in: remainingText, options: [], range: NSRange(location: 0, length: remainingText.utf16.count)) {
                        let matchedString = (remainingText as NSString).substring(with: match.range)
                        segments.append(ParsedSegment(text: matchedString, isEscapeSequence: true, sequenceType: name))
                        remainingText = String(remainingText.dropFirst(matchedString.count))
                        foundMatch = true
                        break
                    }
                }
            }
            
            // If no escape sequence found, take one character as text
            if !foundMatch {
                let char = String(remainingText.prefix(1))
                
                // Combine consecutive text characters
                if let lastSegment = segments.last, !lastSegment.isEscapeSequence {
                    segments[segments.count - 1] = ParsedSegment(
                        text: lastSegment.text + char,
                        isEscapeSequence: false,
                        sequenceType: nil
                    )
                } else {
                    segments.append(ParsedSegment(text: char, isEscapeSequence: false, sequenceType: nil))
                }
                
                remainingText = String(remainingText.dropFirst())
            }
        }
        
        return segments
    }
    
    // Extract clean text from raw input
    static func extractText(from input: String) -> String {
        let segments = parseSegments(from: input)
        let textSegments = segments.filter { !$0.isEscapeSequence }.map { $0.text }
        return textSegments.joined()
    }
    
    // Extract text with line structure preserved
    static func extractTextWithStructure(from input: String) -> String {
        var lines: [String] = []
        var currentLine = ""
        var cursorColumn = 0
        
        let segments = parseSegments(from: input)
        
        for segment in segments {
            if segment.isEscapeSequence {
                // Handle specific escape sequences that affect text layout
                switch segment.sequenceType {
                case "CarriageReturn":
                    cursorColumn = 0
                case "ClearLine":
                    currentLine = String(repeating: " ", count: cursorColumn)
                default:
                    break
                }
            } else {
                // Process text
                for char in segment.text {
                    switch char {
                    case "\n":
                        lines.append(currentLine)
                        currentLine = ""
                        cursorColumn = 0
                    case "\r":
                        cursorColumn = 0
                    case "\t":
                        // Expand tab to spaces (8-space tabs)
                        let spacesToAdd = 8 - (cursorColumn % 8)
                        currentLine += String(repeating: " ", count: spacesToAdd)
                        cursorColumn += spacesToAdd
                    default:
                        if char.isASCII && !char.isControl {
                            // Ensure currentLine is long enough
                            while currentLine.count < cursorColumn {
                                currentLine += " "
                            }
                            
                            if cursorColumn < currentLine.count {
                                // Replace character at position
                                let index = currentLine.index(currentLine.startIndex, offsetBy: cursorColumn)
                                currentLine.replaceSubrange(index...index, with: String(char))
                            } else {
                                // Append character
                                currentLine += String(char)
                            }
                            cursorColumn += 1
                        }
                    }
                }
            }
        }
        
        // Add any remaining line
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        // Clean up lines - remove trailing spaces and empty lines
        let cleanedLines = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        return cleanedLines.joined(separator: "\n")
    }
    
    // Convert raw bytes to a more readable format
    static func formatBytes(_ bytes: ArraySlice<UInt8>) -> String {
        var result = ""
        var textBuffer = ""
        
        for byte in bytes {
            // Check if it's a printable ASCII character
            if byte >= 32 && byte <= 126 {
                textBuffer.append(Character(UnicodeScalar(byte)))
            } else {
                // Flush text buffer if we have any
                if !textBuffer.isEmpty {
                    result += "'\(textBuffer)' "
                    textBuffer = ""
                }
                
                // Add special character representation
                switch byte {
                case 0x1b: result += "[ESC] "
                case 0x0a: result += "[LF] "
                case 0x0d: result += "[CR] "
                case 0x08: result += "[BS] "
                case 0x09: result += "[TAB] "
                case 0x07: result += "[BEL] "
                default: result += String(format: "[%02X] ", byte)
                }
            }
        }
        
        // Flush any remaining text
        if !textBuffer.isEmpty {
            result += "'\(textBuffer)'"
        }
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    // Debug function to show escape sequences
    static func debugParse(_ input: String) -> String {
        let segments = parseSegments(from: input)
        return segments.map { segment in
            if segment.isEscapeSequence {
                return "[\(segment.sequenceType ?? "Unknown"): \(segment.text.debugDescription)]"
            } else {
                return segment.text
            }
        }.joined()
    }
}

// Character extension for control character detection
extension Character {
    var isControl: Bool {
        guard let scalar = self.unicodeScalars.first else { return false }
        return scalar.value < 32 || scalar.value == 127
    }
}