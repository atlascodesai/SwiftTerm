//
//  MonitoringLocalProcessTerminalView.swift
//  mobiledev
//
//  Custom terminal view that monitors output for workflow detection
//

import SwiftTerm
import AppKit

class MonitoringLocalProcessTerminalView: LocalProcessTerminalView {
    var workflowDetector: WorkflowDetector?
    var outputMonitor: TerminalOutputMonitor?
    
    override func dataReceived(slice: ArraySlice<UInt8>) {
        // Convert to string and monitor for patterns
        if let text = String(bytes: slice, encoding: .utf8) {
            workflowDetector?.processOutput(text)
            outputMonitor?.processOutput(text, bytes: slice)
        }
        
        // Call parent to continue normal processing
        super.dataReceived(slice: slice)
    }
    
    func setWorkflowDetector(_ detector: WorkflowDetector) {
        self.workflowDetector = detector
    }
    
    func setOutputMonitor(_ monitor: TerminalOutputMonitor) {
        self.outputMonitor = monitor
    }
}