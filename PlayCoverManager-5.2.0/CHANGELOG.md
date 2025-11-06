# Changelog

All notable changes to PlayCover Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Standalone版アプリビルダー**: Terminal.appに依存しない独立したmacOSアプリケーションを作成
  - 新しいビルドスクリプト: `build-app-standalone.sh`
  - Activity Monitorで "PlayCover Manager" として表示（Terminalではない）
  - Dockで PlayCover Manager アイコンとして表示
  - `exec -a` によるプロセス名の明示的な設定
  - 外部ツール不要（Platypus不要）
  - 配布用に最適化された.appバンドル構造
  - **シングルインスタンス機能**: 複数起動を防止
    - PIDベースのロックファイル管理
    - ゾンビロック自動検出と削除
    - `trap EXIT INT TERM QUIT` による確実なクリーンアップ
    - 既存インスタンスの自動アクティベート
  - **アイコンサポート**: macOS標準の`.icns`形式アイコンに対応
    - `CFBundleIconFile` を Info.plist に追加
    - `.icns` ファイル優先、`.png` フォールバック
    - アイコン未生成時の警告メッセージ
  - 詳細ドキュメント: `STANDALONE_BUILD.md`

- **Standalone版DMGビルダー**: appdmgを使用したDMGインストーラー作成
  - 新しいビルドスクリプト: `create-dmg-standalone.sh`
  - appdmg設定ファイル: `appdmg-config-standalone.json`
  - build-standalone/ ディレクトリからの自動ビルド
  - Terminal版と同じ実績あるappdmgソリューションを使用

### Documentation
- **ICON_GUIDE.md**: アイコン作成の完全ガイドを追加
  - `create-icon.sh` の使用方法
  - `.icns` ファイル生成手順
  - トラブルシューティング
  - Finder キャッシュのクリア方法
- **STANDALONE_BUILD.md**: Standalone版ビルドの完全ガイドを追加
  - ビルド方法、テスト手順、配布方法
  - トラブルシューティングガイド
  - Terminal版との比較表
- **README.md**: Standalone版ビルドの説明を追加
  - インストール方法3にStandalone版とTerminal版の比較表を追加
  - ビルド方式の違いを明記
  - アイコン生成手順を追記（`./create-icon.sh` を最初に実行）

## [5.2.0] - 2025-01-31

### Added
- **システムメンテナンスメニュー**: ストレージ容量問題を解決する新機能
  - メインメニューに`[6] システムメンテナンス`を追加
  - **APFSスナップショットの確認・削除**: Time Machineのローカルスナップショットを削除して容量を回復
  - **システムキャッシュのクリア**: ユーザーキャッシュ、一時ファイル、ダウンロード済みアップデートを削除
  - **ストレージ使用状況の確認**: システムボリュームと外部ボリュームの容量を表示
  - 新しい関数: `check_apfs_snapshots()`, `cleanup_apfs_snapshots()`, `system_maintenance_menu()`, `clear_system_caches()`, `show_storage_usage()`

### Fixed
- **プログレスバー表示の修正**: rsync転送中にリアルタイムでプログレスバーが表示されるように修正
  - `monitor_file_progress()`関数の出力を`stderr`にリダイレクト
  - プログレスバーが戻り値で上書きされる問題を解決
  - `[████████░░] 80% | 4758/5948 files | 52 files/s`形式で表示

- **メッセージクリーンアップ**: 実際の処理を伴わない不要なメッセージを削除
  - `lib/03_storage.sh`の3箇所で「クリーンアップ中...」メッセージを削除
  - ユーザーに視覚的フィードバックが明確になるように改善

### Changed
- **容量表示の説明を改善**: 内部→外部ストレージ移行完了時のメッセージを改善
  - APFSスナップショットによる容量圧迫の説明を追加
  - システムメンテナンスメニューへの誘導を追加
  - 2つの原因（APFS仕様、Time Machineスナップショット）を明記

- **バージョン表記を更新**: 5.1.0 → 5.2.0
  - `lib/07_ui.sh`, `main.sh`, `build-app.sh`でバージョンを統一

### Technical
- **内部ストレージへの意図しないデータ蓄積の検証**: スクリプトが意図せず内部ストレージにデータを書き込んでいないことを確認
  - `_perform_data_transfer()`の呼び出しは全て明示的で制御されている
  - 一時ファイルは全て`/tmp/`ディレクトリを使用
  - `mount_app_volume()`はマウントポイントを作成するだけでデータは書き込まない

- **コード品質向上**: 未使用関数の検出、重複処理の分析、関数の共通化を実施
  - 全ての関数が実際に使用されていることを確認
  - 重複パターンを分析（116箇所のエラーハンドリング、153箇所の`return 1`）
  - 必要なバリデーションとエラーハンドリングを維持

### Stats
- Files changed: 5
- Insertions: 313
- Deletions: 15

### Changed
- **Performance Optimization Phase 4**: Smart volume state caching
  - Implemented intelligent caching system for volume state queries
  - Global cache (`VOLUME_STATE_CACHE`) stores: existence, device, mount point, timestamp
  - Selective invalidation: Only refresh volumes that are actually modified
  - Display operations use cached data for instant response
  - Cache management functions:
    - `get_volume_info_cached()`: Cached volume information retrieval
    - `validate_and_get_device_cached()`: Cached device lookup
    - `validate_and_get_mount_point_cached()`: Cached mount point lookup
    - `invalidate_volume_cache()`: Selective cache clearing
    - `get_cache_stats()`: Debugging and monitoring
  - Automatic cache invalidation after:
    - Mount/unmount operations
    - Volume creation/deletion
    - Batch mount/unmount operations
  - **Performance Impact**: 
    - Menu display: Near-instant (no diskutil calls for unchanged volumes)
    - Typical workflow: ~70% reduction in diskutil calls
    - Navigation: Smooth experience without lag
  - **User Experience**: Instantly responsive menus and status displays
  - Stats: +206 insertions, -31 deletions

- **Performance Optimization Phase 3**: Reduced redundant volume operations
  - Added 3 new helper functions in `lib/00_core.sh`:
    - `get_volume_info()`: Retrieve device + mount point in a single diskutil call
    - `validate_and_get_device()`: Combined existence check + device retrieval
    - `validate_and_get_mount_point()`: Combined existence check + mount retrieval
  - Optimized volume operations across all modules:
    - `lib/02_volume.sh`: Replaced 4 instances of separate checks with unified functions
    - `lib/03_storage.sh`: Eliminated duplicate device queries in migration functions
    - `lib/04_app.sh`: Cached mount point queries to avoid repeated system calls
    - `lib/05_cleanup.sh`, `lib/06_setup.sh`: Unified validation patterns
  - **Performance Impact**: Reduced diskutil system calls by ~40% in common workflows
  - **Consistency**: Uniform error handling across all volume operations
  - Stats: +181 insertions, -92 deletions

## [5.1.0] - 2025-01-29

### Added
- **クイックランチャー**: アプリを素早く起動できる新機能
  - 起動時に自動表示（アプリが1個以上ある場合）
  - シンプルなアイコン表示（ストレージ、sudo、最近起動）
  - Enterキーで最近起動したアプリを再起動
  - 未マウント時の自動マウント機能

### Fixed
- **PlayCoverボリュームの自動マウント**: 起動時にPlayCoverが未マウントでもクイックランチャーに入れるように
- **内蔵データ検出の表示統一**: 「汚染」→「内蔵データ検出」に表記を統一
- **バッチマウントの入力待ち**: 内蔵データ検出時に選択肢が自動スキップされる問題を修正
- **内蔵データ検出アプリの除外**: クイックランチャーに起動不可能なアプリを表示しない
- **recent_flag表示問題**: マッピングファイルの4列目が表示に混入する問題を修正
- **表示アライメント**: 複数アイコン＋2桁番号でも崩れない固定幅フォーマット
- **終了時の動作**: `0`選択時にターミナルウィンドウを即座に閉じるように

### Changed
- **UI簡素化**: クイックランチャーの表示を「起動専用」に特化してシンプル化
- **アイコン配置**: ストレージ(2)→sudo(2)→recent(3)→番号(2桁)の固定幅レイアウト

## [5.0.0] - 2025-01-29

### Fixed

#### ストレージ種別表示の完全統一（Critical Bug Fix）
- **問題**: メインメニュー、アプリ管理、ボリューム情報、ストレージ切替で表示が食い違う重大なバグ
- **症状**: 
  - ボリューム情報: 正しく「マウント済」と表示
  - アプリ管理: 誤って「内部」と表示
  - ストレージ切替: 誤って「データ無し」または「マウント位置異常」と表示
- **根本原因**: 
  - ボリューム情報は `get_mount_point()` で実際のマウント状況を確認
  - アプリ管理とストレージ切替は `get_storage_type()` でパスをチェック
  - `get_storage_type()` の `/sbin/mount` grep パターンが正しく動作しない環境があった
- **修正内容**: 
  - 全ての表示ロジックを `get_mount_point()` ベースに統一
  - 実際のマウント状況を直接確認する方式に変更
  - ボリューム情報と同じ判定ロジックを全画面で使用
- **影響範囲**: 
  - `lib/07_ui.sh`: 統計情報、アプリ一覧の判定ロジック（2箇所）
  - `lib/03_storage.sh`: ストレージ切替メニューの判定ロジック、パス正規化
- **結果**: 全ての画面で一貫したストレージ種別表示を実現

#### 初期セットアップのUX改善
- **問題**: Enter押下が多すぎる（8回必要）、無効な入力でスクリプトが終了
- **修正内容**:
  - 不要な Enter 待機を削除（情報表示後は自動継続）
  - ディスク選択で無効な入力時に再試行ループを実装
  - より詳細なエラーメッセージを表示（「1〜N の数字を入力してください」）
- **影響範囲**: `lib/06_setup.sh`
- **結果**: スムーズで直感的なセットアップ体験

### Technical Details

#### 判定ロジックの統一（全画面共通）
```bash
# 統一後のロジック
local actual_mount=$(get_mount_point "$volume_name")
if [[ -n "$actual_mount" ]] && [[ "$actual_mount" == "$target_path" ]]; then
    # 正しい位置にマウント = 外部ストレージ
    status="🔌 外部"
elif [[ -n "$actual_mount" ]]; then
    # 間違った位置にマウント
    status="⚠️  位置異常"
else
    # 未マウント = 内部ストレージをチェック
    storage_mode=$(get_storage_mode "$target_path" "$volume_name")
    # ...
fi
```

#### 修正コミット
- `5c0faaf`: 初期セットアップのUX改善とストレージ種別表示の統一（第1弾）
- `f5482c1`: ストレージ種別表示ロジックをボリューム情報と統一（第2弾）
- `2776123`: ストレージ切替の表示ロジックをボリューム情報と完全統一（第3弾）

#### 修正ファイル
- `lib/03_storage.sh`: ストレージ切替メニューの完全書き換え、パス正規化
- `lib/06_setup.sh`: 初期セットアップフロー、再試行ロジック
- `lib/07_ui.sh`: メインメニュー統計情報、アプリ管理一覧

### Upgrade Notes

alpha2 からの変更点:
- バグ修正のみでAPIや設定の変更なし
- 既存のマッピングファイルやボリュームはそのまま使用可能
- アップグレード後も通常通り動作

## [5.0.1] - 2025-01-29

### Added
- 初回リリース候補版
- モジュラーアーキテクチャへの完全リファクタリング完了

## [5.0.0] - 2025-01-28

### 🎉 初回正式リリース

**なぜ 5.0.0 から始まるのか？**

このプロジェクトは、以前の個人用スクリプト（バージョン管理なし）を完全に作り直したものです：

1. **v1.x-v4.x 相当の開発期間**
   - 初期プロトタイプ：単一の巨大なBashスクリプト
   - 機能追加と問題修正を繰り返し
   - コードが複雑化し保守困難に

2. **v5.0.0 での完全リビルド**
   - ゼロからの設計見直し
   - Bash → Zsh への移行
   - モノリシック → 8モジュール構成へ分割
   - 完全な日本語UI実装
   - 包括的なエラーハンドリング
   - DMGインストーラー対応

初回の正式リリースとして、大規模な再設計を反映し **5.0.0** としました。

---

### Added
- ✨ **モジュール化されたアーキテクチャ**
  - 8つの独立したモジュール（core, mapping, volume, storage, app, cleanup, setup, ui）
  - 保守性と拡張性の向上
  
- 🇯🇵 **完全な日本語UI**
  - すべてのメッセージとメニューを日本語化
  - 視認性を考慮したカラースキーム
  
- 📦 **DMGインストーラー対応**
  - appdmgによる美しいインストーラー
  - ドラッグ&ドロップで簡単インストール
  
- 💾 **外部ストレージ管理機能**
  - APFS ボリュームの自動作成とマウント
  - 複数アプリの個別ボリューム管理
  - マウント状態の可視化
  
- 🔄 **ストレージ切替機能（内蔵⇄外部）**
  - ワンクリックでデータ位置を切り替え
  - rsyncによる安全なデータ同期
  - フラグファイルでモード管理
  
- 📊 **バッチ操作**
  - 全ボリュームの一括マウント/アンマウント
  - 実行中アプリの自動検出とロック
  
- 🧹 **クリーンアップ機能**
  - 超強力クリーンアップモード（隠しオプション）
  - 段階的な削除確認
  - 復元不可能な完全削除

### Changed
- 🐚 **Bash から Zsh に移行**
  - macOS標準シェルへの対応
  - 配列処理とパラメータ展開の改善
  
- 🏗️ **モノリシックから8モジュール構成に分割**
  - 単一ファイル（2000+ 行）から分離
  - 責任分離の原則に基づいた設計
  - 各モジュールの独立性確保
  
- 🎨 **カラースキーム最適化**
  - ターミナル背景 RGB(28,28,28) / #1C1C1C 対応
  - 人間の色覚特性を考慮した配色
  - 眩しさ軽減と視認性向上の両立

### Technical
- 🍎 **Apple Silicon 専用**
  - arm64 アーキテクチャ最適化
  - M1/M2/M3/M4 Mac 対応
  
- 🖥️ **macOS Sequoia 15.1+ 対応**
  - 最新のAPFS機能を活用
  - システム権限管理の改善
  
- 💿 **APFS ボリューム管理**
  - ボリューム作成、マウント、アンマウント
  - マウントポイント検出とパス管理
  - デバイスノード解決
  
- 🎮 **PlayCover 3.0+ 対応**
  - コンテナ構造の理解
  - アプリ実行状態の検出
  - バンドルID管理

### Architecture

#### モジュール構成
```
lib/
├── 00_core.sh      # 定数、色定義、基本ユーティリティ
├── 01_mapping.sh   # ボリュームマッピング管理
├── 02_volume.sh    # APFS ボリューム操作
├── 03_storage.sh   # ストレージ切替ロジック
├── 04_app.sh       # アプリインストール/アンインストール
├── 05_cleanup.sh   # クリーンアップ機能
├── 06_setup.sh     # 初期セットアップ
└── 07_ui.sh        # UI表示とメインメニュー
```

#### 設計原則
- **単一責任**: 各モジュールは1つの責任のみを持つ
- **疎結合**: モジュール間の依存を最小化
- **高凝集**: 関連する機能を同じモジュールに集約
- **エラーハンドリング**: 包括的なエラー処理とユーザーフィードバック
