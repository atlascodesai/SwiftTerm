import SwiftUI
import SwiftTerm

@Observable
public class HeadlessTerminalModel: TerminalDelegate {
    public var terminalOutput: String = ""
    private let terminal: Terminal
    private let queue = DispatchQueue(label: "terminal.update")
    
    public init() {
        let options = TerminalOptions(cols: 80, rows: 24)
        self.terminal = Terminal(delegate: nil, options: options)
        self.terminal.delegate = self
    }
    
    public func executeCommand(_ command: String) {
        terminal.feed(text: command + "\n")
    }
    
    public func send(source: Terminal, data: ArraySlice<UInt8>) {
        // This is where we'd typically send data to a process
        // For now, we'll just echo back for testing
        let string = String(bytes: data, encoding: .utf8) ?? ""
        terminal.feed(text: "echo: " + string)
    }
    
    public func sizeChanged(source: Terminal, newCols: Int, newRows: Int) {
        // Handle terminal resize if needed
    }
    
    public func setTerminalTitle(source: Terminal, title: String) {
        // Handle title changes if needed
    }
    
    public func requestWindowSizeChange(source: Terminal, cols: Int, rows: Int) {
        // Handle window size change requests
    }
    
    // Called when terminal content changes
    public func updateTerminal(source: Terminal) {
        queue.async { [weak self] in
            self?.updateOutput()
        }
    }
    
    private func updateOutput() {
        var content = ""
        let buffer = terminal.getBuffer()
        
        for row in 0..<terminal.rows {
            if let line = buffer.getLine(row) {
                content += line.translateToString(trimRight: true)
                if row < terminal.rows - 1 {
                    content += "\n"
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.terminalOutput = content
        }
    }
}