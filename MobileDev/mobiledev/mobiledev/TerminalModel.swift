//
//  TerminalModel.swift
//  mobiledev
//
//  Terminal model that works on both iOS and macOS
//

import SwiftUI
import SwiftTerm
import Foundation

@Observable
class TerminalModel: TerminalDelegate {
    var terminalOutput: String = ""
    private var terminal: Terminal!
    #if os(macOS)
    private var localProcess: LocalProcess?
    #endif
    
    init() {
        var options = TerminalOptions(cols: 120, rows: 40)
        options.convertEol = true
        self.terminal = Terminal(delegate: self, options: options)
        
        // Set terminal type for better compatibility
        setenv("TERM", "xterm-256color", 1)
        
        startShell()
    }
    
    private func startShell() {
        #if os(macOS)
        localProcess = LocalProcess(delegate: self)
        
        // Start zsh normally
        let zshPath = "/bin/zsh"
        localProcess?.startProcess(executable: zshPath)
        
        // After a short delay, change to the desired directory
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            let cdCommand = "cd /Users/timapple/Documents/Github\n"
            let data = Array(cdCommand.utf8)
            self?.localProcess?.send(data: data[0..<data.count])
        }
        #else
        // iOS doesn't support LocalProcess, show demo terminal
        terminal.feed(text: "Welcome to MobileDev Terminal (iOS)\r\n")
        terminal.feed(text: "Note: Shell execution is limited on iOS.\r\n")
        terminal.feed(text: "Type 'help' for available commands.\r\n$ ")
        #endif
        
        updateDisplay()
    }
    
    func sendCommand(_ command: String) {
        print("➡️ INPUT: '\(command)'")
        
        #if os(macOS)
        // For Claude, we need to type the text and then send Enter
        // First send the text
        let textData = Array(command.utf8)
        localProcess?.send(data: textData[0..<textData.count])
        
        // Then send Enter key (carriage return)
        let enterKey: [UInt8] = [13] // \r (carriage return)
        localProcess?.send(data: enterKey[0..<enterKey.count])
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
        
        // Update the output - don't trim too aggressively
        let newOutput = content.trimmingCharacters(in: .newlines)
        if newOutput != terminalOutput {
            terminalOutput = newOutput
        }
    }
    
    func debugPrintTerminalContent() {
        print("--- Terminal Buffer Content ---")
        for row in 0..<terminal.rows {
            if let line = terminal.getLine(row: row) {
                let text = line.translateToString(trimRight: true)
                if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    print("Row \(row): '\(text)'")
                }
            }
        }
        print("--- End Terminal Buffer ---")
    }
}

#if os(macOS)
// MARK: - LocalProcessDelegate for macOS
extension TerminalModel: LocalProcessDelegate {
    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        print("❌ PROCESS TERMINATED: exitCode=\(exitCode ?? -1)")
        DispatchQueue.main.async { [weak self] in
            self?.terminal.feed(text: "\r\nProcess terminated with exit code: \(exitCode ?? -1)\r\n")
        }
    }
    
    func dataReceived(slice: ArraySlice<UInt8>) {
        // Just feed to terminal - it handles all the ANSI codes internally
        terminal.feed(buffer: slice)
        
        // Update display to show the changes
        DispatchQueue.main.async { [weak self] in
            self?.updateDisplay()
        }
    }
    
    func getWindowSize() -> winsize {
        var size = winsize()
        size.ws_col = UInt16(terminal.cols)
        size.ws_row = UInt16(terminal.rows)
        return size
    }
}
#endif