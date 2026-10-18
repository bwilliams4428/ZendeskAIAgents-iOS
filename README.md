# Zendesk AI Agents — iOS

A minimal, **fully agnostic** iOS app that connects to any Zendesk account's
AI Agents Advanced messaging bot. The user enters their own credentials at
runtime — nothing is hardcoded, no shared secrets, no account lock-in.

## Features

- 🔐 **User-configured credentials** — channel key, subdomain, auth mode
  (anonymous or JWT), and JWT signing details entered from the first screen
- 🔑 **Keychain-backed storage** — credentials never touch disk in plaintext
- 👤 **Anonymous OR Authenticated visitors** — switch from the home screen
- 💬 **Real Zendesk Messaging SDK** — full chat UI, push-ready, JWT-ready
- 🪶 **Zero account assumptions** — works with any Zendesk subdomain

## Project layout

```
ZendeskAIAgents-iOS/
├── project.yml                    # XcodeGen config
├── Podfile                        # CocoaPods (ZendeskSDKMessaging)
├── ZendeskAIAgents/
│   ├── Info.plist
│   ├── App/                       # AppDelegate, SceneDelegate
│   ├── Credentials/               # ZendeskCredentials model + Keychain store + setup UI
│   ├── Auth/                      # JWTAuthService, ZendeskInitializer
│   ├── Views/                     # HomeViewController
│   └── Resources/                 # LaunchScreen, Assets.xcassets
```

## How the user connects

1. **First launch** — the user lands on *Connect Zendesk*. They enter:
   - Messaging **Channel Key**
   - **Subdomain** (e.g. `mycompany` for `mycompany.zendesk.com`)
   - **Auth mode**: Anonymous Visitor OR Authenticated (JWT)
   - If JWT: **JWT Signing Secret** + **JWT Server URL**
2. **Save & Connect** — credentials are encrypted into the iOS Keychain.
3. **Home** — shows connection status. Tap *Start Chat* to open the bot.
4. **JWT mode** — each chat prompts for visitor name/email/external_id,
   calls the user's JWT server, and logs into Zendesk with the returned
   token. Visitor info is remembered for next time.

## How to build & run

### Prerequisites
- Xcode 16+ (tested on Xcode 26.6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- [CocoaPods](https://cocoapods.org): `sudo gem install cocoapods` (or `brew install cocoapods`)

### One-time setup
```bash
cd ~/Projects/ZendeskAIAgents-iOS
xcodegen generate
pod install
```

### Build
```bash
# Generate Xcode project (re-run after editing project.yml)
xcodegen generate

# Build for simulator (uses Pods integration)
xcodebuild \
  -workspace ZendeskAIAgents.xcworkspace \
  -scheme ZendeskAIAgents \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug \
  build

# Open in Xcode
open ZendeskAIAgents.xcworkspace
```

### Run
Open in Xcode → select a simulator → ⌘R.

## JWT server contract (for authenticated mode)

When `authMode == .jwt`, the app calls the user-configured server:

```
POST ${JWT_SERVER_BASE_URL}/auth/jwt
Content-Type: application/json

{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "external_id": "user_12345"
}
```

Expected response:
```json
{ "token": "<signed JWT>" }
```

The JWT must be signed with the same **signing secret** configured in
Zendesk Admin Center → Channels → Messaging → Authentication.

A reference implementation is in `~/Projects/zendesk-jwt-app`
(an Express server that signs tokens with a shared secret using `jsonwebtoken`).

## Where to find your Zendesk credentials

1. Sign in to https://YOUR_SUBDOMAIN.zendesk.com
2. **Admin Center** → **Channels** → **Messaging** → **SDK**
   - Find the *Channel Key* for your messaging channel
3. **Admin Center** → **Channels** → **Messaging** → **Authentication**
   - Enable *Authenticated visitors*
   - Note the JWT signing secret (or set a new one)

## Security notes

- Credentials are stored in the **iOS Keychain** with
  `kSecAttrAccessibleAfterFirstUnlock` — they survive app restarts but
  are encrypted at rest and not included in iCloud backups.
- The JWT secret is sent over the wire only during the
  `POST /auth/jwt` call to the user-configured server. It is **not**
  embedded in the app binary.
- The app pins `localhost` as an exception for ATS so a dev JWT server
  on `http://localhost:3000` works without HTTPS. Production JWT
  servers should use HTTPS.
- For production deployment, enable code signing with your
  Apple Developer Team ID in `project.yml`.
