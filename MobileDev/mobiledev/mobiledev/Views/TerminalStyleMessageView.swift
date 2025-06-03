import SwiftUI

/// Renders messages exactly as they appear in the terminal
struct TerminalStyleMessageView: View {
    let message: ChatMessage
    @State private var isExpanded = false
    
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
                
                // Terminal-style content
                terminalContent
                
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
    
    @ViewBuilder
    private var terminalContent: some View {
        if message.sender == .claude && shouldRenderAsTerminal {
            // Render exactly as terminal output
            Text(message.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        } else {
            // Regular message style
            HStack(alignment: .bottom, spacing: 0) {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .foregroundColor(textColor)
                
                if message.isStreaming {
                    StreamingCursor()
                        .padding(.leading, 2)
                }
            }
            .padding(12)
            .background(bubbleColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
    }
    
    private var shouldRenderAsTerminal: Bool {
        // Render as terminal if it contains terminal UI elements
        message.content.contains("Welcome to Claude Code") ||
        message.content.contains("╭") ||
        message.content.contains("│") ||
        message.content.contains("╰") ||
        message.content.contains("/help") ||
        message.content.contains("cwd:")
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
    
    private var senderColor: Color {
        switch message.sender {
        case .user: return .blue
        case .claude: return .purple
        case .system: return .gray
        }
    }
    
    private var bubbleColor: Color {
        switch message.sender {
        case .user: return Color.blue.opacity(0.1)
        case .claude: return Color(NSColor.controlBackgroundColor)
        case .system: return Color.gray.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        switch message.sender {
        case .user: return Color.blue.opacity(0.3)
        case .claude: return Color.secondary.opacity(0.2)
        case .system: return Color.gray.opacity(0.3)
        }
    }
    
    private var textColor: Color {
        message.sender == .user ? .primary : .primary
    }
}