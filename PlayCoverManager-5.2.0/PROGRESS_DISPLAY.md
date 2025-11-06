# データ転送の進捗表示

## 概要

ストレージ移行時のデータ転送で、rsyncの進捗表示機能を活用しています。
- **同一ファイルは自動スキップ**: 既に転送済みのファイルは再転送しません
- **%で進捗表示**: 全体の進捗が一目でわかります
- **Homebrew版rsyncを優先**: 最新機能を活用

## 表示例

### 初回転送（全ファイル転送）

```
📊 転送情報:
  ファイル数: 1,523
  データサイズ: 25.7GB

🚀 使用ツール: rsync (Homebrew版)
  rsync version 3.2.7 protocol version 31
💡 同期モード: 同一ファイルはスキップ、余分なファイルは削除

データ転送中...

          0   0%    0.00kB/s    0:00:00
    256,000   1%    2.45MB/s    0:01:42
    512,000   2%    2.89MB/s    0:01:28
  1,024,000   4%    3.21MB/s    0:01:15
  2,048,000   8%    3.45MB/s    0:01:05
  ...
 25,700,000  99%    3.67MB/s    0:00:02
 25,769,000 100%    3.68MB/s    0:01:56

✅ データの転送が完了しました
  転送完了: 1,523 ファイル (25.7GB)
  💡 同一ファイルは自動スキップされました
```

### 2回目以降の転送（大部分がスキップ）

```
📊 転送情報:
  ファイル数: 1,523
  データサイズ: 25.7GB

🚀 使用ツール: rsync (Homebrew版)
  rsync version 3.2.7 protocol version 31
💡 同期モード: 同一ファイルはスキップ、余分なファイルは削除

データ転送中...

     25,000   0%   15.23MB/s    0:00:02  (skipping identical files)
     50,000   0%   18.45MB/s    0:00:01  (skipping identical files)
    125,000   0%   22.67MB/s    0:00:00  (3 files updated)

✅ データの転送が完了しました
  転送完了: 1,523 ファイル (25.7GB)
  💡 同一ファイルは自動スキップされました
```

## rsyncの進捗表示機能

### GNU rsync / Homebrew版（推奨）

`--info=progress2`オプションにより、以下の情報がリアルタイムで表示されます：

- **転送済みバイト数**: 現在までに転送されたデータ量
- **進捗率（%）**: 全体の何%が完了したか
- **転送速度**: 現在の転送速度（MB/s）
- **残り時間**: 推定完了時刻までの時間

### openrsync（macOS Sequoia以降のシステム版）

⚠️ **制限事項**: openrsyncは`--info=progress2`をサポートしていません。

代わりに`--progress`オプション（古いスタイル）を使用します：
- ファイルごとの進捗表示
- %表示なし、転送速度・残り時間の表示なし
- より詳細度が低い

**推奨**: Homebrew版rsyncをインストールすることで、より快適な進捗表示が利用可能です。

### 同一ファイルの自動スキップ

rsyncは転送前にファイルを比較し、以下の場合にスキップします：
- ファイルサイズが同じ
- 更新日時が同じ
- チェックサム（オプション）が同じ

これにより、2回目以降の転送は大幅に高速化されます。

### 同期モードの`--delete`オプション

外部→内蔵の同期移行時、`--delete`オプションにより転送元に存在しないファイルを削除します：
- 内蔵ストレージに余分なファイルが残らない
- ストレージ容量の無駄を防ぐ
- 常に最新の状態を保つ

## 技術詳細

### 実装箇所
- ファイル: `lib/03_storage.sh`
- 関数: `_perform_cp_transfer()` （名前はcpだがrsyncを使用）
- 行数: 約440-520行

### 使用コマンド
```bash
# Homebrew版rsyncを優先使用
local rsync_cmd=""
local rsync_type=""

if [[ -x "/opt/homebrew/bin/rsync" ]]; then
    rsync_cmd="/opt/homebrew/bin/rsync"
    rsync_type="homebrew"
elif [[ -x "/usr/bin/rsync" ]]; then
    rsync_cmd="/usr/bin/rsync"
    # rsyncのタイプを判定（GNU rsync or openrsync）
    local version_output=$("$rsync_cmd" --version | head -n 1)
    if [[ "$version_output" == *"openrsync"* ]]; then
        rsync_type="openrsync"
    else
        rsync_type="gnu"
    fi
fi

# rsyncオプション設定
rsync_opts="-av"

# 同期モードなら--deleteも追加
if [[ "$sync_mode" == "sync" ]]; then
    rsync_opts="${rsync_opts} --delete"
fi

# 進捗表示オプション（rsyncのタイプに応じて選択）
if [[ "$rsync_type" == "openrsync" ]]; then
    # openrsyncの場合: --progressのみ使用（古いスタイル）
    rsync_opts="${rsync_opts} --progress"
else
    # GNU rsync / Homebrew版の場合: --info=progress2使用（%表示）
    rsync_opts="${rsync_opts} --info=progress2"
fi

# 実行
sudo "$rsync_cmd" $rsync_opts "$source/" "$dest/"
```

### Homebrew版rsyncの自動インストール（必須）

セットアップウィザードで自動的にチェック・インストールされます：

1. **チェック機能** (`lib/06_setup.sh` - 行235-310付近)
   - Homebrew版rsyncの存在確認
   - システム版rsyncの存在確認とタイプ判定（GNU or openrsync）
   - openrsync検出時に制限事項をエラー表示
   - バージョン情報の表示

2. **インストール機能** (行312-327付近)
   - `brew install rsync`で最新版をインストール
   - インストール成功時にバージョン表示

3. **セットアップフロー統合** (行689-698付近)
   - Step 5として自動的に実行
   - openrsync検出時はインストールを**必須**として要求
   - インストールを断るとセットアップ中断
   - GNU rsync検出時は推奨レベル（動作はする）

### macOS Sequoia以降の重要な変更

macOS Sequoia（2025年）以降、AppleはGNU rsyncからopenrsyncに変更しました：
- **理由**: GPLv3ライセンスの回避
- **影響**: 一部の高度な機能が使用不可
- **対応**: Homebrew版rsync（GNU rsync）のインストールが**必須**

#### openrsync環境での動作

- openrsync検出時、セットアップウィザードで以下のメッセージが表示されます：
  ```
  ❌ openrsync は機能が不十分です
  ✅ Homebrew版 rsync が必要です
  Homebrew版 rsync をインストールしますか？（必須） (Y/n):
  ```
- インストールを断ると、セットアップが中断されます
- このツールはHomebrew版rsyncなしでは動作しません

## 利点

1. **効率性**: 同一ファイルを自動スキップ、転送時間を大幅短縮
2. **進捗の可視化**: %表示、転送速度、残り時間が一目瞭然
3. **安心感**: リアルタイムで処理状況がわかる
4. **問題検知**: 転送速度の低下やエラーをすぐに発見
5. **同期機能**: `--delete`オプションで完全同期を実現
6. **最新機能**: Homebrew版で最新のrsync機能を利用可能

## 注意事項

- 表示はデータサイズベース（rsyncの`--info=progress2`）
- 初回転送は全ファイル転送のため時間がかかる
- 2回目以降は変更ファイルのみ転送で高速化
- Homebrew版rsyncは自動インストールされるが、手動でも`brew install rsync`可能
