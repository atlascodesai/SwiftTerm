//
//  TerminalRenderingExample.swift
//  mobiledev
//
//  Demonstrates using SwiftTerm for rendering terminal output without a process
//

import SwiftUI
import SwiftTerm

/// A minimal terminal delegate for display-only terminals
class DisplayOnlyTerminalDelegate: TerminalDelegate {
    func send(source: Terminal, data: ArraySlice<UInt8>) {
        // No-op: Display-only terminal doesn't send data anywhere
    }
    
    func showCursor(source: Terminal) {}
    func hideCursor(source: Terminal) {}
    func setTerminalTitle(source: Terminal, title: String) {}
    func setTerminalIconTitle(source: Terminal, title: String) {}
    func isProcessTrusted(source: Terminal) -> Bool { return false }
    func mouseModeChanged(source: Terminal) {}
    func colorChanged(source: Terminal, idx: Int?) {}
}

/// Example class showing how to use Terminal for rendering pre-captured output
class TerminalRenderer: ObservableObject {
    private let terminal: Terminal
    private let delegate: DisplayOnlyTerminalDelegate
    
    @Published var currentContent: String = ""
    
    init(cols: Int = 80, rows: Int = 24) {
        self.delegate = DisplayOnlyTerminalDelegate()
        self.terminal = Terminal(
            delegate: delegate,
            options: TerminalOptions(cols: cols, rows: rows)
        )
    }
    
    /// Feed pre-captured terminal data for display
    func feedCapturedData(_ data: Data) {
        // Convert data to array slice of bytes
        let bytes = [UInt8](data)
        terminal.feed(byteArray: bytes)
        
        // Update the current content
        updateContent()
    }
    
    /// Feed a string containing ANSI escape sequences
    func feedAnsiString(_ text: String) {
        terminal.feed(text: text)
        updateContent()
    }
    
    /// Feed raw bytes containing terminal control sequences
    func feedBytes(_ bytes: [UInt8]) {
        terminal.feed(byteArray: bytes)
        updateContent()
    }
    
    /// Get the current terminal buffer as text
    func getBufferText() -> String {
        let data = terminal.getBufferAsData()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Get a specific line with attributes
    func getLine(_ row: Int) -> BufferLine? {
        guard row >= 0 && row < terminal.buffer.lines.count else {
            return nil
        }
        return terminal.buffer.lines[row]
    }
    
    /// Get the terminal buffer for custom rendering
    var buffer: Buffer {
        return terminal.buffer
    }
    
    /// Get terminal dimensions
    var cols: Int { terminal.cols }
    var rows: Int { terminal.rows }
    
    private func updateContent() {
        currentContent = getBufferText()
    }
}

// MARK: - SwiftUI Example View

struct TerminalRenderingExampleView: View {
    @StateObject private var renderer = TerminalRenderer()
    @State private var sampleOutput = """
    \u{1b}[1;32mHello from SwiftTerm!\u{1b}[0m
    This is a \u{1b}[31mred\u{1b}[0m word and this is \u{1b}[34mblue\u{1b}[0m.
    \u{1b}[1mBold text\u{1b}[0m and \u{1b}[4munderlined\u{1b}[0m text.
    
    Progress: [\u{1b}[42m          \u{1b}[0m] 50%
    """
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Terminal Rendering Example")
                .font(.title)
            
            GroupBox("Input ANSI Text") {
                TextEditor(text: $sampleOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 150)
            }
            
            HStack {
                Button("Render Terminal Output") {
                    renderer.feedAnsiString(sampleOutput)
                }
                
                Button("Clear") {
                    renderer.feedAnsiString("\u{1b}[2J\u{1b}[H") // Clear screen and move to home
                }
                
                Button("Add Timestamp") {
                    let timestamp = Date().formatted()
                    renderer.feedAnsiString("\n\u{1b}[90m[\(timestamp)]\u{1b}[0m\n")
                }
            }
            
            GroupBox("Rendered Output (Plain Text)") {
                ScrollView {
                    Text(renderer.currentContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 200)
                .background(Color.black.opacity(0.9))
                .foregroundColor(.green)
            }
            
            Text("Note: This shows the terminal buffer content. For full styled rendering, use TerminalView.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Usage Examples

extension TerminalRenderer {
    /// Example: Feed captured output from a command
    func feedCommandOutput() {
        // Simulate output from 'ls -la' with colors
        let output = """
        total 64
        drwxr-xr-x  10 user  staff   320 Apr  1 12:00 \u{1b}[34m.\u{1b}[0m
        drwxr-xr-x  20 user  staff   640 Apr  1 11:00 \u{1b}[34m..\u{1b}[0m
        -rw-r--r--   1 user  staff  1024 Apr  1 10:00 README.md
        -rwxr-xr-x   1 user  staff  2048 Apr  1 09:00 \u{1b}[32mscript.sh\u{1b}[0m
        """
        feedAnsiString(output)
    }
    
    /// Example: Feed captured Claude output with formatting
    func feedClaudeOutput() {
        let claudeOutput = """
        \u{1b}[1mClaude:\u{1b}[0m I'll help you create a terminal rendering example.
        
        Here's what we can do:
        1. \u{1b}[32m✓\u{1b}[0m Create a display-only terminal
        2. \u{1b}[32m✓\u{1b}[0m Feed pre-captured ANSI sequences
        3. \u{1b}[32m✓\u{1b}[0m Extract buffer content
        
        \u{1b}[33mNote:\u{1b}[0m This approach doesn't require a running process!
        """
        feedAnsiString(claudeOutput)
    }
    
    /// Example: Feed raw terminal recording data
    func feedRecordedSession(_ recordingData: Data) {
        // This could be data from script/ttyrec or asciinema recordings
        feedCapturedData(recordingData)
    }
}

// MARK: - Preview

struct TerminalRenderingExampleView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalRenderingExampleView()
    }
}