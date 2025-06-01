# Testing Option Selection Response Capture

## The Problem

When a user selects a text-based option (like "1. Replace it with a new poem"), the response from Claude isn't being captured in the chat view. This happens because:

1. The UI creates a CommandEntry with command = "Selected: 1. Replace it with a new poem"
2. Then it sends the actual command "1" to the terminal
3. The extractResponseFromRawFeed method looks for "> Selected: 1. Replace it with a new poem" in the terminal, which never appears
4. The actual response is associated with the "1" command, not the "Selected:" entry

## The Fix

The fix involves:

1. **For text-based options**: Track the actual command sent ("1", "2", etc.) instead of a synthetic "Selected:" command
2. **Better response extraction**: Add logic to extract responses after option selections
3. **Improved completion detection**: Extract responses when Claude finishes generating

## Key Changes Made

### 1. In `selectOption` method:
- For text-based options, we now create a CommandEntry with the actual command text ("1", "2", etc.)
- We store the full option text in the `selectedOption` field
- This ensures the response extraction can find the command in the terminal

### 2. In `extractResponseFromRawFeed` method:
- Added special handling for arrow-based selections (commands starting with "Selected:")
- These use the terminal snapshot to find where to start extracting the response

### 3. In `processCommandCompletion` method:
- Added detection for numeric option selections (commands like "1", "2", "3")
- Triggers response extraction after a short delay when processing option responses
- Also extracts responses when generation completes (detected by seeing a prompt)

## Testing Steps

1. Launch Claude in the terminal
2. Ask Claude to create a poem
3. When Claude presents options, click one of the option buttons
4. Verify that Claude's response appears in the chat history (in the Analysis Panel)

## Expected Behavior

After selecting an option:
- The command "1" (or whichever number) should appear in the history
- Claude's response should be captured and displayed under that command
- The selectedOption field should contain the full option text for reference