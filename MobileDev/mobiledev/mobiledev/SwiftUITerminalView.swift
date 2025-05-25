//
//  SwiftUITerminalView.swift
//  mobiledev
//
//  SwiftUI wrapper for LocalProcessTerminalView
//

import SwiftUI
import SwiftTerm
#if os(macOS)
import AppKit

struct SwiftUITerminalView: NSViewRepresentable {
    
    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var parent: SwiftUITerminalView
        
        init(_ parent: SwiftUITerminalView) {
            self.parent = parent
            super.init()
        }
        
        // MARK: - LocalProcessTerminalViewDelegate
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // Handle size changes if needed
        }
        
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            // Handle title changes if needed
        }
        
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
            // Handle directory updates if needed
        }
        
        func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
            print("Process terminated with exit code: \(exitCode ?? -1)")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)
        terminal.processDelegate = context.coordinator
        
        // Set working directory
        FileManager.default.changeCurrentDirectoryPath("/Users/timapple/Documents/Github")
        
        // Start zsh
        terminal.startProcess(executable: "/bin/zsh", execName: "-zsh")
        
        // Give it focus
        DispatchQueue.main.async {
            terminal.window?.makeFirstResponder(terminal)
        }
        
        return terminal
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Update if needed
    }
}
#else
// iOS version would go here
struct SwiftUITerminalView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        return UIView() // Placeholder for iOS
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update if needed
    }
}
#endif