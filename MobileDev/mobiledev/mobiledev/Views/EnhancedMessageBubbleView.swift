import SwiftUI

struct EnhancedMessageBubbleView: View {
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
                
                // Message content based on type
                messageContent
                
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
    private var messageContent: some View {
        switch message.messageType {
        case .text:
            textMessageView
        case .code:
            codeBlockView
        case .toolUse:
            toolUseView
        case .status:
            statusMessageView
        case .error:
            errorMessageView
        }
    }
    
    private var textMessageView: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(message.content)
                .font(shouldUseMonospace ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
                .foregroundColor(textColor)
            
            // Show streaming cursor
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
    
    private var shouldUseMonospace: Bool {
        // Use monospace for Claude's system messages
        message.sender == .claude && 
        (message.content.contains("Welcome to Claude Code") || 
         message.content.contains("cwd:"))
    }
    
    private var codeBlockView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.caption)
                Text(message.metadata?.language ?? "Code")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Button(action: copyCode) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(message.content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var toolUseView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: toolIcon)
                    .font(.caption)
                Text(message.metadata?.toolName ?? "Tool")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                if !isExpanded {
                    Text("Show output")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .foregroundColor(.secondary)
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                Text(message.content)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(6)
            }
        }
        .padding(12)
        .background(toolBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(toolBorderColor, lineWidth: 1)
        )
    }
    
    private var statusMessageView: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.caption)
            Text(message.content)
                .font(.caption)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusBackgroundColor)
        .cornerRadius(8)
    }
    
    private var errorMessageView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            Text(message.content)
                .font(.body)
                .textSelection(.enabled)
        }
        .foregroundColor(.white)
        .padding(12)
        .background(Color.red)
        .cornerRadius(12)
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
    
    private var toolIcon: String {
        switch message.metadata?.toolName {
        case "bash": return "terminal"
        case "file": return "doc"
        default: return "wrench"
        }
    }
    
    private var toolBackgroundColor: Color {
        Color.orange.opacity(0.1)
    }
    
    private var toolBorderColor: Color {
        Color.orange.opacity(0.3)
    }
    
    private var statusIcon: String {
        switch message.metadata?.statusType {
        case "success": return "checkmark.circle.fill"
        case "warning": return "exclamationmark.triangle"
        case "progress": return "clock"
        default: return "info.circle"
        }
    }
    
    private var statusColor: Color {
        switch message.metadata?.statusType {
        case "success": return .green
        case "warning": return .orange
        case "progress": return .blue
        default: return .secondary
        }
    }
    
    private var statusBackgroundColor: Color {
        statusColor.opacity(0.1)
    }
    
    // MARK: - Actions
    
    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
    }
}

// MARK: - Streaming Cursor

struct StreamingCursor: View {
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Text("▌")
            .font(.body)
            .opacity(opacity)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    opacity = 0.2
                }
            }
    }
}