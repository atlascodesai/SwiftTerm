# Terminal Parsing Logic

This document explains how the MobileDev terminal app intercepts, parses, and interacts with the terminal output, particularly for Claude Code integration.

## Overview

The app uses SwiftTerm's `LocalProcessTerminalView` to run a shell process and captures its output in real-time. We've built a sophisticated parsing system on top of this to:

1. Detect when Claude is running
2. Track Claude's state (generating, waiting for input, etc.)
3. Extract command responses
4. Detect and interact with Claude's option menus
5. Track user selections

## Architecture

### Key Components

1. **SwiftUITerminalView** - NSViewRepresentable wrapper that integrates SwiftTerm with SwiftUI
2. **TerminalViewModel** - Central state management and business logic
3. **ClaudeOutputAnalyzer** - Parses terminal output to detect Claude's activities
4. **ContentView** - UI layer with special controls for Claude interaction

## Terminal Output Capture

### Polling Mechanism

```swift
// SwiftUITerminalView.swift
func startOutputCapture() {
    outputTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
        self.captureOutput()
    }
}
```

- Polls terminal buffer every 0.5 seconds
- Extracts full terminal content using `terminal.getBufferAsData()`
- Tracks changes in content length to optimize processing
- Only logs when content actually changes

### Content Flow

1. **Raw Capture**: Full terminal buffer → `rawTerminalFeed`
2. **New Content Detection**: Compares with previous capture to identify new output
3. **State Analysis**: Parses for Claude-specific patterns
4. **Response Extraction**: Captures command outputs for history

## Claude State Detection

### ESC Pattern Detection

The primary mechanism for detecting when Claude is generating a response:

```swift
let hasEscPattern = content.contains("esc to interrupt")
```

- **Pattern appears**: Claude is actively generating
- **Pattern disappears**: Generation complete, ready for extraction

### Prompt Detection

Detects when Claude is ready for input:

```swift
let claudePromptVisible = self.parent.viewModel.isClaudeRunning && 
                        (content.contains("│ >") && content.contains("│") && 
                         content.contains("? for shortcuts"))
```

### State Transitions

1. **Not Running** → **Starting...** (when "claude" command sent)
2. **Starting...** → **Ready for input** (when welcome box appears)
3. **Ready for input** → **Generating response...** (when ESC pattern appears)
4. **Generating response...** → **Ready for input** (when ESC pattern disappears)
5. **Any state** → **Waiting for input** (after option 3 selected)

## Response Extraction

### Command Tracking

Every user command creates a `CommandEntry`:

```swift
struct CommandEntry {
    let command: String
    var rawResponse: String = ""
    var isComplete: Bool = false
    var selectedOption: String? = nil
}
```

### Extraction Process

1. **Find Command**: Locate "> command" in terminal output
2. **Extract Content**: Capture everything after command until next prompt
3. **Clean Response**: Remove UI elements (boxes, prompts, etc.)
4. **Store Result**: Update CommandEntry with cleaned response

### Cleaning Logic

```swift
private func cleanResponseText(_ text: String) -> String {
    // Skip lines with:
    // - Box borders (╭─, ╰─)
    // - Empty prompt lines (│ > │)
    // - UI hints ("? for shortcuts")
}
```

## Option Menu Detection

### Pattern Recognition

When Claude presents options, we detect:

```
│ Do you want to create poem.md?                    │
│ ❯ 1. Yes                                          │
│   2. Yes, and don't ask again this session        │
│   3. No, and tell Claude what to do differently   │
```

### Detection Logic

1. **Direct Terminal Scan**: Looks for "❯ 1." pattern
2. **Context Validation**: Ensures "Do you want to" question present
3. **Option Extraction**: Parses and cleans option text
4. **UI Update**: Shows option buttons

### Option Selection

When user clicks an option button:

1. **Navigation**: Sends arrow keys to move selection
   - Option 1: Just press Enter
   - Option 2: Down arrow → Enter
   - Option 3: Down arrow → Down arrow → Enter

2. **Tracking**: Creates special CommandEntry marked as selection

3. **State Update**: Option 3 triggers "Waiting for input" state

## Terminal Control

### Sending Commands

```swift
func sendCommand(_ command: String) {
    terminal.send(txt: command)  // Send text
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        terminal.send([13])  // Send CR (Enter)
    }
}
```

### Special Keys

- **Enter**: `[13]` (Carriage Return)
- **Up Arrow**: `[0x1B, 0x5B, 0x41]` (ESC [ A)
- **Down Arrow**: `[0x1B, 0x5B, 0x42]` (ESC [ B)
- **Ctrl+C**: `[0x03]` (Interrupt)

## Edge Cases Handled

### Terminal Clearing

- Terminal sometimes clears/redraws (e.g., 1596 → 734 chars)
- Solution: Capture immediately when generation completes

### Timing Issues

- Responses may not be fully rendered when ESC disappears
- Solution: Multiple detection points and state tracking

### Option Menu Variations

- Options may have different formatting/markers
- Solution: Flexible pattern matching, removes box characters

### State Synchronization

- UI state may drift from actual terminal state
- Solution: Multiple verification points, defensive state updates

## UI Integration

### Command History

- Shows all commands with expand/collapse
- Special formatting for option selections
- Copy functionality for responses

### Option Buttons

- Appear dynamically when options detected
- Send appropriate key sequences
- Track selection in history

### Status Indicators

- Real-time Claude state display
- Visual feedback for operations
- Progress indicators during generation

## Best Practices

1. **Always update raw feed first** - Ensures complete content available
2. **Use multiple detection methods** - Redundancy prevents missed states
3. **Clean extracted content** - Remove UI elements for clarity
4. **Track state transitions** - Helps debug unexpected behavior
5. **Log key events** - Essential for troubleshooting

## Future Improvements

1. **Smarter extraction** - ML-based response boundary detection
2. **Performance optimization** - Reduce polling frequency when idle
3. **More Claude features** - Handle file operations, build status
4. **Better error recovery** - Handle terminal crashes gracefully
5. **Accessibility** - Screen reader support for terminal content