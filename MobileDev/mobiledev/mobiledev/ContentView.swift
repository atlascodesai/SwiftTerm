//
//  ContentView.swift
//  mobiledev
//
//  Created by 🍋💻 on 25/05/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var workflowDetector = WorkflowDetector()
    @StateObject private var outputMonitor = TerminalOutputMonitor()
    @State private var showCommands = false
    @State private var showMonitor = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                SwiftUITerminalView(workflowDetector: workflowDetector, outputMonitor: outputMonitor)
                
                // Overlay for detected commands notification
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        if !workflowDetector.detectedCommands.isEmpty {
                            Button(action: { showCommands.toggle() }) {
                                HStack {
                                    Image(systemName: "terminal.fill")
                                    Text("\(workflowDetector.detectedCommands.count) commands detected")
                                    Image(systemName: showCommands ? "chevron.down" : "chevron.up")
                                }
                                .padding(8)
                                .background(.regularMaterial)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("MobileDev Terminal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showMonitor.toggle() }) {
                        Label("Monitor", systemImage: "waveform.path.ecg")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if !workflowDetector.detectedCommands.isEmpty {
                        Button(action: { showCommands.toggle() }) {
                            Label("Commands", systemImage: "list.bullet.rectangle")
                                .badge(workflowDetector.detectedCommands.count)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCommands) {
                DetectedCommandsView(workflowDetector: workflowDetector)
            }
            .sheet(isPresented: $showMonitor) {
                TerminalMonitorView(monitor: outputMonitor)
            }
        }
    }
}

struct DetectedCommandsView: View {
    @ObservedObject var workflowDetector: WorkflowDetector
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if workflowDetector.detectedCommands.isEmpty {
                    ContentUnavailableView(
                        "No Commands Detected",
                        systemImage: "terminal",
                        description: Text("Commands suggested by Claude will appear here")
                    )
                } else {
                    ForEach(workflowDetector.detectedCommands) { command in
                        CommandRow(command: command)
                    }
                    .onDelete { indexSet in
                        workflowDetector.detectedCommands.remove(atOffsets: indexSet)
                    }
                }
            }
            .navigationTitle("Detected Commands")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if !workflowDetector.detectedCommands.isEmpty {
                        Button("Clear All") {
                            workflowDetector.clearCommands()
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 400)
        #endif
    }
}

struct CommandRow: View {
    let command: WorkflowDetector.DetectedCommand
    @State private var showContext = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: command.type.iconName)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(command.command)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                    
                    HStack {
                        Text(command.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(command.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: copyCommand) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy command")
                
                Button(action: { showContext.toggle() }) {
                    Image(systemName: showContext ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
                .help("Show context")
            }
            
            if showContext {
                Text(command.context)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    func copyCommand() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command.command, forType: .string)
        #else
        UIPasteboard.general.string = command.command
        #endif
    }
}

#Preview {
    ContentView()
}
