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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Terminal View
                SwiftUITerminalView(
                    terminalOutput: $viewModel.terminalOutput,
                    currentDirectory: $viewModel.currentDirectory,
                    projectPath: "/Users/timapple/Documents/Github",
                    onReady: { terminal in
                        viewModel.setTerminal(terminal)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                
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
                        Label("Claude Active", systemImage: "brain")
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
            .navigationTitle("MobileDev Terminal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    ContentView()
}
