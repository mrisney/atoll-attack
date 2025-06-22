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