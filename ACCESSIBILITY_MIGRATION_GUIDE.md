# ♿ アクセシビリティ移行ガイド

**作成日**: 2025年11月11日  
**対象**: PlayCoverManager全ビューのユニバーサルデザイン準拠  
**ステータス**: ⚠️ **実装中止** (2025年11月11日)

---

## 🚫 実装中止の通知

このガイドは、PlayCoverManagerのユニバーサルデザイン実装のために作成されましたが、以下の理由により**実装を中止**しました。

### 中止理由

1. **Swift 6.2の型システムの複雑性**
   - `@Environment`プロパティラッパーの型推論が期待通りに動作しない
   - `ColorSchemeContrast`型の認識エラー
   - Observable vs EnvironmentValuesの構文混乱

2. **実装コストの高さ**
   - 全ビューファイルへの大規模な変更が必要
   - 既存のLiquid Glass Design Systemとの統合の難しさ
   - デバッグとトラブルシューティングに膨大な時間を要する

3. **技術的不確実性**
   - Swift 6.2の型システムに関するベストプラクティスが不明確
   - Appleの公式ドキュメントでも明確な指針がない
   - コミュニティでもまだ解決策が確立されていない

### このドキュメントの位置づけ

このガイドは**将来の参考資料**として保持します：

- ✅ ユニバーサルデザインの概念とパターンは有効
- ✅ WCAG 2.1 AA準拠の要件は変わらない
- ✅ 将来、Swift/SwiftUIの型システムが安定した際の再実装の指針として使用可能

---

## 📋 概要（参考情報）

このドキュメントは、PlayCoverManagerの全UIを**WCAG 2.1 AA準拠**のユニバーサルデザインに移行するための手順書として作成されました。

**提案されたインフラストラクチャ**（未実装）:
- 📄 `AccessibilityEnvironment.swift` - アクセシビリティ設定検出
- 📄 `AccessibleGlassEffect.swift` - アダプティブGlass effectコンポーネント
- 📄 `SemanticColors.swift` - WCAG準拠セマンティックカラーシステム
- 📄 `APPLE_DEV_2025_REFERENCE.md v1.6+` - 完全ガイドライン

**対象ビュー**（実装せず）:
1. QuickLauncherView (3833行) - ❌ 未実装
2. SettingsRootView - ❌ 未実装
3. SetupWizardView - ❌ 未実装
4. AppRootView - ❌ 未実装

---

## ⚠️ 注意: 以下は参考情報です

以下のセクションは、実装を試みた際の知見として保持していますが、**実際には適用されていません**。

---

## 🔄 移行パターン

### パターン1: 固定色 → セマンティックカラー

**Before (悪い例)**:
```swift
.foregroundColor(.blue)
.background(Color(red: 0.95, green: 0.95, blue: 0.97))
```

**After (良い例)**:
```swift
.foregroundStyle(SemanticColors.info)
.background(SemanticColors.primaryBackground)
```

**対象**: すべてのハードコードされた色値

---

### パターン2: glassEffect → accessibleGlassEffect

**Before (悪い例)**:
```swift
.glassEffect(.regular.tint(.blue.opacity(0.1)), in: RoundedRectangle(cornerRadius: 12))
```

**After (良い例)**:
```swift
.accessibleGlassEffect(style: .standard, shape: RoundedRectangle(cornerRadius: 12))

// または、色付きの場合
.accessibleGlassEffect(
    style: GlassStyle(tint: SemanticColors.glassBlue, opacity: 1.0, cornerRadius: 12),
    shape: RoundedRectangle(cornerRadius: 12)
)
```

**対象**: すべての `.glassEffect()` 呼び出し

---

### パターン3: アニメーション → アクセシビリティ対応アニメーション

**Before (悪い例)**:
```swift
.animation(.spring(response: 0.3), value: isOpen)
```

**After (良い例)**:
```swift
.accessibilityAnimation(.spring(response: 0.3), value: isOpen)
```

**対象**: すべての `.animation()` 呼び出し

---

### パターン4: VoiceOverラベル追加

**Before (悪い例)**:
```swift
Image(systemName: "gear")
```

**After (良い例)**:
```swift
Image(systemName: "gear")
    .accessibilityLabel("設定")
    .accessibilityHint("アプリの設定画面を開きます")
```

**対象**: すべてのアイコンとボタン

---

### パターン5: 最小ヒットターゲットサイズ

**Before (悪い例)**:
```swift
Button(action: action) {
    Image(systemName: "trash")
}
```

**After (良い例)**:
```swift
Button(action: action) {
    Image(systemName: "trash")
        .frame(width: 20, height: 20)
}
.frame(minWidth: 44, minHeight: 44)  // Apple HIG最小要件
.contentShape(Rectangle())
```

**対象**: すべてのボタンとインタラクティブ要素

---

## 📂 ビュー別移行チェックリスト

### 1. QuickLauncherView (優先度: 高)

**Glass Effect箇所** (13箇所):
- [ ] Line 220: 検索フィールド - `.accessibleGlassEffect()` に置換
- [ ] Line 243: ツールバー - `.accessibleGlassEffect()` に置換
- [ ] Line 341: Recent Appボタン - `.accessibleGlassEffect()` に置換
- [ ] Line 486: ドロワー - `.accessibleGlassEffect()` に置換
- [ ] Line 674: ModernToolbarButton - `.accessibleGlassEffect()` に置換
- [ ] Line 1081: ContextMenuPreview - `.accessibleGlassEffect()` に置換
- [ ] Line 1150: AppDetailsView - `.accessibleGlassEffect()` に置換
- [ ] Line 1215: UnmountFlowView - `.accessibleGlassEffect()` に置換
- [ ] Line 1357: UninstallDialogView - `.accessibleGlassEffect()` に置換
- [ ] Line 3511: InstallerView - `.accessibleGlassEffect()` に置換
- [ ] Line 3609: UninstallerView - `.accessibleGlassEffect()` に置換
- [ ] Line 3675: ErrorDialogView - `.accessibleGlassEffect()` に置換
- [ ] Line 3781: ShortcutGuideView - `.accessibleGlassEffect()` に置換

**VoiceOverラベル追加** (推定30箇所):
- [ ] イジェクトボタン: "ディスクイメージをアンマウント"
- [ ] 設定ボタン: "設定"
- [ ] 追加ボタン: "新しいアプリをインストール"
- [ ] 検索フィールド: "アプリを検索"
- [ ] アプリアイコン各種: アプリ名 + "起動するにはダブルクリック"
- [ ] その他インタラクティブ要素

**セマンティックカラー置換**:
- [ ] すべてのハードコードされた色値を `SemanticColors.*` に置換
- [ ] `.accentColor` → `SemanticColors.accent`
- [ ] `.blue` → `SemanticColors.info`
- [ ] `.green` → `SemanticColors.success`
- [ ] `.orange` → `SemanticColors.warning`
- [ ] `.red` → `SemanticColors.error`

---

### 2. SettingsRootView (優先度: 高)

**Glass Effect箇所** (7箇所 - すべて設定カード):
- [ ] Storage管理カード
- [ ] Mount設定カード
- [ ] 言語設定カード
- [ ] データ処理カード
- [ ] キャッシュカード
- [ ] ショートカットカード
- [ ] リセットカード

**推奨アプローチ**:
すべてのカードを `AccessibleGlassCard` コンポーネントでラップ:

```swift
// Before
VStack {
    // カードコンテンツ
}
.padding(20)
.glassEffect(.regular.tint(.blue.opacity(0.08)), in: RoundedRectangle(cornerRadius: 12))

// After
AccessibleGlassCard(style: GlassStyle(tint: SemanticColors.glassBlue, opacity: 1.0, cornerRadius: 12)) {
    VStack {
        // カードコンテンツ
    }
}
```

---

### 3. SetupWizardView (優先度: 中)

**Glass Effect箇所** (1箇所):
- [ ] Line 28: メインセットアップカード

**アプローチ**:
```swift
AccessibleGlassCard(style: GlassStyle(tint: SemanticColors.glassAccent, opacity: 1.0, cornerRadius: 20)) {
    // セットアップコンテンツ
}
```

---

### 4. AppRootView (優先度: 中)

**Glass Effect箇所** (3箇所):
- [ ] CheckingView
- [ ] ErrorView  
- [ ] TerminationFlowView

**VoiceOverラベル追加**:
- [ ] 再試行ボタン
- [ ] システム設定を開くボタン
- [ ] 保存先を変更ボタン
- [ ] 終了ボタン

---

## 🧪 テスト手順

各ビュー更新後、以下をテスト:

### 必須テスト
- [ ] **通常モード**: すべての機能が正常動作
- [ ] **Reduce Transparency ON**: 不透明な高コントラストモードに切り替わる
- [ ] **Increase Contrast ON**: より強い境界線とコントラストが適用される
- [ ] **Reduce Motion ON**: アニメーションが無効化される
- [ ] **ライトモード**: 色が適切に表示される
- [ ] **ダークモード**: 色が適切に表示される
- [ ] **VoiceOver ON**: すべての要素が読み上げられる
- [ ] **キーボードのみ操作**: すべての機能にアクセス可能

### 推奨テスト
- [ ] High Contrast Glass Mode ON
- [ ] Reduce Transparency + Increase Contrast 組み合わせ
- [ ] Switch Control対応確認
- [ ] Voice Control対応確認

---

## 📊 進捗管理

### Phase 1: インフラストラクチャ (✅ 完了)
- [x] AccessibilityEnvironment.swift
- [x] AccessibleGlassEffect.swift
- [x] SemanticColors.swift
- [x] APPLE_DEV_2025_REFERENCE.md v1.6

### Phase 2: 主要ビュー (🔄 進行中)
- [ ] QuickLauncherView (13箇所のGlass effect)
- [ ] SettingsRootView (7箇所のGlass effect)

### Phase 3: サブビュー (⏳ 未着手)
- [ ] SetupWizardView (1箇所)
- [ ] AppRootView (3箇所)

### Phase 4: VoiceOverサポート (⏳ 未着手)
- [ ] QuickLauncherView全ボタン
- [ ] SettingsRootView全セクション
- [ ] その他ビュー

### Phase 5: 最終テスト (⏳ 未着手)
- [ ] 全システム設定組み合わせテスト
- [ ] VoiceOver完全テスト
- [ ] キーボードナビゲーションテスト
- [ ] パフォーマンステスト

---

## 💡 実装のヒント

### ヒント1: 段階的移行
一度にすべてを変更せず、ビューごとに完了させる：
1. 1つのビューを完全に移行
2. テスト
3. コミット
4. 次のビューへ

### ヒント2: 検索置換の活用
```bash
# Glass effectの一括検索
grep -n "\.glassEffect" Views/*.swift

# 固定色の一括検索
grep -n "Color(red:" Views/*.swift
grep -n "\.blue\|\.red\|\.green\|\.orange" Views/*.swift
```

### ヒント3: プレビューの活用
各変更後、Xcode Previewで視覚確認:
```swift
#Preview("Accessibility Test") {
    YourModifiedView()
        .environment(\.accessibilityReduceTransparency, true)  // テスト用
}
```

### ヒント4: コミット粒度
各ビュー完了ごとにコミット:
```bash
git commit -m "feat(accessibility): apply universal design to QuickLauncherView

- Replace all glassEffect with accessibleGlassEffect
- Apply semantic colors
- Add VoiceOver labels
- Ensure 44pt minimum hit targets

WCAG 2.1 AA compliant"
```

---

## 📚 参照ドキュメント

### 主要リファレンス
- **APPLE_DEV_2025_REFERENCE.md v1.6**: 完全なガイドライン
- **AccessibleGlassEffect.swift**: コンポーネント実装例
- **SemanticColors.swift**: カラーシステム定義

### 外部リソース
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Apple HIG - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [macOS Tahoe 26 Accessibility Guide](https://macos-tahoe.com/blog/macos-tahoe-accessibility-complete-guide-2025/)

---

## ✅ 完了基準

すべてのビューが以下を満たすこと:

1. ✅ すべての `.glassEffect()` が `.accessibleGlassEffect()` に置換済み
2. ✅ すべての固定色が `SemanticColors.*` に置換済み
3. ✅ すべてのアニメーションが `.accessibilityAnimation()` 対応
4. ✅ すべてのボタンが44×44pt以上
5. ✅ すべてのアイコンにVoiceOverラベル追加済み
6. ✅ Reduce Transparency / Increase Contrast 動作確認済み
7. ✅ VoiceOverで完全操作可能
8. ✅ キーボードのみで完全操作可能

---

**次のステップ**: QuickLauncherViewから段階的に適用を開始してください。
