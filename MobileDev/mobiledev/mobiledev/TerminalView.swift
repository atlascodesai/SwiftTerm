//
//  TerminalView.swift
//  mobiledev
//
//  SwiftUI Terminal View
//

import SwiftUI

struct TerminalView: View {
    @State private var model = TerminalModel()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal output area
            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.terminalOutput)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(white: 0.9))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(10)
                        .textSelection(.enabled)
                        .id("bottom")
                        .onChange(of: model.terminalOutput) { _, _ in
                            // Debounce the scroll to avoid multiple updates per frame
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                        }
                }
                .background(Color(white: 0.05))
            }
            
            Divider()
            
            // Input area
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                
                TextField("Enter command", text: $inputText)
                    .font(.system(size: 13, design: .monospaced))
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !inputText.isEmpty {
                            model.sendCommand(inputText)
                            inputText = ""
                        }
                    }
                
                Button(action: {
                    if !inputText.isEmpty {
                        model.sendCommand(inputText)
                        inputText = ""
                        isInputFocused = true
                    }
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.1))
        }
        .onAppear {
            isInputFocused = true
        }
    }
}