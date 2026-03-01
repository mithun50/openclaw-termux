# Changelog

## v1.8.0 — AI Providers, SSH Access, Ctrl Keys & Configure Menu

### New Features

- **AI Providers** — New "AI Providers" screen to configure API keys and select models for 7 providers: Anthropic, OpenAI, Google Gemini, OpenRouter, NVIDIA NIM, DeepSeek, and xAI. Writes configuration directly to `~/.openclaw/openclaw.json`
- **SSH Remote Access** — New "SSH Access" screen to start/stop an SSH server (sshd) inside proot, set the root password, and view connection info with copyable `ssh` commands. Runs as an Android foreground service for persistence
- **Configure Menu** — New "Configure" dashboard card opens `openclaw configure` in a built-in terminal for managing gateway settings
- **Clickable URLs** — Terminal and onboarding screens detect URLs at tap position (joining adjacent lines, stripping box-drawing characters) and offer Open/Copy/Cancel dialog

### Bug Fixes

- **Ctrl Key with Soft Keyboard (#37)** — Ctrl and Alt modifier state from the toolbar now applies to soft keyboard input across all terminal screens (terminal, configure, onboarding, package install). Previously only worked with toolbar buttons
- **Ctrl+Arrow/Home/End/PgUp/PgDn (#38)** — Toolbar Ctrl modifier now sends correct escape sequences for arrow keys and navigation keys (e.g. `Ctrl+Left` sends `ESC[1;5D`)
- **resolv.conf ENOENT after Update (#40)** — DNS resolution failed after app update because `resolv.conf` was missing. Now ensured on every app launch (splash screen), before every proot operation (`getProotShellConfig`), and in the gateway service init — covering reinstall, update, and normal launch

### Dashboard

- Added "AI Providers" and "SSH Access" quick action cards

---

## v1.7.3 — DNS Fix, Snapshot & Version Sync

### Bug Fixes

- **DNS Breaks After a While (#34)** — `resolv.conf` is now written before every gateway start (in both the Flutter service and the Android foreground service), not just during initial setup. This prevents DNS resolution failures when Android clears the app's file cache
- **Version Mismatch (#35)** — Synced version strings across `constants.dart`, `pubspec.yaml`, `package.json`, and `lib/index.js` so they all report `1.7.3`

### New Features

- **Config Snapshot (#27)** — Added Export/Import Snapshot buttons under Settings > Maintenance. Export saves `openclaw.json` and app preferences to a JSON file; Import restores them. A "Snapshot" quick action card is also available on the dashboard
- **Storage Access** — Added Termux-style "Setup Storage" in Settings. Grants shared storage permission and bind-mounts `/sdcard` into proot, so files in `/sdcard/Download` (etc.) are accessible from inside the Ubuntu environment. Snapshots are saved to `/sdcard/Download/` when permission is granted

---

## v1.7.2 — Setup Fix

### Bug Fixes

- **node-gyp Python Error** — Fixed `PlatformException(PROOT_ERROR)` during setup caused by npm's bundled node-gyp failing to find Python. Now installs `python3`, `make`, and `g++` in the rootfs so native addon compilation works properly
- **tzdata Interactive Prompt** — Fixed setup hanging on continent/timezone selection by pre-configuring timezone to UTC before installing python3
- **proot-compat Spawn Mock** — Removed `node-gyp` and `make` from the mocked side-effect command list since real build tools are now installed

---

## v1.7.1 — Background Persistence & Camera Fix

> Requires Android 10+ (API 29)

### Node Background Persistence

- **Lifecycle-Aware Reconnection** — Handles both `resumed` and `paused` lifecycle states; forces connection health check on app resume since Dart timers freeze while backgrounded
- **Foreground Service Verification** — Watchdog, resume handler, and pause handler all verify the Android foreground service is still alive and restart it if killed
- **Stale Connection Recovery** — On app resume, detects if the WebSocket went stale (no data for 90s+) and forces a full reconnect instead of silently staying in "paired" state
- **Live Notification Status** — Foreground notification text updates in real-time to reflect node state (connected, connecting, reconnecting, error)

### Camera Fix

- **Immediate Camera Release** — Camera hardware is now released immediately after each snap/clip using `try/finally`, preventing "Failed to submit capture request" errors on repeated use
- **Auto-Exposure Settle** — Added 500ms settle time before snap for proper auto-exposure/focus
- **Flash Conflict Prevention** — Flash capability releases the camera when torch is turned off, so subsequent snap/clip operations don't conflict
- **Stale Controller Recovery** — Flash capability detects errored/stale controllers and recreates them instead of failing silently

---

## v1.7.0 — Clean Modern UI Redesign

> Requires Android 10+ (API 29)

### UI Overhaul

- **New Color System** — Replaced default Material 3 purple with a professional black/white palette and red (#DC2626) accent, inspired by Linear/Vercel design language
- **Inter Typography** — Added Google Fonts Inter across the entire app for a clean, modern feel
- **AppColors Class** — Centralized color constants for consistent theming (dark bg, surfaces, borders, status colors)
- **Dark Mode** — Near-black backgrounds (#0A0A0A), subtle surface (#121212), bordered cards
- **Light Mode** — Clean white backgrounds, light borders (#E5E5E5), bordered cards

### Component Redesign

- **Zero-Elevation Cards** — All cards now use 1px borders with 12px radius instead of drop shadows
- **Pill Status Badges** — Gateway and Node controls show pill-shaped badges (icon + label) instead of 12px status dots
- **Monochrome Dashboard** — Removed rainbow icon colors from quick action cards; all icons use neutral muted tones
- **Uppercase Section Headers** — Settings, Node, and Setup screens use letterspaced muted grey headers
- **Red Accent Buttons** — Primary actions (Start Gateway, Enable Node, Install) use red filled buttons; destructive/secondary actions use outlined buttons
- **Terminal Toolbar** — Aligned colors to new palette; CTRL/ALT active state uses red accent; bumped border radius

### Splash Screen

- **Fade-In Animation** — 800ms fade-in on launch with easeOut curve
- **App Icon Branding** — Uses ic_launcher.png instead of generic cloud icon
- **Inter Bold Wordmark** — "OpenClaw" displayed in Inter weight 800 with letter-spacing

### Polish

- **Log Colors** — INFO lines use muted grey (not red); WARN uses amber instead of orange
- **Installed Badges** — Package screens use consistent green (#22C55E) for "Installed" badges
- **Capability Icons** — Node screen capabilities use muted color instead of primary red
- **Input Focus** — Text fields highlight with red border on focus
- **Switches** — Red thumb when active, grey when inactive
- **Progress Indicators** — All use red accent color

### CI

- Removed OpenClaw Node app build from workflow (gateway-only CI now)

---

## v1.6.1 — Node Capabilities & Background Resilience

> Requires Android 10+ (API 29)

### New Features

- **7 Node Capabilities (15 commands)** — Camera, Flash, Location, Screen, Sensor, Haptic, and Canvas now fully registered and exposed to the AI via WebSocket node protocol
- **Proactive Permission Requests** — Camera, location, and sensor permissions are requested upfront when the node is enabled, before the gateway sends invoke requests
- **Battery Optimization Prompt** — Automatically asks user to exempt the app from battery restrictions when enabling the node

### Background Resilience

- **WebSocket Keep-Alive** — 30-second periodic ping prevents idle connection timeout
- **Connection Watchdog** — 45-second timer detects dropped connections and triggers reconnect
- **Stale Connection Detection** — Forces reconnect if no data received for 90+ seconds
- **App Lifecycle Handling** — Auto-reconnects node when app returns to foreground after being backgrounded
- **Exponential Backoff** — Reconnect attempts use 350ms-8s backoff to avoid flooding

### Fixes

- **Gateway Config** — Patches `/root/.openclaw/openclaw.json` to clear `denyCommands` and set `allowCommands` for all 15 commands (previously wrote to wrong config file)
- **Location Timeout** — Added 10-second time limit to GPS fix with fallback to last known position
- **Canvas Errors** — Returns honest `NOT_IMPLEMENTED` errors instead of fake success responses
- **Node Display Name** — Renamed from "OpenClaw Termux" to "OpenClawX Node"

### Node Command Reference

| Capability | Commands |
|------------|----------|
| Camera | `camera.snap`, `camera.clip`, `camera.list` |
| Canvas | `canvas.navigate`, `canvas.eval`, `canvas.snapshot` |
| Flash | `flash.on`, `flash.off`, `flash.toggle`, `flash.status` |
| Location | `location.get` |
| Screen | `screen.record` |
| Sensor | `sensor.read`, `sensor.list` |
| Haptic | `haptic.vibrate` |

---

## v1.5.5

- Initial release with gateway management, terminal emulator, and basic node support
