# Changelog

All notable changes to PlayCover Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release preparation
- Comprehensive README with installation and usage instructions
- MIT License
- Homebrew Cask support for easy installation
- Distribution documentation for free (unsigned) releases

### Changed
- Reorganized development documents into `docs/` directory
- Enhanced .gitignore with comprehensive Swift/Xcode exclusions
- Improved project structure for better maintainability

### Removed
- Removed PlayCover repository clone (external dependency)
- Removed old backup files and archives
- Removed paid distribution documentation (focused on free distribution)

---

## [1.0.0] - TBD

### 🎉 初回リリース

#### Added
- **クイックランチャー機能**
  - PlayCoverでインストールしたiOSアプリを一覧表示
  - アプリアイコンの表示
  - システム言語対応の表示名
  - ダブルクリックで起動
  - 起動中アプリのバッジ表示

- **検索機能**
  - アプリ名での検索
  - Bundle IDでの検索
  - システム言語名・英語名両対応
  - リアルタイム検索結果表示
  - 検索結果が空の場合の適切なメッセージ

- **ストレージ管理**
  - PlayCoverコンテナの自動検出
  - ディスクイメージ（ASIF）のサポート
  - ディスク使用量の表示
  - 保存先変更機能（セットアップウィザード統合）

- **設定画面**
  - 一般設定（ストレージ情報、保存先変更）
  - データ設定（アプリデータ管理）
  - メンテナンス設定（キャッシュクリア、アンマウント）

- **セットアップウィザード**
  - 初回起動時の設定ガイド
  - PlayCover検出
  - ディスクイメージ選択・作成
  - マウントポイント設定

- **アプリ管理**
  - インストール済みアプリの自動検出
  - アプリ情報の表示（名前、バージョン、Bundle ID）
  - アプリの起動状態追跡

#### Technical
- Swift 5.9+
- SwiftUI
- MVVM + Service Layer architecture
- macOS 11.0+ support
- Apple Silicon / Intel universal binary

---

## Development History

### 2024-11-06
- Added custom app icon with all required sizes
- Implemented free distribution setup (GitHub Releases + Homebrew)
- Created build scripts for unsigned releases
- Removed paid distribution documentation

### 2024-11-05
- Enhanced search functionality with improved empty states
- Fixed search to use system language name, standard name, and bundle short name
- Completely overhauled settings UI with organized tabs
- Integrated storage change with setup wizard for safe operation
- Fixed multiple Swift compilation errors
- Removed non-functional appearance settings

### 2024-11 (Earlier)
- Implemented core launcher functionality
- Created setup wizard
- Added PlayCover integration
- Implemented disk image management
- Built service layer architecture

---

## [0.9.0] - Development Phase

### Features Developed
- Core launcher UI
- PlayCover detection and integration
- Disk image service
- App scanning and management
- Search implementation
- Settings infrastructure

### Bug Fixes
- Memory leak fixes in app scanning
- Unmount and auto-unmount issues resolved
- Duplication handling improvements
- Process runner stability improvements

---

## Future Plans

### Planned for 1.1.0
- [ ] Enhanced app information display
- [ ] App favorite/bookmarks
- [ ] Custom app grouping
- [ ] Recent apps history
- [ ] App launch statistics

### Planned for 1.2.0
- [ ] Multi-language support (English, Japanese)
- [ ] Theme customization
- [ ] Keyboard shortcuts
- [ ] Menu bar integration
- [ ] Quick launch via spotlight

### Under Consideration
- App update notifications
- Batch operations
- App backup/restore
- PlayCover settings integration
- Custom app icons support

---

## Links

- [GitHub Repository](https://github.com/HEHEX8/PlayCoverManagerGUI)
- [Issue Tracker](https://github.com/HEHEX8/PlayCoverManagerGUI/issues)
- [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases)

---

[Unreleased]: https://github.com/HEHEX8/PlayCoverManagerGUI/compare/main...HEAD
[1.0.0]: https://github.com/HEHEX8/PlayCoverManagerGUI/releases/tag/v1.0.0
