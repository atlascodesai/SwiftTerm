# SwiftUI Messaging Interface Guide

## Overview
Standard patterns for implementing messaging interfaces in SwiftUI with iOS 17+ features and interactive message options.

## Core Architecture

### Main View Structure
- **VStack** container with messages list and input area
- **ScrollViewReader** for auto-scrolling to new messages
- **LazyVStack** for performance with large message lists
- **MessageInputView** for text input and send functionality

### Key Components

#### MessageBubble
- Handles message alignment (left/right based on sender)
- Custom bubble styling with background colors
- Timestamp display
- Support for interactive options when needed

#### MessageInputView
- Multi-line TextField with `axis: .vertical`
- Send button with proper state management
- Keyboard handling and safe area considerations

## iOS 17+ Features

### Enhanced Text Input
```swift
TextField("Message", text: $text, axis: .vertical)
    .lineLimit(1...4)
    .scrollDismissesKeyboard(.interactively)
```

### Performance Optimizations
- LazyVStack for efficient rendering
- ScrollViewReader for programmatic scrolling
- Proper state management with @State and @Binding

## Interactive Message Options

### Implementation Pattern
Some messages can include 3 selectable options below the message bubble:

#### Option Button Layout
```swift
HStack(spacing: 8) {
    ForEach(message.options ?? [], id: \.self) { option in
        Button(option.title) {
            handleOptionSelection(option)
        }
        .buttonStyle(.bordered)
    }
}
```

#### Message Model Extension
```swift
struct Message {
    let text: String
    let isFromCurrentUser: Bool
    let timestamp: Date
    let options: [MessageOption]? // Optional interactive options
}

struct MessageOption {
    let title: String
    let value: String
}
```

## Best Practices

### UI/UX Standards
- Message bubbles align left (received) or right (sent)
- Consistent spacing (8pt between messages, 16pt padding)
- Proper color contrast (blue for sent, gray for received)
- Timestamp styling with secondary color

### Keyboard & Scrolling
- Auto-scroll to bottom when new messages arrive
- Interactive keyboard dismissal
- Safe area handling for input field
- Proper focus management

### Performance Considerations
- Use LazyVStack for large message lists
- Implement message pagination for extensive conversations
- Efficient state updates to prevent unnecessary re-renders

### Accessibility
- Proper VoiceOver support for message content
- Clear button labels for interactive options
- Appropriate color contrast ratios

## Optional Enhancements

### Custom Bubble Shapes
- Rounded corners with tail indicators
- Different styling for system vs user messages
- Animation support for message appearance

### Advanced Features
- Message status indicators (sent, delivered, read)
- Typing indicators
- Message reactions or emoji responses
- File attachment support