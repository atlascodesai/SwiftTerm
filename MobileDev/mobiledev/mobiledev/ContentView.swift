//
//  ContentView.swift
//  mobiledev
//
//  Created by 🍋💻 on 25/05/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TerminalViewModel()
    @State private var inputCommand = ""
    @State private var showAnalysisPanel = false
    
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
                        
                        Button("Send") {
                            if !inputCommand.isEmpty {
                                viewModel.sendCommand(inputCommand)
                                inputCommand = ""
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
                    
                    AnalysisPanel(analysis: viewModel.lastAnalysis, claudeState: viewModel.claudeState, rawFeed: viewModel.rawTerminalFeed, userCommands: viewModel.userCommands, commandResponses: viewModel.commandResponses)
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
                                    // Command
                                    HStack {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        Text(entry.command)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    // Response (truncated)
                                    if !entry.rawResponse.isEmpty {
                                        Text(String(entry.rawResponse.prefix(200)))
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                            .padding(.leading, 16)
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
                    Text("Raw Terminal Feed")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
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
