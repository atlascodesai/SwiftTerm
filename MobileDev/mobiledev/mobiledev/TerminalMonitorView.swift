//
//  TerminalMonitorView.swift
//  mobiledev
//
//  UI for monitoring terminal output and Claude's state
//

import SwiftUI

struct TerminalMonitorView: View {
    @ObservedObject var monitor: TerminalOutputMonitor
    @State private var autoScroll = true
    @State private var showRawBytes = false
    @State private var showCleanText = true
    @State private var filterType: TerminalOutputMonitor.OutputType? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status Bar
                StatusBar(monitor: monitor)
                
                Divider()
                
                // Output List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredEntries) { entry in
                                OutputRow(entry: entry, showRawBytes: showRawBytes, showCleanText: showCleanText)
                                    .id(entry.id)
                            }
                        }
                        .padding(8)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .onChange(of: monitor.outputEntries.count) { oldValue, newValue in
                        if autoScroll, let lastEntry = monitor.outputEntries.last {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(lastEntry.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Control Bar
                ControlBar(
                    monitor: monitor,
                    autoScroll: $autoScroll,
                    showRawBytes: $showRawBytes,
                    showCleanText: $showCleanText,
                    filterType: $filterType
                )
            }
            .navigationTitle("Terminal Output Monitor")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Export Log") {
                            exportLog()
                        }
                        Button("Clear All") {
                            monitor.clearEntries()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    var filteredEntries: [TerminalOutputMonitor.OutputEntry] {
        if let filter = filterType {
            return monitor.outputEntries.filter { $0.type == filter }
        }
        return monitor.outputEntries
    }
    
    func exportLog() {
        let log = monitor.exportLog()
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "terminal_output_\(Date().formatted(date: .numeric, time: .standard)).txt"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? log.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct StatusBar: View {
    @ObservedObject var monitor: TerminalOutputMonitor
    
    var body: some View {
        HStack(spacing: 20) {
            // Claude Status
            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.isClaudeGenerating ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.green, lineWidth: monitor.isClaudeGenerating ? 2 : 0)
                            .scaleEffect(monitor.isClaudeGenerating ? 1.5 : 1)
                            .opacity(monitor.isClaudeGenerating ? 0 : 1)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: monitor.isClaudeGenerating)
                    )
                
                Text(monitor.isClaudeGenerating ? "Claude is generating..." : "Claude idle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 20)
            
            // Input Status
            HStack(spacing: 8) {
                Image(systemName: monitor.isWaitingForInput ? "keyboard.fill" : "keyboard")
                    .foregroundColor(monitor.isWaitingForInput ? .orange : .gray)
                    .font(.caption)
                
                Text(monitor.isWaitingForInput ? "Waiting for input" : "No input needed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if monitor.isWaitingForInput && !monitor.currentPrompt.isEmpty {
                Divider()
                    .frame(height: 20)
                
                Text(monitor.currentPrompt)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Last Activity
            Text("Last activity: \(monitor.lastActivityTime, style: .relative)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct OutputRow: View {
    let entry: TerminalOutputMonitor.OutputEntry
    let showRawBytes: Bool
    let showCleanText: Bool
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                // Type indicator
                Circle()
                    .fill(entry.type.color)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
                
                // Timestamp
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    if showCleanText && !entry.cleanText.isEmpty {
                        Text(entry.cleanText)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(isExpanded ? nil : 3)
                    } else {
                        Text(entry.content)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(isExpanded ? nil : 3)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Expand button if content is long
                if entry.content.count > 100 || entry.cleanText.count > 100 {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if isExpanded {
                if showRawBytes {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Raw Hex: \(entry.rawBytes)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                        Text("Formatted: \(entry.formattedBytes)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.leading, 16)
                }
                
                if !showCleanText {
                    Text("Raw ANSI: \(entry.content)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .padding(.leading, 16)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct ControlBar: View {
    @ObservedObject var monitor: TerminalOutputMonitor
    @Binding var autoScroll: Bool
    @Binding var showRawBytes: Bool
    @Binding var showCleanText: Bool
    @Binding var filterType: TerminalOutputMonitor.OutputType?
    
    struct FilterButton: Identifiable {
        let id: String
        let type: TerminalOutputMonitor.OutputType?
        let label: String
        let icon: String
    }
    
    let filterButtons = [
        FilterButton(id: "all", type: nil, label: "All", icon: "line.3.horizontal.decrease.circle"),
        FilterButton(id: "claude", type: .claudeOutput, label: "Claude", icon: "brain"),
        FilterButton(id: "prompts", type: .systemPrompt, label: "Prompts", icon: "terminal"),
        FilterButton(id: "commands", type: .command, label: "Commands", icon: "bolt")
    ]
    
    var body: some View {
        HStack {
            // Auto-scroll toggle
            Toggle(isOn: $autoScroll) {
                Label("Auto-scroll", systemImage: "arrow.down.to.line")
            }
            .toggleStyle(.button)
            
            Divider()
                .frame(height: 20)
            
            // Show raw bytes toggle
            Toggle(isOn: $showRawBytes) {
                Label("Raw Bytes", systemImage: "01.square")
            }
            .toggleStyle(.button)
            
            Divider()
                .frame(height: 20)
            
            // Show clean text toggle
            Toggle(isOn: $showCleanText) {
                Label("Clean Text", systemImage: "text.justify")
            }
            .toggleStyle(.button)
            
            Divider()
                .frame(height: 20)
            
            // Filter buttons
            Text("Filter:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(filterButtons) { button in
                Button(action: {
                    if let outputType = button.type {
                        filterType = filterType == outputType ? nil : outputType
                    } else {
                        filterType = nil
                    }
                }) {
                    Label(button.label, systemImage: button.icon)
                }
                .buttonStyle(.accessoryBar)
                .foregroundColor(filterType == button.type ? .accentColor : .primary)
            }
            
            Spacer()
            
            // Entry count
            Text("\(monitor.outputEntries.count) entries")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}