//
//  ContentView.swift
//  mobiledev
//
//  Created by 🍋💻 on 25/05/2025.
//

import SwiftUI

struct ContentView: View {
    let chatID: UUID?
    @StateObject private var viewModel = TerminalViewModel()
    @State private var inputCommand = ""
    @State private var showAnalysisPanel = false
    @State private var expandedCommands: Set<UUID> = []
    @State private var copiedItemId: UUID?
    @State private var copiedRawFeed = false
    
    init(chatID: UUID? = nil) {
        self.chatID = chatID
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // Main Terminal Area
                VStack(spacing: 0) {
                    // Terminal View
                    SwiftUITerminalView(
                        terminalOutput: $viewModel.terminalOutput,
                        currentDirectory: $viewModel.currentDirectory,
                        projectPath: "/Users/timapple/Documents/Github",
                        onReady: { terminal in
                            viewModel.setTerminal(terminal)
                        },
                        viewModel: viewModel
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .onAppear {
                        if let chatID = chatID {
                            // Create bridge for chat-terminal communication
                            let bridge = TerminalBridge.shared.createBridge(for: chatID, terminalViewModel: viewModel)
                            
                            // Set up output handler for chat updates
                            bridge.addOutputHandler { output in
                                // This will be handled by the ChatViewModel
                            }
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        // Analysis Panel Toggle
                        Button(action: { withAnimation { showAnalysisPanel.toggle() } }) {
                            Image(systemName: showAnalysisPanel ? "sidebar.trailing.fill" : "sidebar.trailing")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(6)
                        }
                        .padding()
                    }

                    Divider()

                    // Command Input
                    HStack {
                        TextField("Enter command...", text: $inputCommand)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if !inputCommand.isEmpty {
                                    viewModel.sendCommand(inputCommand)
                                    inputCommand = ""
                                }
                            }
                            .submitLabel(.send)

                        // Arrow buttons for navigation
                        if viewModel.isClaudeRunning {
                            Button(action: {
                                viewModel.sendArrowUp()
                            }) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.borderless)
                            .help("Move up")

                            Button(action: {
                                viewModel.sendArrowDown()
                            }) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.borderless)
                            .help("Move down")
                        }

                        Button("Send") {
                            if !inputCommand.isEmpty {
                                viewModel.sendCommand(inputCommand)
                                inputCommand = ""
                            } else if viewModel.isClaudeRunning {
                                // If no command, just send Enter
                                viewModel.sendEnter()
                            }
                        }

                        if viewModel.isClaudeRunning {
                            Button("Exit Claude") {
                                viewModel.exitClaude()
                            }
                            .foregroundColor(.red)
                        } else {
                            Button("Launch Claude") {
                                viewModel.launchClaude()
                            }
                            .foregroundColor(.green)
                        }
                    }
                    .padding()

                    // Option buttons when options are detected
                    if viewModel.showOptionButtons && !viewModel.detectedOptions.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(Array(viewModel.detectedOptions.enumerated()), id: \.offset) { index, option in
                                Button(action: {
                                    viewModel.selectOption(index + 1)
                                    viewModel.showOptionButtons = false
                                }) {
                                    VStack(alignment: .leading) {
                                        Text("Option \(index + 1)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Text(option)
                                            .font(.caption2)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Status Bar
                    HStack {
                        Label(viewModel.currentDirectory.isEmpty ? "~" : viewModel.currentDirectory,
                              systemImage: "folder")

                        Spacer()

                        if viewModel.isClaudeRunning {
                            Label("Claude: \(viewModel.claudeState)", systemImage: "brain")
                                .foregroundColor(.green)
                        } else {
                            Label("Shell", systemImage: "terminal")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .font(.caption)
                }

                // Analysis Panel
                if showAnalysisPanel {
                    Divider()

                    AnalysisPanel(
                        analysis: viewModel.lastAnalysis,
                        claudeState: viewModel.claudeState,
                        rawFeed: viewModel.rawTerminalFeed,
                        userCommands: viewModel.userCommands,
                        commandResponses: viewModel.commandResponses,
                        expandedCommands: $expandedCommands,
                        copiedItemId: $copiedItemId,
                        copiedRawFeed: $copiedRawFeed
                    )
                        .frame(width: 300)
                        .background(Color(NSColor.controlBackgroundColor))
                        .transition(.move(edge: .trailing))
                }
            }
            .navigationTitle("MobileDev Terminal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

// MARK: - Analysis Panel

struct AnalysisPanel: View {
    let analysis: ClaudeOutputAnalyzer.Analysis?
    let claudeState: String
    let rawFeed: String
    let userCommands: [String]
    let commandResponses: [TerminalViewModel.CommandEntry]
    @Binding var expandedCommands: Set<UUID>
    @Binding var copiedItemId: UUID?
    @Binding var copiedRawFeed: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Claude Analysis")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)

                // Current State
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(claudeState, systemImage: "brain")
                            .foregroundColor(claudeState.contains("Generating") ? .orange : .blue)
                    }

                    if let analysis = analysis {
                        Text("Type: \(String(describing: analysis.type))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                if let analysis = analysis {
                    Divider()

                    // File Operations
                    if !analysis.filesRead.isEmpty || !analysis.filesCreated.isEmpty || !analysis.filesModified.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("File Operations")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            if !analysis.filesRead.isEmpty {
                                Label("Read", systemImage: "doc.text")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(analysis.filesRead, id: \.self) { file in
                                    Text("• \(file)")
                                        .font(.caption)
                                        .padding(.leading)
                                }
                            }

                            if !analysis.filesCreated.isEmpty {
                                Label("Created", systemImage: "doc.badge.plus")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                ForEach(analysis.filesCreated, id: \.self) { file in
                                    Text("• \(file)")
                                        .font(.caption)
                                        .padding(.leading)
                                }
                            }

                            if !analysis.filesModified.isEmpty {
                                Label("Modified", systemImage: "doc.badge.gearshape")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                ForEach(analysis.filesModified, id: \.self) { file in
                                    Text("• \(file)")
                                        .font(.caption)
                                        .padding(.leading)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Command/Response History
                    if !commandResponses.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Command History")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            ForEach(commandResponses) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    // Command header with expand/collapse
                                    HStack {
                                        Button(action: {
                                            if expandedCommands.contains(entry.id) {
                                                expandedCommands.remove(entry.id)
                                            } else {
                                                expandedCommands.insert(entry.id)
                                            }
                                        }) {
                                            Image(systemName: expandedCommands.contains(entry.id) ? "chevron.down" : "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)

                                        if entry.selectedOption != nil {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.square.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                                Text(entry.command)
                                                    .font(.system(.caption, design: .monospaced))
                                                    .foregroundColor(.green)
                                                    .lineLimit(1)
                                            }
                                        } else {
                                            Text(entry.command)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(.blue)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        if entry.claudeGenerating {
                                            HStack(spacing: 4) {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                                Text("Generating...")
                                                    .font(.caption)
                                                    .foregroundColor(.orange)
                                            }
                                        } else if entry.isComplete {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }

                                    // Expanded response
                                    if expandedCommands.contains(entry.id) {
                                        // For option selections, show what was selected
                                        if let selectedOption = entry.selectedOption {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Option selected:")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(selectedOption)
                                                    .font(.system(.caption, design: .monospaced))
                                                    .foregroundColor(.green)
                                                    .padding(8)
                                                    .background(Color.green.opacity(0.1))
                                                    .cornerRadius(4)
                                            }
                                            .padding(.top, 4)
                                        } else if !entry.rawResponse.isEmpty {
                                            let cleanedResponse = entry.rawResponse
                                                .replacingOccurrences(of: "\r", with: "\n")
                                                .trimmingCharacters(in: .whitespacesAndNewlines)

                                            if !cleanedResponse.isEmpty {
                                                VStack(alignment: .leading, spacing: 4) {
                                                ScrollView {
                                                    Text(cleanedResponse)
                                                        .font(.system(.caption, design: .monospaced))
                                                        .foregroundColor(.secondary)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .padding(8)
                                                        .background(Color.black.opacity(0.1))
                                                        .cornerRadius(4)
                                                }
                                                .frame(maxHeight: 200)

                                                // Copy button
                                                Button(action: {
                                                    NSPasteboard.general.clearContents()
                                                    NSPasteboard.general.setString(cleanedResponse, forType: .string)
                                                    copiedItemId = entry.id

                                                    // Reset after 2 seconds
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                        if copiedItemId == entry.id {
                                                            copiedItemId = nil
                                                        }
                                                    }
                                                }) {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: copiedItemId == entry.id ? "checkmark" : "doc.on.doc")
                                                            .font(.caption)
                                                        Text(copiedItemId == entry.id ? "Copied!" : "Copy Response")
                                                            .font(.caption)
                                                    }
                                                    .foregroundColor(copiedItemId == entry.id ? .green : .accentColor)
                                                }
                                                .buttonStyle(.plain)
                                                }
                                                .padding(.leading, 16)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Build/Test Status
                    if analysis.type == .buildOutput {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Build Status")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            HStack {
                                Image(systemName: analysis.buildSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(analysis.buildSuccessful ? .green : .red)
                                Text(analysis.buildSuccessful ? "Build Succeeded" : "Build Failed")
                                    .font(.caption)
                            }

                            if analysis.testsRun {
                                HStack {
                                    Image(systemName: "testtube.2")
                                        .foregroundColor(.blue)
                                    Text("Tests Executed")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Errors
                    if let error = analysis.error {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)

                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }

                    // Completion Status
                    if analysis.isComplete {
                        Divider()
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("Operation Complete")
                                .font(.caption)
                        }
                        .padding(.horizontal)
                    }
                }

                // Raw Terminal Feed
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Raw Terminal Feed")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        // Copy raw feed button
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(rawFeed, forType: .string)
                            copiedRawFeed = true

                            // Reset after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedRawFeed = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: copiedRawFeed ? "checkmark" : "doc.on.doc")
                                    .font(.caption)
                                Text(copiedRawFeed ? "Copied!" : "Copy All")
                                    .font(.caption)
                            }
                            .foregroundColor(copiedRawFeed ? .green : .accentColor)
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView {
                        Text(rawFeed.isEmpty ? "No output captured yet..." : rawFeed)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .frame(maxHeight: 200)
                }
                .padding(.horizontal)

                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
}
