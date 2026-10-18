# Zendesk AI Agents — iOS

A **fully agnostic** iOS app that connects to **any** Zendesk account's
AI Agents Advanced messaging bot. The user enters their own Zendesk
credentials at runtime — nothing is hardcoded into the binary.

Supports both **anonymous** visitors and **JWT-authenticated** visitors.

---

## 🚀 Quick Start (Run on Another Mac)

If you received this project as an archive, follow these steps to build and
run it on any Mac with Xcode installed.

### 1. Prerequisites

| Tool | Min version | Install |
|---|---|---|
| **macOS** | 13.0+ (Ventura) | — |
| **Xcode** | 15.0+ | [App Store](https://apps.apple.com/us/app/xcode/id497799835) |
| **XcodeGen** | 2.38+ | `brew install xcodegen` |
| **CocoaPods** | 1.14+ | `sudo gem install cocoapods` or `brew install cocoapods` |
| **Git** | any | `xcode-select --install` if missing |

> 💡 If you don't have Homebrew: <https://brew.sh>

### 2. Extract the archive

```bash
# Wherever you want the project
cd ~/Desktop
tar -xzf ZendeskAIAgents-iOS.tar.gz
cd ZendeskAIAgents-iOS
```

### 3. Generate the Xcode project

The archive does **not** include the `.xcodeproj` or `Pods/` — they are
regenerated from `project.yml` and the `Podfile` on every machine.

```bash
xcodegen generate
```

This creates `ZendeskAIAgents.xcodeproj`.

### 4. Install CocoaPods dependencies

```bash
pod install
```

This creates `ZendeskAIAgents.xcworkspace` and downloads the
Zendesk Messaging SDK (~130 MB) into `Pods/`.

### 5. Open in Xcode

> ⚠️ **Always open the `.xcworkspace`, never the bare `.xcodeproj`**
> (opening the project file skips the Pods and you'll get
> "No such module" errors at build time.)

```bash
open ZendeskAIAgents.xcworkspace
```

### 6. Run

1. In Xcode, select a simulator from the device picker (e.g. **iPhone 16**)
2. Press **⌘R** (or Product → Run)
3. The app launches and shows the **Connect Zendesk** screen

If no simulators are listed, add one:
- Xcode → Settings → Platforms → Download the latest iOS runtime
- Then: Xcode → Window → Devices and Simulators → `+` to create one

---

## 🧑‍💻 How to Use the App

1. **First launch** — the app shows the **Connect Zendesk** screen. Fill in:
   - **Channel Key** — from Zendesk Admin Center → Channels → Messaging → SDK
   - **Subdomain** — e.g. `mycompany` (your `mycompany.zendesk.com`)
   - **Auth Mode** — pick `Anonymous Visitor` or `Authenticated (JWT)`
   - If JWT:
     - **JWT Signing Secret** — same secret configured in Zendesk Admin Center
     - **JWT Server URL** — your own HTTP server that mints signed tokens
2. **Save & Connect** — credentials are encrypted into the iOS Keychain
3. **Home screen** shows ✅ Connected and the current auth mode
4. **Start Chat** — opens the Zendesk AI Agents bot UI

### JWT Server Contract

When `Auth Mode = Authenticated (JWT)`, before each chat the app calls:

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

A reference implementation is in
[`~/Projects/zendesk-jwt-app`](https://github.com/bwilliams4428/zendesk-jwt-app)
(Express + `jsonwebtoken`).

---

## 🔧 Command-Line Build (without opening Xcode)

```bash
# List available simulators
xcrun simctl list devices available | grep iPhone

# Create a simulator if you need one
xcrun simctl create "iPhone 16 Test" \
  "com.apple.CoreSimulator.SimDeviceType.iPhone-16" \
  "com.apple.CoreSimulator.SimRuntime.iOS-18-4"

# Boot it
xcrun simctl boot "iPhone 16 Test"

# Build
xcodebuild \
  -workspace ZendeskAIAgents.xcworkspace \
  -scheme ZendeskAIAgents \
  -destination 'platform=iOS Simulator,name=iPhone 16 Test,arch=arm64' \
  -configuration Debug \
  -sdk iphonesimulator \
  ONLY_ACTIVE_ARCH=YES \
  build

# Install + launch
APP=$(find ~/Library/Developer/Xcode/DerivedData/ZendeskAIAgents-* \
  -name "ZendeskAIAgents.app" -type d | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.zendeskaiagents.app
```

---

## 🛠 Troubleshooting

| Problem | Fix |
|---|---|
| `xcodebuild: error: Unable to find a destination` | You need to download an iOS runtime: `Xcode → Settings → Platforms → +` |
| `No such module 'ZendeskSDKMessaging'` | You opened `ZendeskAIAgents.xcodeproj` instead of `ZendeskAIAgents.xcworkspace`. Run `pod install` first. |
| `xcodegen: command not found` | `brew install xcodegen` |
| `pod: command not found` | `sudo gem install cocoapods` (or `brew install cocoapods`) |
| App shows "Zendesk init failed" | Double-check the Channel Key and Subdomain. The channel key must come from Admin Center → Channels → Messaging → SDK |
| JWT login fails | Verify the JWT Server URL responds with `{"token": "..."}` and the signing secret matches what's in Zendesk |
| Localhost JWT server blocked by ATS | The Info.plist already permits `localhost` HTTP. For other hosts, edit `ZendeskAIAgents/Info.plist` and add the host to `NSExceptionDomains` |

---

## 📁 Project Layout

```
ZendeskAIAgents-iOS/
├── project.yml                                # XcodeGen config
├── Podfile                                    # CocoaPods (ZendeskSDKMessaging)
├── README.md                                  # this file
├── .gitignore
├── ZendeskAIAgents/
│   ├── Info.plist
│   ├── App/                                   # AppDelegate, SceneDelegate
│   ├── Credentials/                           # credentials model + keychain + setup UI
│   ├── Auth/                                  # JWT auth + Zendesk SDK wrapper
│   ├── Views/                                 # HomeViewController
│   └── Resources/                             # LaunchScreen, Assets.xcassets
```

---

## 🔐 Security Notes

- All credentials are stored in the **iOS Keychain** with
  `kSecAttrAccessibleAfterFirstUnlock`
- No secrets are baked into the binary
- The JWT secret is only transmitted to the user-configured JWT server
- For production deployment, set `DEVELOPMENT_TEAM` in `project.yml` and
  enable code signing

---

## 📦 Where to Get Zendesk Credentials

1. Sign in to `https://YOUR_SUBDOMAIN.zendesk.com`
2. **Admin Center** → **Channels** → **Messaging** → **SDK** → Channel Key
3. **Admin Center** → **Channels** → **Messaging** → **Authentication**
   → enable Authenticated visitors → note the JWT signing secret

---

## License

MIT — use freely.
