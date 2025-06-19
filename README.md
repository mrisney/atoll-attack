# Atoll Attack - Island Conquest RTS

<img src="screenshot.png" alt="Atoll Attack Screenshot" width="300">

A real-time strategy game where players battle for control of procedurally generated islands. Command your units, capture strategic positions, and plant your flag at the island's apex to claim victory!

## 🎮 Game Overview

Atoll Attack is a mobile-first RTS game featuring:
- **Procedurally generated islands** with unique terrain and elevation
- **Three unit types**: Captains (flag bearers), Archers (ranged), and Swordsmen (melee)
- **Strategic gameplay**: Use terrain elevation for tactical advantages
- **Quick battles**: 5-10 minute matches perfect for mobile play
- **Touch-optimized controls**: Drag to select, tap to move, pinch to zoom

## 🏗️ Current Architecture

### Player System
- Migrated from Team enum to flexible Player system
- Supports multiple players with unique IDs
- Tracks unit spawning and resource limits per player

### Core Components
- **UnitModel**: Individual unit data with player ownership
- **ShipComponent**: Naval units for unit deployment
- **IslandComponent**: Procedural terrain generation with GPU shaders
- **CombatRules**: Deterministic combat calculations
- **Snapshot System**: Full game state serialization

### Key Features Implemented
- ✅ Real-time unit movement and combat
- ✅ Drag-to-select unit groups
- ✅ Procedural island generation with elevation-based gameplay
- ✅ Flag capture victory condition
- ✅ Responsive UI scaling
- ✅ Ship-based unit deployment system

## 🚀 Planned Multiplayer System

### Invite-Based Multiplayer (No Lobby Required)
Instead of traditional matchmaking, Atoll Attack will use a friend-invite system perfect for mobile gaming:

#### How It Works:
1. **Create Your Island**: Generate a unique battlefield with your preferred settings
2. **Challenge a Friend**: Send an invite link via SMS, WhatsApp, or any messaging app
3. **Smart Deep Links**: 
   - If they have the game → Opens directly to your battle
   - If they don't → Redirects to App Store/Google Play with preview
4. **Async-Friendly**: Start playing vs AI while waiting for your friend to join

#### Example Flow:
```
Player A: Creates island → Taps "Invite Friend" → Shares link
Message: "🏝️ Join me in Atoll Attack! I've created an island battlefield. Code: ISLAND-X7B2"
Player B: Clicks link → App opens → Joins battle instantly
```

#### Technical Approach:
- **Firebase Dynamic Links** for cross-platform deep linking
- **WebSocket connections** for real-time gameplay (2-4 players max)
- **Game codes** for easy sharing (e.g., "ISLAND-X7B2")
- **7-day expiration** on game invites
- **Rejoin support** for interrupted games

#### Benefits:
- No account/login required
- Personal invites increase engagement
- Natural viral growth through sharing
- Works great for quick 1v1 or 2v2 matches
- Perfect for mobile-first gameplay

## 📋 Next Tasks

### 1. Fix Responsive Layout for Rotation
- Handle landscape/portrait transitions smoothly
- Optimize UI element positioning for different orientations
- Test on various device sizes

### 2. Implement Invite-Based Multiplayer
- **Phase 1**: Deep link infrastructure
  - Set up Firebase Dynamic Links
  - Create invite link generation
  - Handle incoming links
  
- **Phase 2**: Game session management
  - Create game rooms with unique codes
  - Implement waiting/active/completed states
  - Add rejoin functionality
  
- **Phase 3**: Real-time synchronization
  - WebSocket server for game commands
  - Client-side prediction
  - Server reconciliation
  
- **Phase 4**: Social features
  - Show who invited you
  - Preview opponent's island
  - Victory sharing

### 3. Build AI Player System
- Behavior tree architecture
- Multiple difficulty levels
- Strategic goal planning
- Tactical unit micro-management

### 4. Polish & Ship
- App store assets
- Tutorial system
- Sound effects and music
- Performance optimization

## 🛠️ Technical Stack

- **Frontend**: Flutter + Flame Engine
- **Multiplayer**: WebSockets + Firebase
- **Deep Links**: Firebase Dynamic Links / Branch.io
- **Backend**: Firebase Firestore + Cloud Functions
- **Analytics**: Firebase Analytics
- **Crash Reporting**: Firebase Crashlytics

## 🎯 Design Philosophy

Atoll Attack is designed as a "snackable" RTS - quick matches you can play with friends during a coffee break. The invite system removes friction: no accounts, no lobbies, just "tap link and play." Every island is unique, making each battle memorable and shareable.

## 🔧 Development Setup

```bash
# Install dependencies
flutter pub get

# Run on device
flutter run

# Build for release
flutter build apk  # Android
flutter build ios  # iOS
```

## 📱 Platform Support

- iOS 12.0+
- Android 6.0+ (API 23+)
- Optimized for phones (tablet support planned)

## 🤝 Contributing

This is currently a solo project, but contributions are welcome! Please check the issues tab for areas where help is needed.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

---

*Atoll Attack - Where islands become battlefields and friends become rivals!*