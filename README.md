# PlayCover Manager

<div align="center">

![PlayCover Manager Icon](PlayCoverManager/Assets.xcassets/AppIcon.appiconset/icon_512x512.png)

**GUI tool for managing PlayCover iOS apps on macOS**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2026.0+-lightgrey.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## Overview

PlayCover Manager is a GUI application for managing iOS apps installed via PlayCover on macOS. It provides an integrated interface for installing IPAs, launching apps, and managing storage.

### Features

- 🎯 IPA installer integration
- 🚀 Quick launcher with search
- 🗑️ Batch uninstaller
- 💾 ASIF disk image management
- 📦 External drive support
- ⌨️ Keyboard navigation

---

## Requirements

- **macOS 26.0 Tahoe or later** (ASIF format required)
- **Apple Silicon Mac** (Intel not supported)
- **PlayCover.app** (must be installed separately)

---

## Installation

### Download from Releases

1. Download `PlayCoverManager.dmg` from [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases)
2. Open DMG and drag to Applications folder
3. First launch: Right-click → "Open" (unsigned app)

### Build from Source

```bash
git clone https://github.com/HEHEX8/PlayCoverManagerGUI.git
cd PlayCoverManagerGUI
./scripts/build_release_unsigned.sh
```

**Requirements**: macOS 15.6+, Xcode 26.0+, Node.js (optional, for better DMG)

---

## Usage

### Initial Setup

1. Launch app (macOS version check)
2. Select PlayCover.app location
3. Select ASIF disk image storage location

### Install IPA

Click "Install IPA" → Select IPA file → Confirm → Install

### Launch Apps

- Double-click app icon
- Search and double-click
- Press Enter for recent app

### Uninstall

- **Single**: Right-click → "Uninstall"
- **Batch**: Click "Uninstaller" → Select apps → Execute

---

## Technical Details

- **Language**: Swift 6.0+
- **UI**: SwiftUI
- **Architecture**: MVVM + Service Layer
- **Storage**: ASIF (Apple Sparse Image Format)

### Project Structure

```
PlayCoverManager/
├── Views/          # SwiftUI views
├── ViewModels/     # State management
├── Services/       # Business logic
├── Models/         # Data models
└── Utilities/      # Helpers
```

---

## Compatibility Note

This is a complete rewrite of the [original CLI version](https://github.com/HEHEX8/PlayCoverManager). **No compatibility between versions** due to fundamentally different storage technologies (APFS volumes vs ASIF disk images).

---

## License

MIT License - See [LICENSE](LICENSE) for details

---

## Links

- [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases)
- [Issues](https://github.com/HEHEX8/PlayCoverManagerGUI/issues)
- [PlayCover Official](https://github.com/PlayCover/PlayCover)
