# MobileDev - SwiftUI Terminal with Claude Code Integration

A native macOS/iOS terminal application built with SwiftUI and SwiftTerm, featuring seamless Claude Code CLI integration.

## Features

- Native SwiftUI interface
- Full terminal functionality via SwiftTerm
- Claude Code CLI integration
- Starts in your GitHub directory (`~/Documents/Github`)
- Proper keyboard shortcut handling

## SwiftTerm Fork Improvements

This project uses a local fork of SwiftTerm with the following enhancements:

### Fixed: Cmd+Backspace Support
- Added handling for `deleteToBeginningOfLine:` selector
- Sends Ctrl+U (0x15) to delete from cursor to beginning of line
- Fixes "Unhandle selector deleteToBeginningOfLine:" error

**TODO**: Submit this fix as a pull request to the upstream SwiftTerm repository at https://github.com/migueldeicaza/SwiftTerm

## Building the Project

1. Open `mobiledev.xcodeproj` in Xcode
2. Select the "mobiledev" scheme
3. Build and run (Cmd+R)

## Requirements

- macOS 14.0+ (for @Observable macro support)
- Xcode 15.0+
- Claude Code CLI installed (optional, for Claude integration)

## Known Limitations

- iOS support is limited (LocalProcess not available on iOS)
- App sandbox must be disabled for terminal functionality

## Future Roadmap

See `claude-code-mvp-roadmap.md` for planned features including:
- MVP3: Workflow completion detection
- MVP4: Multi-session & image support
- MVP5: Chat history
- MVP6: iOS deep links

## Development Notes

See `CLAUDE.md` for detailed development guidelines and AI assistant instructions.