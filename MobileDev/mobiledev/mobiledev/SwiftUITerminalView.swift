//
//  SwiftUITerminalView.swift
//  mobiledev
//
//  SwiftUI wrapper for LocalProcessTerminalView with output capture
//

import SwiftUI
import SwiftTerm
#if os(macOS)
import AppKit

struct SwiftUITerminalView: NSViewRepresentable {
    @Binding var terminalOutput: String
    @Binding var currentDirectory: String
    let projectPath: String
    let onReady: ((LocalProcessTerminalView) -> Void)?
    
    init(terminalOutput: Binding<String> = .constant(""),
         currentDirectory: Binding<String> = .constant(""),
         projectPath: String = "/Users/timapple/Documents/Github",
         onReady: ((LocalProcessTerminalView) -> Void)? = nil) {
        self._terminalOutput = terminalOutput
        self._currentDirectory = currentDirectory
        self.projectPath = projectPath
        self.onReady = onReady
    }
    
    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var parent: SwiftUITerminalView
        var processStarted = false
        weak var terminalView: LocalProcessTerminalView?
        private var outputTimer: Timer?
        
        init(_ parent: SwiftUITerminalView) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            outputTimer?.invalidate()
        }
        
        // MARK: - LocalProcessTerminalViewDelegate
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // Handle size changes if needed
        }
        
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            // Handle title changes if needed
        }
        
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
            if let dir = directory {
                DispatchQueue.main.async {
                    self.parent.currentDirectory = dir
                }
            }
        }
        
        func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
            print("Process terminated with exit code: \(exitCode ?? -1)")
            outputTimer?.invalidate()
        }
        
        // Start capturing output periodically
        func startOutputCapture() {
            outputTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                self.captureOutput()
            }
        }
        
        private func captureOutput() {
            guard let terminal = terminalView?.terminal else { return }
            
            let data = terminal.getBufferAsData()
            if let content = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.parent.terminalOutput = content
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)
        terminal.processDelegate = context.coordinator
        
        // Store reference
        context.coordinator.terminalView = terminal
        
        return terminal
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        if !context.coordinator.processStarted {
            // Start process with specified working directory
            FileManager.default.changeCurrentDirectoryPath(projectPath)
            nsView.startProcess(executable: "/bin/zsh", execName: "-zsh")
            
            context.coordinator.processStarted = true
            context.coordinator.startOutputCapture()
            
            // Notify when ready and give focus
            DispatchQueue.main.async {
                self.onReady?(nsView)
                // Give terminal focus so keyboard input works
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}


#else
// iOS version placeholder
struct SwiftUITerminalView: UIViewRepresentable {
    @Binding var terminalOutput: String
    @Binding var currentDirectory: String
    let projectPath: String
    let onReady: ((UIView) -> Void)?
    
    init(terminalOutput: Binding<String> = .constant(""),
         currentDirectory: Binding<String> = .constant(""),
         projectPath: String = "/Users/timapple/Documents/Github",
         onReady: ((UIView) -> Void)? = nil) {
        self._terminalOutput = terminalOutput
        self._currentDirectory = currentDirectory
        self.projectPath = projectPath
        self.onReady = onReady
    }
    
    func makeUIView(context: Context) -> UIView {
        return UIView() // Placeholder for iOS
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update if needed
    }
}
#endif