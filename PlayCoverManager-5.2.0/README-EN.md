# PlayCover Manager

<div align="center">

![Version](https://img.shields.io/badge/version-5.0.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20Sequoia%2015.1%2B-lightgrey.svg)
![Architecture](https://img.shields.io/badge/architecture-Apple%20Silicon-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

**APFS Volume Management Tool for PlayCover**

English | [日本語](README.md)

</div>

---

## 🎉 v5.0.0 - Stable Release

The first stable release of PlayCover Manager is now available. All critical bugs have been fixed and it is ready for production use.

**Release Details**: [RELEASE_NOTES_5.0.0.md](RELEASE_NOTES_5.0.0.md)

---

## 📖 Overview

PlayCover Manager is a macOS tool for migrating and managing iOS app data running on PlayCover to external storage. It automates APFS volume creation and mount management to save internal storage space.

### Key Features

- ✅ **External Storage Migration**: Safely move game data to external drives
- ✅ **Internal⇄External Switching**: One-click storage mode change
- ✅ **Batch Operations**: Bulk mount/unmount multiple volumes
- ✅ **Data Protection**: Capacity checks, running app checks, rsync synchronization
- ✅ **Complete Cleanup**: Safely delete all data (hidden option)

---

## 🚀 Quick Start

### Prerequisites

- macOS Sequoia 15.1 or later
- Apple Silicon Mac (M1/M2/M3/M4)
- PlayCover 3.0 or later
- External storage (APFS compatible)

### Installation Method 1: Application Bundle (Recommended)

1. **Download Latest Release**
   - Download `PlayCover Manager-5.0.0.zip` from [GitHub Releases](https://github.com/HEHEX8/PlayCoverManager/releases)

2. **Extract and Install**
   ```bash
   # Extract ZIP (or double-click in Finder)
   unzip "PlayCover Manager-5.0.0.zip"
   
   # Move to Applications folder
   mv "PlayCover Manager.app" /Applications/
   ```

3. **First Launch**
   - Right-click the app → Select "Open"
   - If Gatekeeper warning appears, click "Open"

### Installation Method 2: From Source

```bash
# Clone repository
git clone https://github.com/HEHEX8/PlayCoverManager.git
cd PlayCoverManager

# Grant execution permission
chmod +x main.sh

# Launch
./main.sh
```

### Installation Method 3: Build Yourself

```bash
# Clone repository
git clone https://github.com/HEHEX8/PlayCoverManager.git
cd PlayCoverManager

# Build application
./build-app.sh

# Install built app
mv "build/PlayCover Manager.app" /Applications/
```

### Initial Setup

1. Initial setup starts automatically when you launch the tool
2. Select external storage (USB/Thunderbolt/SSD)
3. APFS volume for PlayCover is created automatically
4. Main menu appears after setup completion

---

## 📚 Usage

### Main Menu

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📱 PlayCover Volume Manager v5.0.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. App Management
  2. Volume Operations
  3. Storage Switch (Internal⇄External)
  4. Eject Disk
  0. Exit

Select (0-4):
```

### 1. App Management

- **IPA Install**: Bulk install multiple IPA files (with progress display)
- **Uninstall**: Delete apps and related volumes

### 2. Volume Operations

- **Mount All Volumes**: Bulk mount registered volumes
- **Unmount All Volumes**: Safely bulk unmount
- **Individual Operations**: Mount/unmount/remount specific volumes

### 3. Storage Switch

- **Internal → External**: Migrate internal data to external volume
- **External → Internal**: Move external data back to internal storage
- Includes capacity checks, running app checks, and data protection

### 4. Eject Disk

Safely eject external storage (unmounts all volumes)

---

## 🏗️ Architecture

### Module Structure

```
PlayCoverManager/
├── main.sh                    # Main entry point
├── playcover-manager.command  # GUI launcher script
├── lib/                       # Modules
│   ├── 00_core.sh            # Core functions & utilities
│   ├── 01_mapping.sh         # Mapping file management
│   ├── 02_volume.sh          # APFS volume operations
│   ├── 03_storage.sh         # Storage switching
│   ├── 04_app.sh             # App installation & management
│   ├── 05_cleanup.sh         # Cleanup functions
│   ├── 06_setup.sh           # Initial setup
│   └── 07_ui.sh              # UI & menu display
├── README.md                  # Japanese README
├── CHANGELOG.md               # Change history (old version)
└── RELEASE_NOTES_5.0.0.md    # v5.0.0 Release Notes
```

### Technical Details

- **Total Lines of Code**: 6,056 lines
- **Number of Modules**: 8
- **Language**: Zsh (macOS standard shell)
- **Number of Functions**: 91
- **Testing**: Comprehensively verified

### About the Icon

The project includes a custom icon. To build with icon on macOS:

```bash
# Generate icon (run on macOS)
./create-icon.sh

# Build with icon
./build-app.sh
```

See [ICON_GUIDE.md](ICON_GUIDE.md) for details.

---

## 🐛 Bug Reports

If you find a bug, please create an Issue with the following information:

- macOS version
- Mac model (M1/M2/M3/M4)
- PlayCover version
- Steps to reproduce
- Error messages

---

## 📝 Known Limitations

1. **APFS Capacity Display**: Due to macOS specifications, capacity may appear different in Finder
   - The tool works correctly
   - Check actual effect in "Used" (top number) of Macintosh HD

2. **Intel Mac Not Supported**: Apple Silicon only

3. **PlayCover Dependency**: PlayCover must be installed

---

## 🔐 Security

- Uses sudo privileges only when absolutely necessary
- Multiple checks to prevent data corruption
- Confirmation prompts for destructive operations
- Safe data transfer via rsync

---

## 📜 License

MIT License

---

## 🙏 Acknowledgments

This tool was developed for users who enjoy iOS games on PlayCover.
All critical bugs have been fixed and it is ready for production use.

---

## 📮 Contact

- **GitHub**: [HEHEX8/PlayCoverManager](https://github.com/HEHEX8/PlayCoverManager)
- **Issues**: [Bug Reports](https://github.com/HEHEX8/PlayCoverManager/issues)

---

**Last Updated**: October 28, 2025 | **Version**: 5.0.0
