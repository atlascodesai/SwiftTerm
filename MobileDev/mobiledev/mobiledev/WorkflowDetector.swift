//
//  WorkflowDetector.swift
//  mobiledev
//
//  Detects command patterns in Claude's output for workflow automation
//

import Foundation

class WorkflowDetector: ObservableObject {
    @Published var detectedCommands: [DetectedCommand] = []
    @Published var hasNewCommand = false
    
    private var buffer = ""
    private let bufferLimit = 10000
    
    struct DetectedCommand: Identifiable {
        let id = UUID()
        let command: String
        let type: CommandType
        let timestamp: Date
        let context: String
    }
    
    enum CommandType {
        case build
        case test
        case lint
        case commit
        case install
        case run
        case other
        
        var displayName: String {
            switch self {
            case .build: return "Build"
            case .test: return "Test"
            case .lint: return "Lint"
            case .commit: return "Commit"
            case .install: return "Install"
            case .run: return "Run"
            case .other: return "Other"
            }
        }
        
        var iconName: String {
            switch self {
            case .build: return "hammer"
            case .test: return "checkmark.circle"
            case .lint: return "doc.text.magnifyingglass"
            case .commit: return "arrow.up.circle"
            case .install: return "arrow.down.circle"
            case .run: return "play.circle"
            case .other: return "terminal"
            }
        }
    }
    
    private let patterns: [(pattern: String, type: CommandType)] = [
        // Swift patterns
        ("swift\\s+build", .build),
        ("swift\\s+test", .test),
        ("swiftlint", .lint),
        ("xcodebuild.*-scheme.*build", .build),
        ("xcodebuild.*test", .test),
        
        // Git patterns
        ("git\\s+commit", .commit),
        ("git\\s+add", .other),
        ("git\\s+push", .other),
        
        // Node/npm patterns
        ("npm\\s+install", .install),
        ("npm\\s+test", .test),
        ("npm\\s+run\\s+build", .build),
        ("npm\\s+run\\s+lint", .lint),
        ("npm\\s+run\\s+dev", .run),
        
        // Yarn patterns
        ("yarn\\s+install", .install),
        ("yarn\\s+test", .test),
        ("yarn\\s+build", .build),
        ("yarn\\s+lint", .lint),
        
        // Python patterns
        ("python.*-m\\s+pytest", .test),
        ("pip\\s+install", .install),
        ("python.*setup\\.py", .build),
        ("pylint", .lint),
        ("flake8", .lint),
        
        // Rust patterns
        ("cargo\\s+build", .build),
        ("cargo\\s+test", .test),
        ("cargo\\s+clippy", .lint),
        
        // Make patterns
        ("make\\s+test", .test),
        ("make\\s+build", .build),
        ("make\\s+lint", .lint),
    ]
    
    func processOutput(_ text: String) {
        buffer += text
        
        // Keep buffer size manageable
        if buffer.count > bufferLimit {
            buffer = String(buffer.suffix(bufferLimit / 2))
        }
        
        // Special handling for Claude responses
        if text.contains("⏺") {
            // Claude's response follows the ⏺ marker
            detectCommands(in: text)
        }
        
        // Look for command patterns in the recent output
        detectCommands(in: text)
    }
    
    private func detectCommands(in text: String) {
        // Look for code blocks or command suggestions
        let lines = text.components(separatedBy: .newlines)
        
        // Check if we're in a code block context
        let isInCodeBlock = text.contains("```") || buffer.suffix(500).contains("```")
        let isClaudeOutput = text.contains("│") || text.contains("Assistant:") || buffer.suffix(200).contains("Assistant:")
        
        for line in lines {
            // Skip empty lines and Claude UI elements
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty && 
                  !trimmedLine.hasPrefix("│") && 
                  !trimmedLine.hasPrefix("╭") && 
                  !trimmedLine.hasPrefix("╰") else { continue }
            
            // Check if this line contains a command
            for (pattern, type) in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let _ = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
                    
                    // Only extract if it looks like a command context
                    if isInCodeBlock || isClaudeOutput || line.hasPrefix("$") || line.hasPrefix(">") {
                        // Extract the actual command (remove prompts, etc.)
                        let command = extractCommand(from: line)
                        if !command.isEmpty && !isDuplicateCommand(command) {
                            let detected = DetectedCommand(
                                command: command,
                                type: type,
                                timestamp: Date(),
                                context: getContext(around: line)
                            )
                            
                            DispatchQueue.main.async {
                                self.detectedCommands.append(detected)
                                self.hasNewCommand = true
                                print("🎯 Detected command: \(command)")
                            }
                        }
                    }
                    break
                }
            }
        }
    }
    
    private func extractCommand(from line: String) -> String {
        var command = line
        
        // Remove common shell prompts
        let prompts = ["$", ">", "#", "❯", "➜", "→"]
        for prompt in prompts {
            if let range = command.range(of: prompt + " ") {
                command = String(command[range.upperBound...])
                break
            }
        }
        
        // Remove ANSI escape codes
        let ansiPattern = "\\x1b\\[[0-9;]*m"
        if let regex = try? NSRegularExpression(pattern: ansiPattern) {
            command = regex.stringByReplacingMatches(
                in: command,
                range: NSRange(location: 0, length: command.utf16.count),
                withTemplate: ""
            )
        }
        
        // Remove leading/trailing whitespace
        command = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove backticks if present
        if command.hasPrefix("`") && command.hasSuffix("`") {
            command = String(command.dropFirst().dropLast())
        }
        
        return command
    }
    
    private func getContext(around line: String) -> String {
        // Get a few lines of context around the detected command
        let lines = buffer.components(separatedBy: .newlines)
        if let index = lines.firstIndex(where: { $0.contains(line) }) {
            let start = max(0, index - 2)
            let end = min(lines.count, index + 3)
            return lines[start..<end].joined(separator: "\n")
        }
        return line
    }
    
    private func isDuplicateCommand(_ command: String) -> Bool {
        // Check if we've seen this exact command in the last few detections
        let recentCommands = detectedCommands.suffix(5)
        return recentCommands.contains { $0.command == command }
    }
    
    func clearCommands() {
        detectedCommands.removeAll()
        hasNewCommand = false
    }
    
    func dismissNewCommandAlert() {
        hasNewCommand = false
    }
}