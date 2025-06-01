# Terminal Parsing Logic

This document explains how the MobileDev terminal app intercepts, parses, and interacts with the terminal output, particularly for Claude Code integration.

## Overview

The app uses SwiftTerm's `LocalProcessTerminalView` to run a shell process and captures its output in real-time. We've built a sophisticated parsing system on top of this to:

1. Detect when Claude is running
2. Track Claude's state (generating, waiting for input, etc.)
3. Extract command responses
4. Detect and interact with Claude's option menus
5. Track user selections
6. Bridge terminal output to a chat interface

## Architecture

### Key Components

1. **SwiftUITerminalView** - NSViewRepresentable wrapper that integrates SwiftTerm with SwiftUI
2. **TerminalViewModel** - Central state management and business logic
3. **ClaudeOutputAnalyzer** - Parses terminal output to detect Claude's activities
4. **ContentView** - Terminal UI with special controls for Claude interaction
5. **ChatView** - Chat interface showing commands and responses
6. **TerminalBridge** - Connects terminal operations to chat display
7. **ChatManager** - Manages chat sessions and message history

## Terminal Output Capture

### Real-time Processing

```swift
// SwiftUITerminalView.swift
func dataReceived(slice: ArraySlice<UInt8>) {
    let data = Data(slice)
    if let string = String(data: data, encoding: .utf8) {
        parent.viewModel.processCommandCompletion(string)
    }
}
```

- Receives data in real-time as it arrives at the terminal
- Updates `rawTerminalFeed` with accumulated content
- Processes new output immediately for state changes
- Tracks command completion and response extraction

### Content Flow

1. **Raw Capture**: Terminal data → `processCommandCompletion()`
2. **State Analysis**: Check for Claude patterns (generating, ready, etc.)
3. **Response Extraction**: When command completes, extract response
4. **Chat Bridge**: Send extracted responses to chat interface

## Claude State Detection

### Generation Pattern Detection

The system now checks only NEW output (not entire history):

```swift
// Check for generation pattern in the NEW output only
if output.contains("esc to interrupt") {
    if !wasGenerating {
        claudeState = "Generating response..."
        wasGenerating = true
    }
}
```

### Prompt Detection

Multiple methods to detect when Claude is ready:

1. **Analyzer Detection**: `analysis.type == .ready`
2. **Clean Prompt**: Output is just `>` or `> ` with minimal text
3. **Terminal Content**: Bridge checks last 5 lines for prompt

### State Transitions

1. **Not Running** → **Starting Claude...** (when "claude" command sent)
2. **Starting Claude...** → **Ready for input** (when welcome box extracted)
3. **Ready for input** → **Generating response...** (when "esc to interrupt" appears in new output)
4. **Generating response...** → **Ready for input** (when prompt detected)
5. **Any state** → **Waiting for option selection** (when options detected)

## Response Extraction

### Command Tracking

Every command creates a `CommandEntry`:

```swift
struct CommandEntry {
    let command: String
    var rawResponse: String = ""
    let isClaudeCommand: Bool
    var isComplete: Bool = false
    var claudeGenerating: Bool = false
    var selectedOption: String? = nil
}
```

### Extraction Process (`extractResponseFromRawFeed`)

1. **Find Command**: 
   - For numeric commands: Also check without prompt ("> 1", "> 1\n", or just "1\n")
   - For regular commands: Look for "> command\n" or "> command"

2. **Special Handling for Claude Welcome**:
   ```swift
   if command == "claude" && afterCommand.contains("Welcome to Claude Code!") {
       // Extract from ╭ to ╰─── plus one newline
       // This captures just the welcome box
   }
   ```

3. **General Extraction**:
   - Skip empty lines at start
   - Continue until hitting input prompt box
   - Clean UI elements from response

### Terminal Bridge

The `TerminalBridge` connects terminal to chat:

1. **Command Tracking**: 
   - Monitors `lastCommandIndex` in commandResponses
   - Updates when new commands are sent

2. **Response Detection**:
   - Checks every 0.5 seconds if command is complete with response
   - Sends response to ChatManager when ready

3. **Special Cases**:
   - Claude launch: Waits 0.2s then finds claude command
   - Option selections: Updates index after selection

## Option Menu Detection

### Two Types of Options

1. **UI-Based Options** (with `❯` markers):
   ```
   │ ❯ 1. Yes                                          │
   │   2. Yes, and don't ask again this session        │
   │   3. No, and tell Claude what to do differently   │
   ```

2. **Text-Based Options** (plain numbered lists):
   ```
   1. Replace it with a new poem
   2. Add another poem to the existing file  
   3. Create a different poem file (like poem4.md)
   ```

### Detection Logic

```swift
func detectOptionsInTerminal(_ terminalContent: String) {
    // Check for UI markers (❯)
    let hasUIMarkers = lineStr.contains("❯ 1.")
    
    // Set flag for how to handle selection
    optionsRequireTextInput = !hasUIMarkers
}
```

### Option Selection

**UI-Based Options** (arrow navigation):
- Option 1: Press Enter
- Option 2: Down arrow → Enter
- Option 3: Down arrow × 2 → Enter

**Text-Based Options** (send number):
- Send the number as text ("1", "2", or "3")
- Uses `sendCommand()` to properly track response

## Chat Integration

### Message Flow

1. **User Command**: ChatView → TerminalBridge → TerminalViewModel
2. **Terminal Execution**: Command runs, output captured
3. **Response Extraction**: When complete, response extracted
4. **Chat Update**: TerminalBridge → ChatManager → ChatView

### State Synchronization

- Terminal state propagates to chat via bridge
- Options detected in terminal appear as buttons in chat
- Text input disabled when options are present

## Current Issues & Solutions

### Welcome Message Display

**Issue**: Welcome message is extracted but shows "Response: false" in logs

**Current Approach**:
- Special extraction for claude command
- Extracts from ╭ to ╰─── plus newline
- Should include welcome box but may miss "? for shortcuts"

### State Management

**Fixed Issue**: State was getting stuck on "Generating response..."
- Changed from checking entire `rawTerminalFeed` to just new `output`
- Prevents old "esc to interrupt" text from triggering generation state

### Option Button Display

**Working**: 
- Detects both UI and text-based options
- Shows appropriate buttons in chat
- Handles selection correctly
- Fixed issue where "Starting Claude..." was treated as thinking

## Best Practices

1. **Check new output only** - Don't scan entire terminal history for state changes
2. **Track command indices** - Essential for bridge to know which response goes where
3. **Handle timing carefully** - Use delays when needed for command tracking
4. **Clean extracted content** - Remove UI elements for chat display
5. **Multiple detection methods** - Redundancy prevents missed states
6. **Log key events** - Essential for troubleshooting

## Debugging Tips

1. **Console Logs**: Watch for:
   - `📝 TerminalBridge: Tracking command`
   - `🔍 TerminalBridge state:`
   - `✅ Extracted response`
   - `🎯 Detected options`

2. **Common Issues**:
   - Response shows "false" = extraction failed
   - State stuck = check what's triggering state changes
   - Options not appearing = check detection patterns
   - Messages not in chat = check bridge connection

## Future Improvements

1. **Better extraction** - More robust response boundary detection
2. **Streaming responses** - Show Claude's output as it generates
3. **File operation tracking** - Show file changes in chat
4. **Error recovery** - Handle terminal crashes gracefully
5. **Performance** - Optimize polling and extraction