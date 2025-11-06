# PlayCoverManager 無料配布ガイド（署名なし）

個人製作アプリを **完全無料** で配布する方法です。
Apple Developer Program（$99/年）は不要！

## 🎯 配布方法

### GitHub Releasesで配布（推奨）

1. **ビルド**
   ```bash
   ./scripts/build_dev.sh
   ```

2. **DMGを作成**
   ```bash
   # アプリのパス
   APP_PATH="build/dev/Build/Products/Debug/PlayCoverManager.app"
   
   # DMG作成
   hdiutil create -volname "PlayCoverManager" \
       -srcfolder "$APP_PATH" \
       -ov -format UDZO "PlayCoverManager.dmg"
   ```

3. **GitHub Releasesにアップロード**
   - https://github.com/HEHEX8/PlayCoverManagerGUI/releases
   - DMGファイルをアップロード

### ユーザー向けインストール手順

リリースページに以下を記載：

```markdown
## 📦 インストール方法

### ダウンロード
[PlayCoverManager.dmg](リンク)

### インストール
1. DMGをダウンロード
2. DMGを開く
3. PlayCoverManagerを「アプリケーション」フォルダにドラッグ

### 初回起動（Gatekeeperの回避）

macOSが「開発元を確認できません」と警告を出します。
以下の方法で起動してください：

#### 方法A: 右クリックで開く（推奨）
1. アプリを **右クリック**（または Ctrl + クリック）
2. 「開く」を選択
3. 警告ダイアログで「開く」をクリック

これで今後は普通にダブルクリックで起動できます。

#### 方法B: コマンドで開く
```bash
open /Applications/PlayCoverManager.app
```

#### 方法C: quarantine属性を削除（上級者向け）
```bash
xattr -cr /Applications/PlayCoverManager.app
```
```

---

## 🍺 Homebrew Cask対応（もっと簡単！）

Homebrew Caskを作れば、ユーザーは：
```bash
brew install --cask playcovermanager
```
だけでインストール＆起動できる！

### Homebrew Caskの作り方

1. **Formulaを作成**
   
   自分のリポジトリに `Casks/playcovermanager.rb` を作成：

   ```ruby
   cask "playcovermanager" do
     version "1.0.0"
     sha256 "dmgファイルのSHA256ハッシュ"
     
     url "https://github.com/HEHEX8/PlayCoverManagerGUI/releases/download/v#{version}/PlayCoverManager.dmg"
     name "PlayCover Manager"
     desc "GUI launcher and manager for PlayCover iOS apps"
     homepage "https://github.com/HEHEX8/PlayCoverManagerGUI"
     
     depends_on macos: ">= :big_sur"
     
     app "PlayCoverManager.app"
     
     # quarantine属性を自動削除
     postflight do
       system_command "/usr/bin/xattr",
                      args: ["-cr", "#{appdir}/PlayCoverManager.app"]
     end
   end
   ```

2. **Tap作成（自分専用リポジトリ）**
   
   ```bash
   # 新規リポジトリ作成: homebrew-playcovermanager
   # または既存リポジトリに Casks/ ディレクトリを追加
   ```

3. **ユーザーの使い方**
   
   ```bash
   # Tap追加
   brew tap HEHEX8/playcovermanager
   
   # インストール（自動でquarantine削除！）
   brew install --cask playcovermanager
   ```

### SHA256ハッシュの取得
```bash
shasum -a 256 PlayCoverManager.dmg
```

---

## 📝 リリースノートテンプレート（署名なし版）

```markdown
## PlayCoverManager v1.0.0

### ✨ 新機能
- iOSアプリの快適な起動・管理
- 検索機能
- PlayCover連携

### 📦 ダウンロード
[PlayCoverManager.dmg](リンク) (XX.X MB)

### 💻 動作環境
- macOS 11.0 Big Sur以降
- Apple Silicon / Intel両対応
- PlayCover必須

---

### ⚠️ 重要: 初回起動について

このアプリは **署名されていません**（個人製作のため）。
初回起動時にmacOSが警告を出しますが、以下の方法で安全に起動できます：

#### 簡単な起動方法（30秒）

1. DMGをダウンロード・マウント
2. PlayCoverManagerを「アプリケーション」フォルダにドラッグ
3. アプリを **右クリック** → 「開く」を選択
4. 「開く」をクリック

✅ これで今後は普通にダブルクリックで起動できます！

#### コマンドで起動
ターミナルから：
```bash
xattr -cr /Applications/PlayCoverManager.app
open /Applications/PlayCoverManager.app
```

---

### 🍺 Homebrew対応（推奨）

面倒な手順をスキップ！

```bash
brew tap HEHEX8/playcovermanager
brew install --cask playcovermanager
```

これだけで自動インストール＆起動可能に！

---

### 🔐 セキュリティについて

- ✅ ソースコードは完全公開
- ✅ GitHubで透明性を確保
- ✅ ビルドプロセスも公開

疑う方はソースからビルドしてください：
```bash
git clone https://github.com/HEHEX8/PlayCoverManagerGUI.git
cd PlayCoverManagerGUI
./scripts/build_dev.sh
```

---

### ❓ FAQ

**Q: なぜ署名されていないの？**
A: Apple Developer Program（年間$99）が必要なため。個人製作の無料アプリなので署名していません。

**Q: 安全なの？**
A: ソースコードは全て公開されています。不安な方は自分でビルドしてください。

**Q: 毎回右クリックで開かないとダメ？**
A: 初回だけです。一度「開く」で起動すれば、次回から普通にダブルクリックで起動できます。

**Q: Gatekeeperを無効化する必要は？**
A: 必要ありません。右クリック→開くだけでOKです。
```

---

## 🤝 他の無署名アプリの例

署名なしで配布されている有名アプリ：
- 個人開発のユーティリティツール多数
- オープンソースプロジェクト
- 大学・研究機関のツール

みんな「右クリック→開く」で起動してもらってる！

---

## 📊 まとめ: 無料配布の選択肢

| 方法 | 難易度 | ユーザー体験 | コスト |
|------|--------|--------------|--------|
| GitHub Releases | ⭐ 簡単 | 右クリック→開く | 無料 |
| Homebrew Cask | ⭐⭐ 普通 | 自動で起動可能 | 無料 |
| 署名＋公証 | ⭐⭐⭐ 面倒 | 完璧（警告なし） | $99/年 |

**個人製作なら GitHub Releases + Homebrew Cask で十分！** 🎉

---

## 🚀 次のステップ

1. ビルドスクリプト実行
2. DMG作成
3. GitHub Releasesにアップロード
4. （オプション）Homebrew Cask作成

全部無料でできる！
