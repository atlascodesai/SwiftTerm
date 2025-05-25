//
//  TerminalModel.swift
//  mobiledev
//
//  Terminal model that works on both iOS and macOS
//

import SwiftUI
import SwiftTerm

@Observable
class TerminalModel: TerminalDelegate {
    var terminalOutput: String = ""
    private var terminal: Terminal!
    #if os(macOS)
    private var localProcess: LocalProcess?
    #endif
    
    init() {
        print("🟢 TerminalModel: Initializing")
        var options = TerminalOptions(cols: 80, rows: 24)
        options.convertEol = true
        self.terminal = Terminal(delegate: self, options: options)
        print("🟢 TerminalModel: Terminal created with \(terminal.cols)x\(terminal.rows)")
        
        // Set terminal type for better compatibility
        setenv("TERM", "xterm-256color", 1)
        
        startShell()
    }
    
    private func startShell() {
        print("🟢 TerminalModel: Starting shell")
        #if os(macOS)
        print("🟢 TerminalModel: Running on macOS, creating LocalProcess")
        // Use HeadlessTerminal approach for macOS
        localProcess = LocalProcess(delegate: self)
        print("🟢 TerminalModel: LocalProcess created, starting process with zsh")
        
        // Start zsh instead of default shell
        let zshPath = "/bin/zsh"
        localProcess?.startProcess(executable: zshPath)
        print("🟢 TerminalModel: startProcess called with zsh")
        
        // Add initial prompt to see something
        terminal.feed(text: "Starting zsh shell...\r\n")
        #else
        print("🟢 TerminalModel: Running on iOS, using demo terminal")
        // iOS doesn't support LocalProcess, show demo terminal
        terminal.feed(text: "Welcome to MobileDev Terminal (iOS)\r\n")
        terminal.feed(text: "Note: Shell execution is limited on iOS.\r\n")
        terminal.feed(text: "Type 'help' for available commands.\r\n$ ")
        #endif
        
        updateDisplay()
        print("🟢 TerminalModel: Initial display updated")
    }
    
    func sendCommand(_ command: String) {
        print("🟡 TerminalModel: sendCommand called with: '\(command)'")
        
        #if os(macOS)
        // Don't feed to terminal - let the shell echo it back
        // Send to actual process with proper line ending
        let data = Array((command + "\n").utf8)
        print("🟡 TerminalModel: Sending \(data.count) bytes to localProcess")
        localProcess?.send(data: data[0..<data.count])
        #else
        // Show the command in terminal for iOS
        terminal.feed(text: command + "\r\n")
        // Handle commands locally on iOS
        handleIOSCommand(command)
        #endif
    }
    
    #if !os(macOS)
    private func handleIOSCommand(_ command: String) {
        switch command.lowercased() {
        case "help":
            terminal.feed(text: "Available commands:\r\n")
            terminal.feed(text: "  help - Show this message\r\n")
            terminal.feed(text: "  clear - Clear the screen\r\n")
            terminal.feed(text: "  echo <text> - Echo text back\r\n")
            terminal.feed(text: "  date - Show current date\r\n")
        case "clear":
            terminal.clearScreen()
        case let cmd where cmd.starts(with: "echo "):
            let text = String(cmd.dropFirst(5))
            terminal.feed(text: text + "\r\n")
        case "date":
            terminal.feed(text: "\(Date())\r\n")
        default:
            if !command.isEmpty {
                terminal.feed(text: "Command not found: \(command)\r\n")
            }
        }
        terminal.feed(text: "$ ")
    }
    #endif
    
    // MARK: - TerminalDelegate
    
    func send(source: Terminal, data: ArraySlice<UInt8>) {
        let str = String(bytes: data, encoding: .utf8) ?? "<non-utf8>"
        print("🔵 TerminalDelegate.send called with: '\(str)' (\(data.count) bytes)")
        #if os(macOS)
        localProcess?.send(data: data)
        #endif
    }
    
    func sizeChanged(source: Terminal, newCols: Int, newRows: Int) {
        // Handle size changes if needed
    }
    
    func setTerminalTitle(source: Terminal, title: String) {
        // Handle title changes if needed
    }
    
    func requestWindowSizeChange(source: Terminal, cols: Int, rows: Int) {
        // Handle window size change requests
    }
    
    func updateDisplay(source: Terminal, notifyUpdateRange: Bool) {
        print("🟣 TerminalDelegate.updateDisplay called")
        updateDisplay()
    }
    
    func updateDisplay() {
        var content = ""
        var nonEmptyLines = 0
        
        // Get all lines from terminal buffer
        var lastNonEmptyRow = -1
        
        // First pass: find the last non-empty row
        for row in 0..<terminal.rows {
            if let line = terminal.getLine(row: row) {
                let text = line.translateToString(trimRight: true)
                if !text.isEmpty {
                    lastNonEmptyRow = row
                }
            }
        }
        
        // Second pass: build content up to last non-empty row
        for row in 0...max(0, lastNonEmptyRow) {
            if let line = terminal.getLine(row: row) {
                let text = line.translateToString(trimRight: true)
                if !text.isEmpty {
                    nonEmptyLines += 1
                }
                content += text
                if row < lastNonEmptyRow {
                    content += "\n"
                }
            }
        }
        
        print("🟣 updateDisplay: Found \(nonEmptyLines) non-empty lines")
        
        // Update the output - don't trim too aggressively
        let newOutput = content.trimmingCharacters(in: .newlines)
        if newOutput != terminalOutput {
            print("🟣 updateDisplay: Output changed, updating UI")
            terminalOutput = newOutput
        }
    }
}

#if os(macOS)
// MARK: - LocalProcessDelegate for macOS
extension TerminalModel: LocalProcessDelegate {
    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        print("🔴 LocalProcessDelegate.processTerminated: exitCode=\(exitCode ?? -1)")
        DispatchQueue.main.async { [weak self] in
            self?.terminal.feed(text: "\r\nProcess terminated with exit code: \(exitCode ?? -1)\r\n")
        }
    }
    
    func dataReceived(slice: ArraySlice<UInt8>) {
        let str = String(bytes: slice, encoding: .utf8) ?? "<non-utf8>"
        
        // Log raw bytes for debugging ANSI codes
        if str.contains("\u{001B}") {
            print("🟠 LocalProcessDelegate.dataReceived: Contains ANSI escape codes")
            print("🟠 Raw string: \(str.debugDescription)")
        } else {
            print("🟢 LocalProcessDelegate.dataReceived: '\(str)' (\(slice.count) bytes)")
        }
        
        terminal.feed(buffer: slice)
        
        // Force a display update after feeding data
        DispatchQueue.main.async { [weak self] in
            self?.updateDisplay()
        }
    }
    
    func getWindowSize() -> winsize {
        var size = winsize()
        size.ws_col = UInt16(terminal.cols)
        size.ws_row = UInt16(terminal.rows)
        print("🔵 LocalProcessDelegate.getWindowSize: \(size.ws_col)x\(size.ws_row)")
        return size
    }
}
#endif