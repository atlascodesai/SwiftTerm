import XCTest
@testable import mobiledev

class TerminalParsingTests: XCTestCase {
    
    var viewModel: TerminalViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = TerminalViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Welcome Message Tests
    
    func testClaudeWelcomeMessageExtraction() {
        // Given: Claude welcome output
        let welcomeOutput = """
╭───────────────────────────────────────────────────╮
│ ✻ Welcome to Claude Code!                         │
│                                                   │
│   /help for help, /status for your current setup  │
│                                                   │
│   cwd: /Users/timapple/Documents/Github           │
╰───────────────────────────────────────────────────╯


> 
"""
        
        // When: Process the claude command
        viewModel.sendCommand("claude")
        viewModel.processCommandCompletion(welcomeOutput)
        
        // Then: Check if welcome was extracted
        XCTAssertEqual(viewModel.commandResponses.count, 1)
        let response = viewModel.commandResponses[0]
        XCTAssertEqual(response.command, "claude")
        XCTAssertTrue(response.isComplete)
        XCTAssertFalse(response.rawResponse.isEmpty)
        
        print("🧪 Extracted response: '\(response.rawResponse)'")
        XCTAssertTrue(response.rawResponse.contains("Welcome to Claude Code!"))
    }
    
    func testResponseExtractionWithPrompt() {
        // Given: Command and response
        viewModel.rawTerminalFeed = "> hi\n"
        viewModel.commandResponses.append(TerminalViewModel.CommandEntry(
            timestamp: Date(),
            command: "hi",
            rawResponse: "",
            isClaudeCommand: true,
            isComplete: false
        ))
        
        let response = """
⏺ Hello! How can I help you today?

> 
"""
        
        // When: Process the response
        viewModel.processCommandCompletion(response)
        viewModel.extractPendingResponses()
        
        // Then: Check extraction
        XCTAssertEqual(viewModel.commandResponses.count, 1)
        let extracted = viewModel.commandResponses[0]
        XCTAssertTrue(extracted.isComplete)
        XCTAssertEqual(extracted.rawResponse.trimmingCharacters(in: .whitespacesAndNewlines), 
                      "⏺ Hello! How can I help you today?")
    }
    
    func testOptionDetection() {
        // Given: Options output
        let optionsOutput = """
⏺ I see there's already a poem in poem.md. Would you like me to:
  1. Replace it with a new poem
  2. Add another poem to the existing file
  3. Create a different poem file (like poem6.md)

  What would you prefer?

> 
"""
        
        // When: Process options
        viewModel.rawTerminalFeed += optionsOutput
        viewModel.detectOptionsInTerminal(optionsOutput)
        
        // Then: Check detection
        XCTAssertEqual(viewModel.detectedOptions.count, 3)
        XCTAssertTrue(viewModel.showOptionButtons)
        XCTAssertTrue(viewModel.optionsRequireTextInput) // No ❯ markers
        
        print("🧪 Detected options: \(viewModel.detectedOptions)")
    }
    
    func testUIBasedOptionDetection() {
        // Given: UI selection options
        let uiOptions = """
╭────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Do you want to make this edit to poem.md?                                                                  │
│ ❯ 1. Yes                                                                                                   │
│   2. Yes, and don't ask again this session                                                                 │
│   3. No, and tell Claude what to do differently                                                            │
│                                                                                                            │
╰────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
"""
        
        // When: Process UI options
        viewModel.detectOptionsInTerminal(uiOptions)
        
        // Then: Check detection
        XCTAssertEqual(viewModel.detectedOptions.count, 3)
        XCTAssertTrue(viewModel.showOptionButtons)
        XCTAssertFalse(viewModel.optionsRequireTextInput) // Has ❯ markers
    }
    
    // MARK: - Raw Feed Extraction Tests
    
    func testExtractResponseFromRawFeed() {
        // Given: Terminal feed with claude command
        viewModel.rawTerminalFeed = """
timapple@MBP Github % claude
╭───────────────────────────────────────────────────╮
│ ✻ Welcome to Claude Code!                         │
│                                                   │
│   /help for help, /status for your current setup  │
│                                                   │
│   cwd: /Users/timapple/Documents/Github           │
╰───────────────────────────────────────────────────╯


> hi
⏺ Hello! How can I help you today?

> 
"""
        
        // Add claude command to track
        viewModel.commandResponses.append(TerminalViewModel.CommandEntry(
            timestamp: Date(),
            command: "claude",
            rawResponse: "",
            isClaudeCommand: true,
            isComplete: false
        ))
        
        // When: Extract response
        viewModel.extractPendingResponses()
        
        // Then: Verify extraction
        let claudeCommand = viewModel.commandResponses[0]
        XCTAssertTrue(claudeCommand.isComplete)
        XCTAssertTrue(claudeCommand.rawResponse.contains("Welcome to Claude Code!"))
        
        print("🧪 Full extracted welcome:")
        print(claudeCommand.rawResponse)
    }
    
    // MARK: - State Detection Tests
    
    func testClaudeStateTransitions() {
        // Test: Not running -> Launching
        XCTAssertEqual(viewModel.claudeState, "Not running")
        
        viewModel.launchClaude()
        XCTAssertEqual(viewModel.claudeState, "Starting Claude...")
        XCTAssertTrue(viewModel.isClaudeRunning)
        
        // Test: Launching -> Ready (after welcome)
        let welcomeOutput = """
╭───────────────────────────────────────────────────╮
│ ✻ Welcome to Claude Code!                         │
│                                                   │
│   /help for help, /status for your current setup  │
│                                                   │
│   cwd: /Users/timapple/Documents/Github           │
╰───────────────────────────────────────────────────╯


> 
"""
        viewModel.processCommandCompletion(welcomeOutput)
        
        // Should transition to ready
        XCTAssertEqual(viewModel.claudeState, "Ready for input")
    }
    
    // MARK: - Debug Output Test
    
    func testDebugRawFeedCapture() {
        // This test helps us see exactly what's being captured
        let outputs = [
            "timapple@MBP Github % ",
            "claude\n",
            "\u{1B}[?25l", // cursor hide
            "\u{1B}[2J\u{1B}[H", // clear screen
            "╭───────────────────────────────────────────────────╮\n",
            "│ ✻ Welcome to Claude Code!                         │\n",
            "│                                                   │\n",
            "│   /help for help, /status for your current setup  │\n",
            "│                                                   │\n",
            "│   cwd: /Users/timapple/Documents/Github           │\n",
            "╰───────────────────────────────────────────────────╯\n",
            "\n\n> "
        ]
        
        // Simulate receiving outputs
        for output in outputs {
            viewModel.processCommandCompletion(output)
        }
        
        print("🧪 Raw Terminal Feed:")
        print("---START---")
        print(viewModel.rawTerminalFeed)
        print("---END---")
        
        print("\n🧪 Command Responses: \(viewModel.commandResponses.count)")
        for (idx, cmd) in viewModel.commandResponses.enumerated() {
            print("[\(idx)] Command: '\(cmd.command)'")
            print("    Complete: \(cmd.isComplete)")
            print("    Response: '\(cmd.rawResponse.prefix(50))...'")
        }
    }
}

// MARK: - Test Helpers

extension TerminalParsingTests {
    func simulateTerminalOutput(_ outputs: [String]) {
        for output in outputs {
            viewModel.processCommandCompletion(output)
        }
    }
    
    func assertCommandResponse(at index: Int, command: String, isComplete: Bool, containsText: String? = nil) {
        XCTAssertTrue(viewModel.commandResponses.count > index, "Not enough command responses")
        let response = viewModel.commandResponses[index]
        XCTAssertEqual(response.command, command)
        XCTAssertEqual(response.isComplete, isComplete)
        if let expectedText = containsText {
            XCTAssertTrue(response.rawResponse.contains(expectedText), 
                         "Response doesn't contain '\(expectedText)'")
        }
    }
}