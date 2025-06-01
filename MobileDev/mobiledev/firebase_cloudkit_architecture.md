# Firebase + CloudKit Terminal Chat Sync Architecture

## Project Overview
A unified SwiftUI terminal chat application that runs on both macOS and iOS from a single codebase. The macOS app acts as the terminal host (executing commands), while iOS devices act as remote clients. Chat history syncs seamlessly across devices, enabling continuous development workflows when away from the Mac.

## Architecture Goals
- **Single codebase** - One SwiftUI project for both platforms
- **Real-time chat sync** - See command history on any device via Firebase  
- **Zero-friction setup** - Automatic device discovery using hashed CloudKit ID
- **Privacy-first** - CloudKit ID is hashed before use in Firebase
- **Cost-efficient** - Optimized for Firebase free tier with CloudKit archival
- **Offline-capable** - Works without connection, syncs when online

## Technical Stack
- **Firebase Firestore** - Real-time sync for active chats
- **CloudKit** - Long-term history archive
- **SwiftTerm** - Terminal emulation on macOS
- **SwiftUI** - Single codebase for macOS/iOS
- **CryptoKit** - Privacy-preserving ID hashing

## Authentication & Identity

### Privacy-First User Identity
```swift
import CloudKit
import CryptoKit

func getUnifiedUserID(completion: @escaping (String?) -> Void) {
    // Fetch CloudKit ID without any UI
    CKContainer.default().fetchUserRecordID { recordID, error in
        guard let cloudKitID = recordID?.recordName else {
            completion(nil)
            return
        }
        
        // Hash CloudKit ID for privacy
        let salt = "com.mobiledev.terminal.2024"
        let input = cloudKitID + salt
        let hashed = SHA256.hash(data: input.data(using: .utf8)!)
        
        // Format as standard UUID
        let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()
        let uuid = String(hashString.prefix(32))
        let formattedUUID = "\(uuid.prefix(8))-\(uuid.dropFirst(8).prefix(4))-\(uuid.dropFirst(12).prefix(4))-\(uuid.dropFirst(16).prefix(4))-\(uuid.dropFirst(20).prefix(12))"
        
        completion(formattedUUID)
    }
}
```

### Why This Approach
- **No login required** - Uses existing iCloud account
- **Privacy preserved** - Firebase never sees real CloudKit ID
- **Consistent across devices** - Same hash on all user's devices
- **Automatic discovery** - No pairing codes needed

## Data Architecture

### Optimized Storage Strategy
Split data between Firebase (real-time) and CloudKit (archive):

**Firebase - Active Data Only**
```swift
// Lightweight metadata for real-time sync
struct FirebaseChat {
    let id: String
    let title: String
    let lastMessagePreview: String  // Last 100 chars
    let lastActiveAt: Date
    let activeDeviceId: String
    let pendingCommand: String?
}

// Recent messages only (last 48 hours)
struct FirebaseMessage {
    let chatId: String
    let content: String  // Truncated if > 1000 chars
    let sender: String   // "user", "terminal", "system"
    let timestamp: Date
    let deviceId: String
}
```

**CloudKit - Complete Archive**
```swift
// Full Chat objects with complete history
extension Chat {
    var cloudKitRecord: CKRecord {
        let record = CKRecord(recordType: "Chat", recordID: CKRecord.ID(recordName: id.uuidString))
        record["title"] = title
        record["messages"] = try? JSONEncoder().encode(messages)
        record["state"] = state.rawValue
        record["createdAt"] = createdAt
        return record
    }
}
```

### Firestore Structure
```
users/{hashedUserID}/
  activeChats/{chatId}/
    - title: string
    - lastMessagePreview: string
    - lastActiveAt: timestamp
    - activeDeviceId: string
    
  recentMessages/{messageId}/
    - chatId: string
    - content: string
    - sender: string
    - timestamp: timestamp
    - deviceId: string
    
  devices/{deviceId}/
    - type: "macOS" | "iOS"
    - name: string
    - lastSeen: timestamp
```

## Data Flow

### Command Execution Flow
```swift
// Simplified flow: iOS → Firebase → macOS → Firebase → iOS
class CommandFlow {
    // 1. iOS creates message with pending command
    func sendCommand(from iOS: Device, command: String) {
        let message = FirebaseMessage(
            chatId: currentChat.id,
            content: command,
            sender: "user",
            timestamp: Date(),
            deviceId: iOS.id
        )
        firestore.collection("recentMessages").add(message)
    }
    
    // 2. macOS listens and executes
    func listenForCommands(on macOS: Device) {
        firestore.collection("recentMessages")
            .whereField("sender", isEqualTo: "user")
            .whereField("deviceId", isNotEqualTo: macOS.id)
            .addSnapshotListener { snapshot, error in
                // Execute via TerminalBridge
                let output = TerminalBridge.execute(command)
                // Post response
            }
    }
}
```

### Hybrid Storage Manager
```swift
class HybridChatManager {un
    private let firestore = Firestore.firestore()
    private let cloudKit = CKContainer.default()
    private let coreData: NSPersistentContainer
    
    func sendMessage(_ message: ChatMessage, in chat: Chat) {
        // 1. Save locally first (instant UI update)
        coreData.save(message)
        
        // 2. Sync to Firebase (real-time to other devices)
        if message.timestamp > Date().addingTimeInterval(-48*3600) {
            firestore.saveMessage(message)
        }
        
        // 3. Queue for CloudKit (batch every 30s)
        cloudKitQueue.add(message)
    }
    
    func loadChat(_ chatId: String) {
        // 1. Load from Core Data (instant)
        let cached = coreData.fetch(chatId)
        
        // 2. Sync recent from Firebase
        firestore.fetchRecentMessages(chatId) { messages in
            // Merge with cache
        }
        
        // 3. Backfill from CloudKit if needed
        if cached.messages.count < 50 {
            cloudKit.fetchHistory(chatId)
        }
    }
}

## MVP Scope

### Phase 1: Core Chat Sync (Current Focus)
- [x] Existing Chat/ChatMessage models
- [x] Local terminal execution on macOS
- [ ] Firebase anonymous auth with hashed CloudKit ID
- [ ] Real-time message sync between devices
- [ ] Basic command execution flow
- [ ] 48-hour message retention in Firebase

### Phase 2: Enhanced Features
- [ ] CloudKit history backup
- [ ] Offline queue with sync on reconnect
- [ ] Multiple chat management
- [ ] Device presence indicators

### Phase 3: Power User Features
- [ ] SSH mode for direct terminal access
- [ ] Command history search
- [ ] Export functionality
- [ ] Workspace sync (working directory, environment)

## Cost Optimization

### Firebase Free Tier Strategy
- **Document reads**: 50K/day limit
- **Document writes**: 20K/day limit  
- **Storage**: 1GB limit

### Optimization Techniques
1. **Time-based cleanup**: Auto-delete messages > 48 hours
2. **Efficient listeners**: Only subscribe to recent messages
3. **Batched writes**: Group multiple updates
4. **Local caching**: Minimize repeated reads

### Estimated Usage (Single User)
- Commands per day: ~200
- Reads per day: ~1000 (5 devices checking)
- Writes per day: ~400 (commands + responses)
- **Well within free tier limits**

## Implementation Details

### Firebase Setup
```swift
// AppDelegate or App initialization
FirebaseApp.configure()

// Enable offline persistence
let settings = FirestoreSettings()
settings.isPersistenceEnabled = true
settings.cacheSizeBytes = 10 * 1024 * 1024 // 10MB
Firestore.firestore().settings = settings
```

### Platform-Specific Code
```swift
struct TerminalView: View {
    #if os(macOS)
    // Full terminal with local execution
    var body: some View {
        MacTerminalView(bridge: TerminalBridge())
    }
    #else
    // Chat interface that sends to Mac
    var body: some View {
        iOSChatView(manager: FirebaseChatManager())
    }
    #endif
}
```

### Key Integration Points
1. **ChatManager** → Add Firebase sync methods
2. **TerminalBridge** → Post outputs to Firebase  
3. **mobiledevApp** → Initialize Firebase
4. **ChatView** → Real-time message listeners

## Security & Privacy

### Firebase Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data (using hashed ID)
    match /users/{hashedUserId}/{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Message cleanup - allow deletion of old messages
    match /users/{hashedUserId}/recentMessages/{messageId} {
      allow delete: if resource.data.timestamp < request.time - duration.value(48, 'h');
    }
  }
}
```

### Privacy Considerations
1. **No personal data in Firebase** - Only hashed IDs
2. **CloudKit for sensitive data** - Terminal history stays in user's iCloud
3. **Local execution only** - Commands never leave the Mac
4. **No cloud terminal** - This is NOT a cloud IDE

## Summary

This architecture enables:
- **Single codebase** for macOS and iOS
- **Zero-friction setup** using hashed CloudKit ID
- **Real-time sync** via Firebase (last 48 hours)
- **Complete history** in CloudKit (private to user)
- **Cost-efficient** design within Firebase free tier
- **Privacy-first** approach with no personal data exposure

The MVP focuses on getting basic chat sync working between your Mac and iOS devices, with commands executing locally on the Mac and results syncing back to all devices in real-time.