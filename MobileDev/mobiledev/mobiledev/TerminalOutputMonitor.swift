//
//  TerminalOutputMonitor.swift
//  mobiledev
//
//  Monitors and analyzes terminal output to detect Claude's state
//

import Foundation
import SwiftUI

class TerminalOutputMonitor: ObservableObject {
    @Published var outputEntries: [OutputEntry] = []
    @Published var isClaudeGenerating = false
    @Published var isWaitingForInput = false
    @Published var lastActivityTime = Date()
    @Published var currentPrompt = ""
    
    private var outputBuffer = ""
    private var lastOutputTime = Date()
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 2.0 // 2 seconds of no output = done generating
    
    struct OutputEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let content: String
        let cleanText: String
        let rawBytes: String
        let formattedBytes: String
        let type: OutputType
    }
    
    enum OutputType {
        case claudeOutput
        case userInput
        case systemPrompt
        case command
        case unknown
        
        var color: Color {
            switch self {
            case .claudeOutput: return .blue
            case .userInput: return .green
            case .systemPrompt: return .orange
            case .command: return .purple
            case .unknown: return .gray
            }
        }
    }
    
    func processOutput(_ text: String, bytes: ArraySlice<UInt8>) {
        let rawHex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        let timestamp = Date()
        
        // Extract clean text
        let cleanText = ANSIParser.extractTextWithStructure(from: text)
        let formattedBytes = ANSIParser.formatBytes(bytes)
        
        // Update activity time
        lastOutputTime = timestamp
        lastActivityTime = timestamp
        
        // Detect output type using clean text for better accuracy
        let outputType = detectOutputType(cleanText.isEmpty ? text : cleanText)
        
        // Create entry
        let entry = OutputEntry(
            timestamp: timestamp,
            content: text,
            cleanText: cleanText,
            rawBytes: rawHex,
            formattedBytes: formattedBytes,
            type: outputType
        )
        
        DispatchQueue.main.async {
            self.outputEntries.append(entry)
            
            // Keep only last 1000 entries
            if self.outputEntries.count > 1000 {
                self.outputEntries.removeFirst(self.outputEntries.count - 1000)
            }
        }
        
        // Analyze for Claude state
        analyzeClaudeState(text)
        
        // Reset silence timer
        resetSilenceTimer()
        
        // Console logging
        logOutput(entry)
    }
    
    private func detectOutputType(_ text: String) -> OutputType {
        // Check for Claude UI elements
        if text.contains("╭") || text.contains("╰") || text.contains("│") {
            return .claudeOutput
        }
        
        // Check for Claude status indicators
        if text.contains("✽") || text.contains("✢") || text.contains("·") || text.contains("✻") {
            return .claudeOutput
        }
        
        // Check for Claude messages
        if text.contains("Welcome to Claude") || text.contains("Greeting…") || 
           text.contains("↑") || text.contains("↓") || text.contains("tokens") ||
           text.contains("esc to interrupt") || text.contains("Connecting…") ||
           text.contains("⏺") || text.contains("Hi!") || text.contains("help you") ||
           text.contains("Marinating") || text.contains("Deliberating") || 
           text.contains("Hatching") || text.contains("…") {
            return .claudeOutput
        }
        
        // Check for system prompts
        if text.contains(" % ") || text.contains("$") || text.contains("#") || text.contains("➜") {
            return .systemPrompt
        }
        
        // Check for command patterns
        let commandPatterns = ["swift", "git", "npm", "yarn", "cargo", "make", "python"]
        for pattern in commandPatterns {
            if text.lowercased().contains(pattern) {
                return .command
            }
        }
        
        // Check for user input patterns
        if text.contains("> ") && !text.contains("│") {
            return .userInput
        }
        
        return .unknown
    }
    
    private func analyzeClaudeState(_ text: String) {
        // Detect if Claude is actively generating
        let claudeGeneratingPatterns = [
            "Greeting…", "Thinking…", "Processing…", "Analyzing…",
            "↑", "↓", "tokens", "esc to interrupt",
            "✽", "✢", "·", "✻"
        ]
        
        for pattern in claudeGeneratingPatterns {
            if text.contains(pattern) {
                DispatchQueue.main.async {
                    if !self.isClaudeGenerating {
                        self.isClaudeGenerating = true
                        print("🟢 Claude is generating...")
                    }
                    self.isWaitingForInput = false
                }
                break
            }
        }
        
        // Detect Claude's input box
        if text.contains("│ >") && text.contains("│") && text.contains("╭") {
            DispatchQueue.main.async {
                if !self.isWaitingForInput || self.currentPrompt != "Claude is ready for input" {
                    self.isWaitingForInput = true
                    self.currentPrompt = "Claude is ready for input"
                    print("🟡 Claude is ready for input")
                }
                self.isClaudeGenerating = false
            }
        }
        
        // Detect terminal prompts waiting for input
        let terminalPromptPatterns = [
            " % ", " $ ", " # ", "➜", "→"
        ]
        
        for pattern in terminalPromptPatterns {
            if text.contains(pattern) && !text.contains("│") {
                let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    if !self.isWaitingForInput || self.currentPrompt != prompt {
                        self.isWaitingForInput = true
                        self.currentPrompt = prompt
                        print("🟡 Terminal waiting for input: \(prompt)")
                    }
                    self.isClaudeGenerating = false
                }
                break
            }
        }
        
        // Claude's actual response is shown with ⏺ 
        if text.contains("⏺") && !text.contains("esc to interrupt") {
            DispatchQueue.main.async {
                if self.isClaudeGenerating {
                    self.isClaudeGenerating = false
                    print("🏁 Claude finished - response delivered")
                }
            }
        }
        
        outputBuffer += text
        if outputBuffer.count > 10000 {
            outputBuffer = String(outputBuffer.suffix(5000))
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { _ in
            DispatchQueue.main.async {
                if self.isClaudeGenerating {
                    self.isClaudeGenerating = false
                    print("🔴 Claude stopped generating (silence detected)")
                }
            }
        }
    }
    
    private func stripAnsiCodes(from text: String) -> String {
        // Remove ANSI escape sequences
        let patterns = [
            "\\x1b\\[[0-9;]*m",      // Color codes
            "\\x1b\\[[0-9]*[A-Z]",   // Cursor movement
            "\\x1b\\[\\?[0-9]*[hl]", // Mode changes
            "\\x1b\\[[0-9;]*[HfJ]",  // Clear/position
            "\\x1b\\].*?\\x07",      // OSC sequences
            "\\x1b\\[K",             // Clear line
            "\u{001b}\\[[^m]*m"      // Any other escape sequences
        ]
        
        var cleanText = text
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                cleanText = regex.stringByReplacingMatches(
                    in: cleanText,
                    range: NSRange(location: 0, length: cleanText.utf16.count),
                    withTemplate: ""
                )
            }
        }
        
        // Also remove common Unicode box drawing characters
        let boxChars = ["╭", "╰", "│", "─", "╮", "╯"]
        let lines = cleanText.components(separatedBy: .newlines)
        let cleanedLines = lines.map { line in
            var cleaned = line
            // Remove box characters from the start and end of lines
            for char in boxChars {
                cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: char))
            }
            return cleaned.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        
        return cleanedLines.joined(separator: "\n")
    }
    
    private var lastLoggedGeneratingState = false
    private var lastLoggedWaitingState = false
    
    private func logOutput(_ entry: OutputEntry) {
        // Use the pre-parsed clean text
        let cleanContent = entry.cleanText
        
        // Skip empty content or just whitespace
        guard !cleanContent.isEmpty else { return }
        
        // Skip logging individual character inputs
        if entry.type == .unknown && cleanContent.count <= 2 {
            return
        }
        
        // Skip only empty UI updates
        if entry.type == .claudeOutput && cleanContent == ">" {
            return
        }
        
        let typeEmoji: String
        switch entry.type {
        case .claudeOutput: typeEmoji = "🤖"
        case .userInput: typeEmoji = "👤"
        case .systemPrompt: typeEmoji = "💻"
        case .command: typeEmoji = "⚡"
        case .unknown: typeEmoji = "❓"
        }
        
        // Special handling for Claude responses with ⏺
        if cleanContent.contains("⏺") {
            // Extract just the response text after ⏺
            if let markerRange = cleanContent.range(of: "⏺") {
                let afterMarker = String(cleanContent[markerRange.upperBound...])
                let cleanedResponse = afterMarker.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedResponse.isEmpty {
                    print("🤖 [\(entry.timestamp.formatted(date: .omitted, time: .standard))] Claude response: \(cleanedResponse)")
                    return
                }
            }
        }
        
        print("\(typeEmoji) [\(entry.timestamp.formatted(date: .omitted, time: .standard))] \(entry.type): \(cleanContent)")
    }
    
    func clearEntries() {
        outputEntries.removeAll()
        outputBuffer = ""
        isClaudeGenerating = false
        isWaitingForInput = false
        currentPrompt = ""
    }
    
    func exportLog() -> String {
        outputEntries.map { entry in
            "[\(entry.timestamp.formatted())] \(entry.type): \(entry.content)"
        }.joined(separator: "\n")
    }
}