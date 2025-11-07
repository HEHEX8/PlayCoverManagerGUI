# PlayCover Manager

<div align="center">

![PlayCover Manager Icon](PlayCoverManager/Assets.xcassets/AppIcon.appiconset/icon_512x512.png)

**macOS Tahoe 26.0+ 用 PlayCover アプリ統合管理ツール**

IPA インストール • アプリ起動 • ストレージ管理 • アンインストール

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2026.0%20Tahoe+-lightgrey.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[機能](#-機能) • [必須環境](#-必須環境) • [インストール](#-インストール) • [使い方](#-使い方) • [開発](#-開発)

</div>

---

## 📖 概要

**PlayCover Manager** は、PlayCover でインストールした iOS アプリを統合的に管理するための GUI ツールです。

> **🔗 オリジナル版**: このプロジェクトは [PlayCoverManager (ZSH CLI版)](https://github.com/HEHEX8/PlayCoverManager) の完全リライト・進化版です。ZSH スクリプトベースの CLI ツールから、SwiftUI による GUI アプリへと生まれ変わりました。

### 主な特徴

- ✅ **IPA インストーラー統合** - GUI から IPA ファイルを選択してインストール
- ✅ **クイックランチャー** - インストール済みアプリを一覧表示・起動
- ✅ **アプリアンインストーラー** - 複数アプリの一括アンインストール
- ✅ **ASIF ディスクイメージ** - macOS Tahoe の最新フォーマット採用
- ✅ **ストレージ管理** - 外部ドライブへの保存先変更対応
- ✅ **検索機能** - アプリ名・Bundle ID で素早く検索

### 🆚 オリジナル版との主な違い

このプロジェクトはオリジナルの [PlayCoverManager (ZSH CLI版)](https://github.com/HEHEX8/PlayCoverManager) から大幅に進化していますが、**完全な互換性はありません**。

| 項目 | オリジナル版 (ZSH CLI) | GUI 版 (このプロジェクト) |
|------|----------------------|------------------------|
| **ストレージ形式** | APFS ボリューム（ディスク/パーティション上） | **ASIF ディスクイメージ** (`.asif` ファイル) |
| **ボリューム作成** | `diskutil apfs addVolume` | `diskutil image create --format ASIF` |
| **対応 macOS** | macOS Sequoia 15.1+ | **macOS Tahoe 26.0+** のみ |
| **マッピングファイル** | `playcover-map.txt` (TSV: `VolumeName|BundleID|DisplayName|LastLaunched`) | 不要（`.asif` ファイル名が BundleID） |
| **起動履歴管理** | TSV ファイルの4列目でフラグ管理 | `map.dat` で最近起動アプリ記録 |
| **マウント方法** | `mount -t apfs -o nobrowse` | `diskutil image attach` |
| **ボリューム管理** | 手動マウント/アンマウント必須 | 自動マウント・自動管理 |
| **IPA インストール** | PlayCover.app に依存 | PlayCover.app に依存（同じ） |
| **設定保存** | スクリプト内部 + TSV ファイル | UserDefaults + plist |
| **コンテナロック** | 未実装 | **実装済み**（多重起動防止） |
| **アプリ起動** | `open -a [app.app]` で直接起動 | `open [app.app]` で直接起動（同じ） |
| **起動前マウント** | ボリューム状態確認 + 必要に応じてマウント | 自動マウント（LauncherService 経由） |
| **プロセス監視** | 未実装 | **実装済み**（NSWorkspace で監視） |
| **ストレージ移行** | rsync ベース手動コピー | **自動再マウント対応** |
| **Nuclear Cleanup** | 実装（破壊的削除） | 未実装（安全性重視） |

#### 技術的な非互換性

1. **ストレージ形式の根本的な違い**
   - **オリジナル版**: 実際のディスク/パーティション上に **APFS ボリューム** を作成
     - 外部ドライブや内蔵ストレージ上に `diskutil apfs addVolume` でボリュームを作成
     - ボリューム名（例: `io.playcover.PlayCover`）でディスク上に直接存在
     - `mount -t apfs -o nobrowse /dev/diskXsY ~/Library/Containers/[BundleID]` でマウント
   - **GUI 版**: ファイルシステム上に **ASIF ディスクイメージファイル** (`.asif`) を作成
     - 各アプリごとに `[BundleID].asif` ファイルを作成（例: 50GB の単一ファイル）
     - `diskutil image create --format ASIF` で作成
     - `diskutil image attach [BundleID].asif --mountPoint ~/Library/Containers/[BundleID]` でマウント
   - **完全に非互換**: APFS ボリュームと ASIF ファイルは全く異なる技術

2. **ストレージ柔軟性の違い**
   - **オリジナル版**: 
     - APFS の動的容量割り当て活用（コンテナ内で容量共有）
     - 複数ボリュームが同じ物理領域を効率的に共有
     - スナップショット・クローン機能が使える
   - **GUI 版**:
     - 各 `.asif` ファイルは固定最大サイズ（アプリ: 50GB、PlayCover コンテナ: 10TB）
     - ファイルごとに独立した容量を消費
     - ファイル移動が容易（外部ドライブ間のコピーが可能）
   - **トレードオフ**: オリジナル版は容量効率が良いが、GUI 版はファイル管理が直感的

3. **アプリ起動方法の違い**
   - **オリジナル版 (lib/04_app.sh:launch_app)**:
     - 起動前にボリュームマウント状態を確認
     - 必要に応じて `mount_app_volume` でマウント
     - `open -a "$app_path"` で `.app` を起動
     - 起動後、TSV ファイルの4列目を更新（最近起動フラグ）
   - **GUI 版 (LauncherService.swift:openApp)**:
     - LauncherService が自動的にマウント管理
     - `open "$app_path"` で `.app` を直接起動（`-a` フラグなし）
     - NSWorkspace でプロセス監視（`isAppRunning`）
     - `map.dat` に最近起動アプリを記録
   - **共通点**: 両方とも PlayCover.app 経由ではなく、`.app` を直接起動

4. **マッピング・管理の違い**
   - **オリジナル版**: 
     - `playcover-map.txt` (TSV形式) で管理：
       ```
       VolumeName<TAB>BundleID<TAB>DisplayName<TAB>LastLaunched
       ```
     - ロック機構実装（`MAPPING_LOCK_FILE` でディレクトリロック）
     - `diskutil list` で実際のボリュームの存在を確認
     - ボリューム名とマウント状態を手動追跡
   - **GUI 版**:
     - マッピングファイル不要（`.asif` ファイル名が BundleID）
     - ファイルシステムで `.asif` ファイルの存在を確認するだけ
     - マウント状態は `diskutil info` で確認
     - ContainerLockService でコンテナロック実装
   - **完全に非互換**: ストレージ形式・データ構造が根本的に異なる

5. **設定・状態管理の違い**
   - **オリジナル版**: 
     - zsh スクリプト変数（`00_core.sh` 内で定義）
     - TSV マッピングファイル（ボリューム↔アプリ関連付け）
     - 環境変数（`PLAYCOVER_BASE`, `DATA_DIR` など）
   - **GUI 版**: 
     - UserDefaults (plist) でアプリ設定保存
     - `.asif` ファイル自体がメタデータ保持
     - SettingsStore で SwiftUI @Observable 管理
   - **完全に非互換**: 設定形式・保存方法が全く異なる

6. **Nuclear Cleanup（完全リセット）**
   - **オリジナル版 (lib/05_cleanup.sh)**:
     - 隠しメニュー（メインメニューで "X" または "RESET" 入力）
     - 全ボリューム削除 + PlayCover アンインストール + コンテナ削除
     - 2段階確認（"yes" + "DELETE ALL"）
     - 削除前にプレビュー表示
   - **GUI 版**:
     - **未実装**（意図的に除外 - 安全性重視）
     - 個別アンインストールのみ提供
   - **理由**: GUI で破壊的操作は危険なため実装せず

#### 🚫 互換性について

**オリジナル版（ZSH CLI）と GUI 版の間に互換性は全くありません。**

以下の理由により、両バージョンは完全に独立したプロジェクトです：

1. **ストレージ技術の根本的な違い**
   - APFS ボリューム（物理ディスク上の論理ボリューム）
   - vs ASIF ディスクイメージファイル（ファイルシステム上の単一ファイル）

2. **データ構造の完全な不一致**
   - TSV マッピングファイル vs ファイル名ベース管理
   - zsh 変数 vs UserDefaults/plist
   - ディレクトリロック vs ContainerLockService

3. **移行機能は意図的に未実装**
   - データ変換ツールは提供しない
   - 自動移行機能も提供しない
   - 両バージョンの同時使用も非推奨

**どちらか一方を選択して使用してください。両立はできません。**

---

## ⚠️ 必須環境

### システム要件

- **macOS Tahoe 26.0 以降** （必須）
  - このアプリは macOS Tahoe で導入された **ASIF ディスクイメージフォーマット** を使用しています
  - macOS Sequoia (25.x) 以前では動作しません
- **アーキテクチャ**: Apple Silicon 専用（Intel Mac 非対応）

### なぜ macOS Tahoe が必要？

このアプリは ASIF (Apple Software Image Format) という新しいディスクイメージフォーマットを使用しています。ASIF は macOS Tahoe 26.0 で導入され、以下の利点があります：

- 📦 より効率的なストレージ管理
- 🔒 強化されたセキュリティ
- ⚡ 高速なマウント・アンマウント
- 🔄 読み書き可能なコンテナ

**バージョン番号について**: Apple は 2025 年から OS のバージョンナンバリングを変更しました。macOS Sequoia は 15 でしたが、macOS Tahoe からは年ベースの「26」（2025-2026 年を表す）に変わりました。これにより、すべての Apple OS のバージョン管理が統一されました。

---

## ✨ 機能

### 🚀 1. IPA インストーラー

IPA ファイルを直接インストールできます：

- 複数の IPA ファイルを一度に選択可能
- インストール前に確認ダイアログ表示
- リアルタイムでインストール進捗を表示
- アプリアイコンと名前を確認しながらインストール
- バージョンアップグレード・ダウングレード対応

**使い方**:
1. ランチャー画面右上の「IPA をインストール」ボタンをクリック
2. IPA ファイルを選択（複数選択可）
3. 確認画面でインストール内容を確認
4. 「インストール」をクリック

### 🎮 2. クイックランチャー

インストール済みアプリを快適に管理・起動：

- グリッド表示でアプリ一覧を視覚的に確認
- アプリアイコンと表示名を表示
- ダブルクリックまたは Enter キーで起動
- 起動中のアプリには「実行中」バッジ表示
- 最近起動したアプリのクイック起動ボタン

**操作方法**:
- **ダブルクリック**: アプリを起動
- **右クリック**: コンテキストメニュー
  - Finder で表示
  - アプリをアンインストール
  - アプリ詳細設定
- **Enter キー**: 最近起動したアプリを起動

### 🔍 3. 検索機能

アプリをすばやく見つける：

- アプリ名で検索
- Bundle ID で検索
- リアルタイム検索結果表示
- 検索結果が 0 件の場合の分かりやすい表示

### 🗑️ 4. アプリアンインストーラー

複数のアプリを一括でアンインストール：

- チェックボックスで複数選択
- アプリサイズとディスクイメージサイズを表示
- 確認ダイアログで削除内容を確認
- アンインストール進捗をリアルタイム表示
- 完了・失敗したアプリを個別に表示

**使い方**:
1. ランチャー画面右上の「アンインストーラー」ボタンをクリック
2. アンインストールしたいアプリをチェック
3. 「アンインストール (X 個)」ボタンをクリック
4. 確認ダイアログで内容を確認
5. 「アンインストール」をクリック

### 💾 5. ストレージ管理

ASIF ディスクイメージの保存先を柔軟に管理：

- 現在の保存先とディスク使用量を表示
- 外部ドライブへの保存先変更
- 保存先変更時の自動再マウント
- 容量の大きい外部ストレージを推奨（必須ではない）
- Finder に表示しない設定（nobrowse オプション）

**設定画面**:
- 「データ」タブ: 保存先の設定
- 「メンテナンス」タブ: アンマウント・キャッシュクリア

### 🛠️ 6. メンテナンス機能

システムを快適に保つ：

- **アンマウント機能**
  - すべてのディスクイメージを安全にアンマウント
  - 外部ドライブの場合、ドライブごと安全に取り外せる状態にする
  - アンマウント完了後にアプリを終了するオプション
- **アイコンキャッシュクリア**
  - アプリアイコンのキャッシュをクリア
  - アイコン表示の不具合を解消
- **設定リセット**
  - すべての設定を初期値に戻す
  - ディスクイメージとアプリは削除されない

### ⚙️ 7. アプリ個別設定

各アプリごとに詳細な設定が可能：

- **基本設定**: 起動時の内部データ処理方法
- **グラフィックス設定**: 解像度、アスペクト比、ウィンドウ修正方法
- **コントロール設定**: マウス感度、画面タッチのキーマッピング
- **詳細設定**: iOS デバイスモデル、PlayCover 実行時パッチ、jailbreak 検出回避
- **情報**: アプリ情報、設定ファイルの場所

---

## 📦 インストール

### 方法1: GitHub Releases（推奨）

1. [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases) から最新の `PlayCoverManager.dmg` をダウンロード
2. DMG をマウント
3. PlayCoverManager.app を「アプリケーション」フォルダにドラッグ
4. 初回起動時は **右クリック → 「開く」** を選択（署名なしアプリのため）

### 方法2: ソースからビルド

**必要な環境**:
- macOS Sequoia 15.6 以降
- Xcode 26.0 以降

```bash
# リポジトリをクローン
git clone https://github.com/HEHEX8/PlayCoverManagerGUI.git
cd PlayCoverManagerGUI

# Xcode でプロジェクトを開く
open PlayCoverManager.xcodeproj

# または、コマンドラインでビルド
xcodebuild -scheme PlayCoverManager -configuration Release archive
```

---

## 🎮 使い方

### 初回起動

1. PlayCover Manager を起動
2. macOS バージョンチェックが実行されます
   - macOS Tahoe 26.0 未満の場合、エラーメッセージが表示されます
3. セットアップウィザードが表示されます（初回のみ）
4. PlayCover.app の場所を選択
   - デフォルト: `/Applications/PlayCover.app`
5. ASIF ディスクイメージの保存先を選択
   - 内蔵ストレージまたは外部ドライブを選択可能
6. 完了！ランチャー画面が表示されます

### IPA のインストール

1. 右上の「IPA をインストール」ボタンをクリック
2. IPA ファイルを選択（複数選択可能）
3. 解析完了後、インストール確認画面が表示されます
4. 「インストール」をクリック
5. インストール完了後、ランチャーに追加されます

### アプリの起動

- **方法1**: グリッド内のアプリアイコンをダブルクリック
- **方法2**: 検索バーでアプリを検索してダブルクリック
- **方法3**: 最近起動したアプリが表示されている場合、Enter キーを押す

### アプリのアンインストール

**個別アンインストール**:
1. アプリを右クリック
2. 「アプリをアンインストール」を選択
3. 確認ダイアログで「アンインストール」をクリック

**一括アンインストール**:
1. 右上の「アンインストーラー」ボタンをクリック
2. アンインストールしたいアプリにチェック
3. 「アンインストール (X 個)」をクリック
4. 確認後、実行

### ストレージ管理

1. 右上の歯車アイコンで設定画面を開く
2. 「データ」タブを選択
3. 現在の保存先とディスク使用量を確認
4. 保存先を変更する場合:
   - 「保存先を変更」ボタンをクリック
   - 新しい保存先を選択
   - 自動的に再マウントされます

---

## 🛠️ 開発

### プロジェクト構造

```
PlayCoverManagerGUI/
├── PlayCoverManager/              # メインアプリコード
│   ├── Views/                     # SwiftUI Views
│   │   ├── AppRootView.swift         # ルートビュー（フェーズ管理）
│   │   ├── QuickLauncherView.swift   # ランチャー画面
│   │   ├── SettingsRootView.swift    # 設定画面（IPA インストーラー・アンインストーラー含む）
│   │   ├── SetupWizardView.swift     # セットアップウィザード
│   │   └── UnmountOverlayView.swift  # アンマウントオーバーレイ
│   ├── ViewModels/                # ViewModels
│   │   ├── AppViewModel.swift        # アプリ全体の状態管理
│   │   ├── LauncherViewModel.swift   # ランチャーロジック
│   │   └── SetupWizardViewModel.swift # セットアップロジック
│   ├── Services/                  # ビジネスロジック
│   │   ├── DiskImageService.swift    # ASIF ディスクイメージ管理
│   │   ├── IPAInstallerService.swift # IPA インストーラー
│   │   ├── AppUninstallerService.swift # アンインストーラー
│   │   ├── LauncherService.swift     # アプリ起動管理
│   │   ├── PlayCoverEnvironmentService.swift # PlayCover 環境検出
│   │   ├── ContainerLockService.swift # コンテナロック管理
│   │   └── ProcessRunner.swift       # プロセス実行ユーティリティ
│   ├── Models/                    # データモデル
│   │   ├── AppError.swift           # エラー定義
│   │   ├── AppPhase.swift           # アプリフェーズ定義
│   │   ├── PlayCoverPaths.swift     # パス管理
│   │   └── PlayCoverAppSettings.swift # アプリ設定
│   ├── Utilities/                 # ユーティリティ
│   │   └── AppIconHelper.swift      # アイコン読み込み
│   └── Assets.xcassets/           # アセット
└── README.md                      # このファイル
```

### 技術スタック

- **言語**: Swift 6.0+
- **フレームワーク**: SwiftUI
- **最小ターゲット**: macOS 26.0 Tahoe
- **開発環境**: Xcode 26.0+ (macOS Sequoia 15.6+ が必要)
- **アーキテクチャ**: MVVM + Service Layer + Phase-based State Management
- **ディスクイメージ**: ASIF (Apple Software Image Format)

### 主要な技術的特徴

1. **ASIF ディスクイメージ**
   - `diskutil` コマンドで ASIF フォーマットのディスクイメージを作成
   - 読み書き可能なコンテナとしてマウント
   - アプリごとに個別のディスクイメージを管理

2. **フェーズベース状態管理**
   - インストーラー・アンインストーラーで enum によるフェーズ管理
   - boolean フラグの乱立を避け、状態遷移を明確化

3. **非同期処理**
   - Swift Concurrency (async/await) を全面採用
   - MainActor で UI 更新を安全に管理

4. **アイコンキャッシュ**
   - NSCache を使用した高解像度アイコンのキャッシュ
   - 512x512 解像度で鮮明な表示

---

## 📤 配布

このプロジェクトは **署名なし** で配布されています（個人プロジェクトのため）。

### 初回起動時の注意

macOS Gatekeeper により、初回起動時に警告が表示されます：

1. アプリを右クリック
2. 「開く」を選択
3. 「開く」をもう一度クリック

これにより、以降は通常通り起動できます。

---

## 📄 ライセンス

このプロジェクトは [MIT License](LICENSE) の下でライセンスされています。

---

## 🙏 謝辞

- [PlayCover](https://github.com/PlayCover/PlayCover) - iOS アプリを macOS で実行可能にする素晴らしいプロジェクト
- Apple の ASIF ディスクイメージフォーマット
- SF Symbols - macOS 標準アイコンセット

---

## 🔗 リンク

- [GitHub リポジトリ](https://github.com/HEHEX8/PlayCoverManagerGUI)
- [Issues](https://github.com/HEHEX8/PlayCoverManagerGUI/issues)
- [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases)
- [PlayCover 公式](https://github.com/PlayCover/PlayCover)

---

## ❓ FAQ

### Q: なぜ macOS 15 Sequoia の次が macOS 26 Tahoe なの？

**A:** Apple が 2025 年からバージョンナンバリングルールを変更したためです。従来の連番（15, 16, 17...）から、年ベースのナンバリング（26 = 2025-2026年）に変わりました。これにより iOS、iPadOS、macOS などすべての OS のバージョン管理が統一されました。

### Q: macOS Sequoia (15.x) で動作しますか？

**A:** いいえ。このアプリは macOS Tahoe 26.0 以降が必須です。ASIF ディスクイメージフォーマットは macOS Tahoe で導入されました。

### Q: PlayCover は別途インストールが必要ですか？

**A:** はい。PlayCover Manager は PlayCover の補助ツールです。PlayCover 本体は別途インストールしてください。

### Q: IPA ファイルはどこから入手できますか？

**A:** IPA ファイルの入手方法については、PlayCover の公式ドキュメントを参照してください。

### Q: アプリが起動しない場合は？

**A:** 以下を確認してください：
- macOS Tahoe 26.0 以降であるか
- PlayCover が正しくインストールされているか
- ディスクイメージがマウントされているか
- 設定画面の「メンテナンス」タブからアンマウントを実行してみる

### Q: 外部ドライブに保存先を変更するメリットは？

**A:** 内蔵ストレージの容量を節約できます。大容量のゲームなどをインストールする場合に推奨します。ただし、外部ドライブが接続されていないとアプリが起動できません。

### Q: ディスクイメージが Finder に表示されるのを防ぐには？

**A:** 設定画面の「データ」タブで「マウント時に Finder に表示しない (-nobrowse)」を有効にしてください。

---

## 🐛 問題報告

バグや機能リクエストは [GitHub Issues](https://github.com/HEHEX8/PlayCoverManagerGUI/issues) で報告してください。

報告時には以下の情報を含めてください：
- macOS バージョン
- PlayCover Manager バージョン
- 問題の詳細と再現手順
- スクリーンショット（可能な場合）

---

<div align="center">

Made with ❤️ for PlayCover users on macOS Tahoe

[⬆ トップに戻る](#playcover-manager)

</div>
