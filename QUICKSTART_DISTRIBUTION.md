# 🚀 PlayCoverManager 配布クイックスタート

アプリをGatekeeperに怒られずに配布するための最短手順です。

## ⚡ 3ステップでリリース

### ステップ1: Apple Developer準備（初回のみ）

1. **Apple Developer Programに加入**
   - https://developer.apple.com/programs/
   - 年間$99（クレジットカード必要）

2. **Developer ID証明書を取得**
   ```
   Xcode > Settings > Accounts > [Apple ID] > Manage Certificates
   → "+" > "Developer ID Application"
   ```

3. **App-Specific Passwordを作成**
   - https://appleid.apple.com/account/manage
   - "App-Specific Passwords" > "Generate Password"
   - **生成されたパスワードをメモ！**

4. **認証情報をKeychainに保存（推奨）**
   ```bash
   xcrun notarytool store-credentials "playcover-notarization" \
       --apple-id "your-email@example.com" \
       --team-id "YOUR_TEAM_ID" \
       --password "xxxx-xxxx-xxxx-xxxx"
   ```
   
   Team IDの確認方法:
   - https://developer.apple.com/account → Membership

---

### ステップ2: ビルド・署名・公証

**超簡単！ワンコマンド実行:**

```bash
# Keychainプロファイル設定
export NOTARIZATION_KEYCHAIN_PROFILE="playcover-notarization"

# 実行（完全自動）
./scripts/build_and_notarize.sh
```

**処理内容（全自動）:**
1. ✅ プロジェクトをArchiveビルド
2. ✅ Developer ID証明書で署名
3. ✅ .appファイルをエクスポート
4. ✅ DMGファイルを作成
5. ✅ Appleに公証リクエスト送信（5-15分）
6. ✅ 公証チケットをDMGに添付
7. ✅ Gatekeeper検証

**完成！**
👉 `build/PlayCoverManager.dmg` が配布可能な状態で作成されます。

---

### ステップ3: リリース配布

#### GitHubリリース作成:

1. **タグを作成**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

2. **GitHubでリリース作成**
   - https://github.com/HEHEX8/PlayCoverManagerGUI/releases/new
   - タグ選択: `v1.0.0`
   - タイトル: `PlayCoverManager v1.0.0`
   - DMGをアップロード: `build/PlayCoverManager.dmg`

3. **完了！🎉**
   - ユーザーはDMGをダウンロードして即起動可能
   - Gatekeeperの警告は一切出ません

---

## 📝 リリースノートテンプレート

```markdown
## PlayCoverManager v1.0.0

### ✨ 新機能
- iOSアプリの快適な起動・管理
- 検索機能で素早くアプリを発見
- ディスク使用量の確認
- PlayCover連携

### 📦 ダウンロード
**[PlayCoverManager.dmg](リンク)** (XX.X MB)

**対応環境:**
- macOS 11.0 Big Sur以降
- Apple Silicon / Intel両対応

### 🔐 セキュリティ
- ✅ Apple公式の署名・公証済み
- ✅ Gatekeeperに承認されています
- ✅ 安全にインストール・起動できます

### 📖 インストール方法
1. DMGファイルをダウンロード
2. DMGを開く
3. PlayCoverManagerを「アプリケーション」フォルダにドラッグ
4. 起動！

### ⚠️ 注意事項
- PlayCoverが事前にインストールされている必要があります
- 初回起動時にディスクイメージの保存場所を設定します

---

**問題が発生した場合:**
- GitHub Issues: https://github.com/HEHEX8/PlayCoverManagerGUI/issues
```

---

## 🛠️ 開発用ビルド（テスト用）

公証なしの簡易ビルド:

```bash
./scripts/build_dev.sh
```

出力: `build/dev/Build/Products/Debug/PlayCoverManager.app`

⚠️ **注意**: このビルドは自分のマシンでのみ動作します（署名なし）

---

## ❓ よくある質問

### Q: 毎回公証が必要？
**A:** はい。DMGを変更するたびに公証が必要です。

### Q: 公証にどれくらい時間かかる？
**A:** 通常5-15分。混雑時は30分程度。

### Q: 公証に失敗したら？
**A:** ログを確認:
```bash
xcrun notarytool log SUBMISSION_ID \
    --keychain-profile "playcover-notarization"
```

一般的な原因:
- Hardened Runtimeが無効 → プロジェクト設定を確認
- 署名されていないバイナリが含まれる → 依存関係を確認

### Q: 証明書の有効期限は？
**A:** Developer ID証明書は5年間有効。期限前に自動更新可能。

### Q: 費用は？
**A:** 
- Apple Developer Program: $99/年
- 公証（Notarization）: 無料・無制限

---

## 📚 詳細ドキュメント

- **完全ガイド**: [DISTRIBUTION_GUIDE.md](DISTRIBUTION_GUIDE.md)
- **スクリプト説明**: [scripts/README.md](scripts/README.md)

---

## 🎯 まとめ

1. **初回準備**: Apple Developer加入 + 証明書取得 + 認証情報保存
2. **毎回実行**: `./scripts/build_and_notarize.sh`
3. **リリース**: GitHub ReleasesにDMGアップロード

**たったこれだけ！** 🚀

ユーザーはダウンロードして即起動。Gatekeeperの警告は一切出ません！
