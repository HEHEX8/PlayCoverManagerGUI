# Homebrew Cask for PlayCoverManager

## 🍺 ユーザー向けインストール方法

### 方法1: Tapを使用（推奨）

```bash
# このリポジトリをTapに追加
brew tap HEHEX8/playcovermanager https://github.com/HEHEX8/PlayCoverManagerGUI

# インストール（自動でGatekeeper警告を回避）
brew install --cask playcovermanager
```

### 方法2: URLを直接指定

```bash
brew install --cask https://raw.githubusercontent.com/HEHEX8/PlayCoverManagerGUI/main/homebrew/playcovermanager.rb
```

---

## 🔧 開発者向け: Caskの更新方法

### 1. リリースビルドを作成

```bash
./scripts/build_release_unsigned.sh
```

これで以下が表示されます：
- DMGファイルのパス
- SHA256ハッシュ

### 2. GitHub Releasesにアップロード

```bash
# タグ作成
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

GitHub Releasesページで：
1. https://github.com/HEHEX8/PlayCoverManagerGUI/releases/new
2. タグ `v1.0.0` を選択
3. DMGファイルをアップロード
4. 公開

### 3. Cask Formulaを更新

`homebrew/playcovermanager.rb` を編集：

```ruby
version "1.0.0"  # ← 新しいバージョン
sha256 "abc123..." # ← build_release_unsigned.shで表示されたSHA256
```

### 4. コミット＆プッシュ

```bash
git add homebrew/playcovermanager.rb
git commit -m "chore: Update Homebrew cask to v1.0.0"
git push origin main
```

---

## 🧪 テスト

### ローカルでテスト

```bash
# Caskをインストール（ローカルファイルから）
brew install --cask homebrew/playcovermanager.rb

# 起動確認
open /Applications/PlayCoverManager.app

# アンインストール
brew uninstall --cask playcovermanager
```

### Lintチェック

```bash
brew audit --cask homebrew/playcovermanager.rb
brew style --fix homebrew/playcovermanager.rb
```

---

## 📝 Cask Formula説明

```ruby
cask "playcovermanager" do
  version "1.0.0"              # バージョン番号
  sha256 "..."                 # DMGのSHA256ハッシュ（セキュリティ検証用）
  
  url "https://..."            # DMGのダウンロードURL
  name "PlayCover Manager"     # アプリの表示名
  desc "..."                   # 説明文
  homepage "..."               # プロジェクトURL
  
  depends_on macos: ">= :big_sur"  # macOS要件
  
  app "PlayCoverManager.app"   # インストールするアプリ
  
  postflight do
    # インストール後に実行（Quarantine属性削除）
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/PlayCoverManager.app"]
  end
  
  uninstall quit: "..."        # アンインストール時に終了するアプリ
  
  zap trash: [...]             # アンインストール時に削除するファイル
end
```

---

## 🌟 利点

### ユーザー側：
- ✅ `brew install` だけで完結
- ✅ Gatekeeperの警告が自動回避
- ✅ 右クリック→開く不要
- ✅ アップデートも `brew upgrade` で簡単

### 開発者側：
- ✅ 署名不要（無料）
- ✅ 公証不要（無料）
- ✅ ビルド → リリース → Cask更新だけ

---

## 🔄 アップデートフロー

1. コード変更
2. `./scripts/build_release_unsigned.sh` 実行
3. GitHub Releasesに新しいDMGをアップロード
4. `homebrew/playcovermanager.rb` の `version` と `sha256` を更新
5. コミット＆プッシュ

**ユーザー側：**
```bash
brew upgrade playcovermanager
```

---

## 📚 参考リンク

- [Homebrew Cask公式ドキュメント](https://docs.brew.sh/Cask-Cookbook)
- [Cask Formula Reference](https://docs.brew.sh/Cask-Cookbook#stanza-reference)
- [Homebrew公式リポジトリ](https://github.com/Homebrew/homebrew-cask)

---

## ❓ FAQ

**Q: Homebrew公式リポジトリに追加できる？**
A: できますが、以下の条件が必要：
- ある程度の人気・需要
- 安定したリリース
- メンテナンス継続の意思

個人製作なら自分のリポジトリでTap運用が現実的です。

**Q: Tapとは？**
A: Homebrewの追加リポジトリのこと。`brew tap` で追加できます。

**Q: 署名なしでも安全？**
A: `postflight` で `xattr -cr` を実行するので、ユーザーの手間が省けます。
   Homebrewが検証するため、一定の信頼性はあります。
