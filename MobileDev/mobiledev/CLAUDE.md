# CLAUDE.md - Project Guidelines for AI Assistants

## Project Overview
MobileDev is a SwiftUI terminal application that integrates SwiftTerm to provide a native terminal experience with Claude Code support on macOS and iOS.

## Key Development Guidelines

### Code Quality Requirements
**IMPORTANT**: Before presenting any code changes to the user for review:
1. **Run SwiftLint** (if configured): `swiftlint` in the project directory
2. **Build the project**: `xcodebuild -project mobiledev.xcodeproj -scheme mobiledev -configuration Debug build`
3. Ensure all compiler warnings and errors are resolved
4. Verify the changes work as expected

### Project Structure
- **SwiftTerm Integration**: The app uses SwiftTerm as a local Swift package dependency (forked version with fixes)
- **Terminal View**: Uses `LocalProcessTerminalView` wrapped in `NSViewRepresentable` for SwiftUI
- **Platform Support**: Primary focus on macOS with iOS support planned

### SwiftTerm Fork Modifications
We maintain a fork of SwiftTerm with the following fixes:
1. **Cmd+Backspace Support**: Added handling for `deleteToBeginningOfLine:` selector that sends Ctrl+U (0x15) to delete to beginning of line

### Known Limitations
1. **iOS Support**: LocalProcess is not available on iOS, so terminal functionality is limited to a demo mode on that platform.
2. **Sandbox**: The app requires sandbox to be disabled for full terminal functionality.

### Testing Checklist
When making changes, ensure:
- [ ] Code compiles without errors
- [ ] SwiftUI previews work (if applicable)
- [ ] Terminal launches successfully
- [ ] Claude Code integration works
- [ ] Keyboard input is properly handled
- [ ] Terminal output displays correctly

### Common Build Commands
```bash
# Build the project
xcodebuild -project mobiledev.xcodeproj -scheme mobiledev -configuration Debug build

# Clean build folder
xcodebuild -project mobiledev.xcodeproj -scheme mobiledev -configuration Debug clean

# Run SwiftLint (if installed)
swiftlint

# Build with verbose output for debugging
xcodebuild -project mobiledev.xcodeproj -scheme mobiledev -configuration Debug build -verbose
```

### Dependencies
- SwiftTerm (local package at `../..`)
- SwiftUI
- AppKit (macOS)
- UIKit (iOS)

### Important Files
- `SwiftUITerminalView.swift` - Main terminal view wrapper
- `ContentView.swift` - App's main view
- `mobiledev.entitlements` - App entitlements (sandbox disabled)

### Development Tips
1. Always test changes on the target platform
2. Use Xcode's console to debug terminal output issues
3. Check SwiftTerm's sample apps for implementation examples
4. Remember that terminal apps often need special entitlements or permissions

## AI Assistant Reminders
- Always validate code changes with a build before presenting to the user
- Consider platform differences (macOS vs iOS) when suggesting changes
- Be aware of SwiftTerm's API limitations and workarounds
- Test keyboard input and terminal output thoroughly
- Document any workarounds or known issues in code comments