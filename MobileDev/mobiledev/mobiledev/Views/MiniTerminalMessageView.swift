import SwiftUI
import SwiftTerm

/// A mini terminal view that renders content using SwiftTerm's formatting
struct MiniTerminalMessageView: View {
    let message: ChatMessage
    @State private var terminal: Terminal?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.sender.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.sender.isUser ? .trailing : .leading, spacing: 8) {
                // Sender label
                HStack(spacing: 4) {
                    Image(systemName: senderIcon)
                        .font(.caption)
                    Text(senderName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(senderColor)
                
                // Mini terminal content
                if message.sender == .claude {
                    MiniTerminalView(content: message.content)
                        .frame(maxWidth: 600)
                        .cornerRadius(8)
                } else {
                    // Regular message for user
                    regularMessageView
                }
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.sender.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
    }
    
    private var regularMessageView: some View {
        Text(message.content)
            .font(.body)
            .textSelection(.enabled)
            .foregroundColor(textColor)
            .padding(12)
            .background(bubbleColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
    
    // MARK: - Styling
    
    private var senderIcon: String {
        switch message.sender {
        case .user: return "person.circle.fill"
        case .claude: return "brain"
        case .system: return "gear"
        }
    }
    
    private var senderName: String {
        switch message.sender {
        case .user: return "You"
        case .claude: return "Claude"
        case .system: return "System"
        }
    }
    
    private var senderColor: SwiftUI.Color {
        switch message.sender {
        case .user: return .blue
        case .claude: return .purple
        case .system: return .gray
        }
    }
    
    private var bubbleColor: SwiftUI.Color {
        switch message.sender {
        case .user: return SwiftUI.Color.blue.opacity(0.1)
        case .claude: return SwiftUI.Color(NSColor.controlBackgroundColor)
        case .system: return SwiftUI.Color.gray.opacity(0.1)
        }
    }
    
    private var borderColor: SwiftUI.Color {
        switch message.sender {
        case .user: return SwiftUI.Color.blue.opacity(0.3)
        case .claude: return SwiftUI.Color.secondary.opacity(0.2)
        case .system: return SwiftUI.Color.gray.opacity(0.3)
        }
    }
    
    private var textColor: SwiftUI.Color {
        .primary
    }
}

/// Mini terminal view using SwiftTerm's rendering
struct MiniTerminalView: NSViewRepresentable {
    let content: String
    
    func makeNSView(context: Context) -> TerminalView {
        let terminalView = TerminalView()
        
        // Configure terminal
        let terminal = Terminal(delegate: context.coordinator, options: TerminalOptions())
        terminalView.terminal = terminal
        terminalView.terminal.silentLog = true
        
        // Set appropriate size
        terminal.resize(cols: 80, rows: calculateRows())
        
        // Style the terminal
        terminalView.configureNativeColors()
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        // Feed the content
        terminal.feed(text: content)
        
        // Make it read-only
        // Terminal is selectable by default
        terminalView.allowMouseReporting = false
        
        return terminalView
    }
    
    func updateNSView(_ nsView: TerminalView, context: Context) {
        // Update content if needed
        if let terminal = nsView.terminal {
            terminal.resetToInitialState()
            terminal.feed(text: content)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func calculateRows() -> Int {
        // Calculate number of rows needed based on content
        let lines = content.split(separator: "\n").count
        return max(lines + 1, 5) // Minimum 5 rows
    }
    
    class Coordinator: NSObject, TerminalDelegate {
        func send(source: Terminal, data: ArraySlice<UInt8>) {
            // Read-only, don't send anything
        }
        
        func showCursor(source: Terminal) {}
        func hideCursor(source: Terminal) {}
        func getBgColor(source: Terminal) -> NSColor? { return .textBackgroundColor }
        func getFgColor(source: Terminal) -> NSColor? { return .labelColor }
        func setTerminalTitle(source: Terminal, title: String) {}
        func sizeChanged(source: Terminal) {}
        func scrolled(source: Terminal, yDisp: Int) {}
    }
}

// Color configuration extension
extension TerminalView {
    func configureNativeColors() {
        let theme = NSApplication.shared.effectiveAppearance.name == .darkAqua ? "dark" : "light"
        
        if theme == "dark" {
            // Dark mode colors
            nativeForegroundColor = NSColor.labelColor
            nativeBackgroundColor = NSColor(calibratedWhite: 0.11, alpha: 1.0)
        } else {
            // Light mode colors  
            nativeForegroundColor = NSColor.labelColor
            nativeBackgroundColor = NSColor.textBackgroundColor
        }
    }
}