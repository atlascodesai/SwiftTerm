//
//  ClaudeOutputRenderer.swift
//  mobiledev
//
//  Example showing how to render captured Claude terminal output
//

import SwiftUI
import SwiftTerm

/// A specialized renderer for Claude's terminal output
class ClaudeOutputRenderer: ObservableObject {
    private let terminal: Terminal
    private let delegate: DisplayOnlyTerminalDelegate
    
    @Published var isReady = false
    @Published var hasContent = false
    
    init() {
        self.delegate = DisplayOnlyTerminalDelegate()
        self.terminal = Terminal(
            delegate: delegate,
            options: TerminalOptions(cols: 120, rows: 40)
        )
        self.isReady = true
    }
    
    /// Feed captured Claude output (raw bytes from terminal)
    func feedCapturedOutput(_ data: Data) {
        let bytes = [UInt8](data)
        terminal.feed(byteArray: bytes)
        hasContent = true
    }
    
    /// Feed captured Claude output (string with ANSI sequences)
    func feedCapturedString(_ output: String) {
        terminal.feed(text: output)
        hasContent = true
    }
    
    /// Get the terminal for direct access
    var terminalInstance: Terminal {
        return terminal
    }
    
    /// Clear the terminal
    func clear() {
        // Send clear screen sequence
        terminal.feed(text: "\u{1b}[2J\u{1b}[H")
        hasContent = false
    }
    
    /// Get current buffer content as text
    func getPlainText() -> String {
        let data = terminal.getBufferAsData()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// A view that renders Claude output using a native TerminalView
struct ClaudeOutputView: View {
    @StateObject private var renderer = ClaudeOutputRenderer()
    @State private var capturedOutput = ""
    @State private var showingCapture = false
    
    // Sample Claude outputs for testing
    let sampleOutputs = [
        "Simple Response": """
        \u{1b}[1mClaude:\u{1b}[0m I'll help you with that request.
        
        Here's what I found:
        • First point
        • Second point
        • Third point
        """,
        
        "Code Block": """
        \u{1b}[1mClaude:\u{1b}[0m Here's the code you requested:
        
        \u{1b}[36m```swift\u{1b}[0m
        \u{1b}[32mfunc\u{1b}[0m \u{1b}[33mhelloWorld\u{1b}[0m() {
            \u{1b}[32mprint\u{1b}[0m(\u{1b}[31m"Hello, World!"\u{1b}[0m)
        }
        \u{1b}[36m```\u{1b}[0m
        """,
        
        "Progress Output": """
        \u{1b}[1mClaude:\u{1b}[0m Processing your request...
        
        \u{1b}[32m✓\u{1b}[0m Analyzing code
        \u{1b}[32m✓\u{1b}[0m Finding patterns
        \u{1b}[33m⟳\u{1b}[0m Generating response...
        
        Progress: [\u{1b}[42m████████  \u{1b}[0m] 80%
        """,
        
        "Options Menu": """
        \u{1b}[1mClaude:\u{1b}[0m What would you like to do next?
        
        \u{1b}[36m❯\u{1b}[0m 1. Continue with current approach
          2. Try a different solution
          3. Exit and save progress
        
        Please select an option (1-3):
        """
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Claude Output Renderer")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Button("Capture Current") {
                    capturedOutput = renderer.getPlainText()
                    showingCapture = true
                }
                
                Button("Clear") {
                    renderer.clear()
                }
            }
            .padding()
            
            // Sample buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Array(sampleOutputs.keys.sorted()), id: \.self) { key in
                        Button(action: {
                            if let output = sampleOutputs[key] {
                                renderer.feedCapturedString(output + "\n")
                            }
                        }) {
                            Text(key)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Terminal view wrapper
            if renderer.isReady {
                ClaudeTerminalWrapper(terminal: renderer.terminalInstance)
                    .background(Color.black)
                    .cornerRadius(8)
                    .padding()
            } else {
                ProgressView("Initializing terminal...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingCapture) {
            VStack {
                Text("Captured Output")
                    .font(.title2)
                    .padding()
                
                ScrollView {
                    Text(capturedOutput)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding()
                
                Button("Close") {
                    showingCapture = false
                }
                .padding()
            }
        }
    }
}

/// Wrapper for the native TerminalView
struct ClaudeTerminalWrapper: NSViewRepresentable {
    let terminal: Terminal
    
    class ClaudeTerminalView: TerminalView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }
        
        private func setup() {
            // Configure appearance for Claude output
            installColors([
                // ANSI colors optimized for Claude output
                TTColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),    // black
                TTColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0),    // red
                TTColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0),    // green
                TTColor(red: 0.8, green: 0.8, blue: 0.2, alpha: 1.0),    // yellow
                TTColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0),    // blue
                TTColor(red: 0.8, green: 0.2, blue: 0.8, alpha: 1.0),    // magenta
                TTColor(red: 0.2, green: 0.8, blue: 0.8, alpha: 1.0),    // cyan
                TTColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0),    // white
                // Bright colors
                TTColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0),    // bright black
                TTColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0),    // bright red
                TTColor(red: 0.4, green: 1.0, blue: 0.4, alpha: 1.0),    // bright green
                TTColor(red: 1.0, green: 1.0, blue: 0.6, alpha: 1.0),    // bright yellow
                TTColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0),    // bright blue
                TTColor(red: 1.0, green: 0.4, blue: 1.0, alpha: 1.0),    // bright magenta
                TTColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 1.0),    // bright cyan
                TTColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),    // bright white
            ])
            
            // Set font
            if let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular) {
                self.font = monoFont
            }
        }
    }
    
    func makeNSView(context: Context) -> TerminalView {
        let view = ClaudeTerminalView(frame: .zero)
        
        // Important: Set the terminal AFTER view initialization
        // This replaces the terminal created by TerminalView's init
        view.terminal = terminal
        
        return view
    }
    
    func updateNSView(_ nsView: TerminalView, context: Context) {
        // The terminal content is updated through the Terminal instance
        // No need to update here
    }
}

// MARK: - Integration with existing code

extension ClaudeOutputRenderer {
    /// Feed output captured from TerminalViewModel or other sources
    func feedFromViewModel(_ content: String) {
        // Process the content to ensure it has proper formatting
        feedCapturedString(content)
    }
    
    /// Feed specific response sections
    func feedResponse(_ response: TerminalResponse) {
        if !response.rawResponse.isEmpty {
            feedCapturedString(response.rawResponse)
        }
    }
}

// MARK: - Preview

struct ClaudeOutputView_Previews: PreviewProvider {
    static var previews: some View {
        ClaudeOutputView()
            .frame(width: 800, height: 600)
    }
}