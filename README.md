# Atoll Attack - Island Conquest RTS

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
- ✅ **Responsive layout for device rotation** *(Completed!)*
- ✅ **Deep link infrastructure & Join Screen (Phase 1)**
  - Asset links & universal links configured in Firebase Hosting
  - Cloud Function redirect endpoint at `/i/{code}`
  - App Links handling in Flutter via `app_links` package

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

- **Custom App Links & Universal Links** hosted on `link.atoll-attack.com` via Firebase Hosting and Cloud Functions
- **Serverless redirect endpoint** at `/i/{code}` to lookup invite in Firestore
- **Static .well-known JSON** files (`assetlinks.json`, `apple-app-site-association`) for OS deep-link verification
- **WebRTC peer-to-peer & WebSocket** connections for real-time gameplay (2-4 players max)
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

1. **Phase 2: Game Session Management**

   - Create game rooms with unique codes
   - Implement waiting/active/completed states
   - Add rejoin functionality

2. **Phase 3: Real-time Synchronization**

   - WebSocket server for game commands
   - Client-side prediction & smoothing
   - Server reconciliation logic

3. **Phase 4: Social Features & Polish**

   - Show who invited you and preview opponent's island
   - Victory sharing & replay
   - App store assets, tutorial, SFX & music
   - Performance optimization & scaling

## 🛠️ Technical Stack

- **Frontend**: Flutter + Flame Engine
- **Multiplayer**: WebSockets / WebRTC + Firebase
- **Deep Links**: Custom App Links & Universal Links via Firebase Hosting + Cloud Functions
- **Backend**: Firebase Firestore + Cloud Functions
- **Analytics**: Firebase Analytics
- **Crash Reporting**: Firebase Crashlytics

## 🎯 Design Philosophy

Atoll Attack is designed as a "snackable" RTS—quick matches you can play with friends during a coffee break. The invite system removes friction: no accounts, no lobbies, just "tap link and play." Every island is unique, making each battle memorable and shareable.

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
- Full landscape/portrait orientation support

## 🤝 Contributing

This is currently a solo project, but contributions are welcome! Please check the issues tab for areas where help is needed.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

---

*Atoll Attack - Where islands become battlefields and friends become rivals!*

