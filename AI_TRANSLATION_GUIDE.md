# PlayCoverManager AI翻訳ガイド

このドキュメントは、AIが日本語から英語・中国語への翻訳を行う際の参考資料です。

## 🎯 翻訳の原則

### 1. 用語の一貫性
- 同じ日本語用語は常に同じ英語/中国語に翻訳する
- 専門用語は業界標準の訳語を使用する
- UI要素の訳語は簡潔で明確にする

### 2. 文体
- **日本語**: 丁寧語（です・ます調）
- **英語**: 簡潔で直接的（命令形や不定詞を使用）
- **中国語**: 簡潔で礼貌的

### 3. フォーマット
- プレースホルダー（%@, %lld等）は必ず保持する
- 改行は元の構造を維持する
- 句読点は各言語の慣例に従う

## 📚 重要用語集

### コア用語

#### `アプリ / アプリケーション`

- **英語**: app / application
- **簡体字**: 应用 / 应用程序
- **繁体字**: 應用 / 應用程式
- **備考**: UIでは「app」を優先

#### `ディスクイメージ`

- **英語**: disk image
- **簡体字**: 磁盘映像
- **繁体字**: 磁碟映像
- **備考**: ASIFフォーマットの仮想ディスク

#### `マウント`

- **英語**: mount
- **簡体字**: 挂载
- **繁体字**: 掛載
- **備考**: ディスクイメージをシステムに接続する

#### `アンマウント`

- **英語**: unmount
- **簡体字**: 卸载
- **繁体字**: 卸載
- **備考**: ディスクイメージを切断する

#### `イジェクト`

- **英語**: eject
- **簡体字**: 弹出
- **繁体字**: 彈出
- **備考**: ドライブを取り出す

#### `コンテナ`

- **英語**: container
- **簡体字**: 容器
- **繁体字**: 容器
- **備考**: アプリのデータを格納する領域

#### `インストール`

- **英語**: install
- **簡体字**: 安装
- **繁体字**: 安裝

#### `アンインストール`

- **英語**: uninstall
- **簡体字**: 卸载
- **繁体字**: 卸載

#### `設定 / 設定項目`

- **英語**: settings
- **簡体字**: 设置
- **繁体字**: 設定

#### `保存先`

- **英語**: save location / storage location
- **簡体字**: 保存位置
- **繁体字**: 儲存位置

#### `内部データ / 内部ストレージ`

- **英語**: internal data / internal storage
- **簡体字**: 内部数据 / 内部存储
- **繁体字**: 內部資料 / 內部儲存
- **備考**: アプリ内のユーザーデータ

#### `IPA`

- **英語**: IPA
- **簡体字**: IPA
- **繁体字**: IPA
- **備考**: iOS App Store Package

## 🔤 UI要素の訳語

- **ボタン**: button / 按钮|按鈕
- **キャンセル**: Cancel / 取消
- **OK**: OK / 确定|確定
- **はい**: Yes / 是
- **いいえ**: No / 否
- **続ける**: Continue / 继续|繼續
- **閉じる**: Close / 关闭|關閉
- **開く**: Open / 打开|打開
- **選択**: Select / 选择|選擇
- **参照**: Browse / 浏览|瀏覽

## 📋 よく使われるフレーズパターン

### ～しています…

- **英語**: ～ing...
- **中国語**: 正在～...
- **例**:
  - 🇯🇵 インストールしています…
  - 🇺🇸 Installing...
  - 🇨🇳 正在安装...

### ～しますか？

- **英語**: ～?
- **中国語**: 是否～？
- **例**:
  - 🇯🇵 インストールしますか？
  - 🇺🇸 Install?
  - 🇨🇳 是否安装？

### ～できませんでした

- **英語**: Failed to ～
- **中国語**: 无法～ / 無法～
- **例**:
  - 🇯🇵 インストールできませんでした
  - 🇺🇸 Failed to install
  - 🇨🇳 无法安装 / 無法安裝

### ～してください

- **英語**: Please ～
- **中国語**: 请～
- **例**:
  - 🇯🇵 選択してください
  - 🇺🇸 Please select
  - 🇨🇳 请选择

## 🎨 スタイルガイド

### 英語
- タイトルケース: ダイアログタイトル、ボタンラベル
- センテンスケース: 説明文、エラーメッセージ
- 簡潔性: 冗長な表現を避ける
- 例:
  - ✅ "Install App"
  - ❌ "Perform App Installation"

### 中国語
- 簡体字と繁体字の違いを意識
- 簡潔で明確な表現
- 専門用語は統一
- 例:
  - ✅ 简体字: "安装应用" / 繁体字: "安裝應用"
  - ❌ "进行应用程序的安装操作"

## 📊 完全な翻訳データベース

総エントリー数: 589

各エントリーは以下の形式で記録されています：

```
日本語原文 | 英語訳 | 簡体字訳 | 繁体字訳
```

### 全エントリー一覧

| ` (推奨)` | (recommended) | (受到推崇的) | (受到推崇的) |
| ` (省電力)` | (Power saving) | (省电) | (省電) |
| ` に一致するアプリが見つかりませんでした。` | No matching apps were found. | 未找到匹配的应用程序。 | 未找到匹配的應用程序。 |
| `"%@" に一致するアプリが見つかりませんでした。` | No apps found matching "%@". | 未找到与“%@”匹配的应用程序。 | 未找到與“%@”匹配的應用程序。 |
| `%@ → %@` | %@ → %@ | %@ → %@ | %@ → %@ |
| `%@ の内部ストレージにデータが存在します。どのように処理しますか？` | Data exists in internal storage for %@. How would you like to proceed? | 数据存在于%@的内部存储器中。你如何处理？ | 數據存在於%@的內部存儲器中。你如何處理？ |
| `%@ をインストール中` | Installing %@ | 正在安装%@ | 正在安裝%@ |
| `%@ を準備しています…` | Preparing %@... | 正在准备%@... | 正在準備%@... |
| `%@ 用の ASIF ディスクイメージを作成しますか？` | Would you like to create an ASIF disk image for %@? | 您想为 %@ 创建 ASIF 磁盘映像吗？ | 您想為 %@ 創建 ASIF 磁盤映像嗎？ |
| `%@ 用のディスクイメージを作成しています…` | Creating disk image for %@... | 正在为 %@ 创建磁盘映像... | 正在為 %@ 創建磁盤映像... |
| `%@:` | %@: | %@: | %@: |
| `%@: 解析失敗 - %@` | %1$@: Parsing failed - %2$@ | %1$@:解析失败 - %2$@ | %1$@:解析失敗 - %2$@ |
| `%lld` |  |  |  |
| `%lld / %lld 完了` | %lld / %lld Complete | %lld / %lld 已完成 | %lld / %lld 已完成 |
| `%lld 個` | %lld items | %lld 件 | %lld 件 |
| `%lld 個のアプリ` |  |  |  |
| `%lld 個のアプリをアンインストールしますか？` | Uninstall %lld apps? | 您想卸载 %lld 个应用程序吗？ | 您想卸載 %lld 個應用程序嗎？ |
| `%lld 個のアプリをインストールしますか？` | Install %lld apps? | 您想安装 %lld 个应用程序吗？ | 您想安裝 %lld 個應用程序嗎？ |
| `%lld 個のコンテナをアンマウントできませんでした。` | Failed to unmount %lld containers. | 无法卸载 %lld 个容器。 | 無法卸載 %lld 個容器。 |
| `%lld 個のコンテナを強制アンマウントできませんでした。

Finderから手動でイジェクトしてから、再度保存先の変更を試してください。` | Failed to force unmount %lld containers.

Please manually eject it from Finder and try changing the save location again. | 无法强制卸载 %lld 个容器。

请手动将其从 Finder 中弹出，然后再次尝试更改保存位置。 | 無法強制卸載 %lld 個容器。

請手動將其從 Finder 中彈出，然後再次嘗試更改保存位置。 |
| `%lld 個のコンテナを強制アンマウントできませんでした。

手動でFinderからイジェクトしてください。` | Failed to force unmount %lld containers.

Please manually eject it from Finder. | 无法强制卸载 %lld 个容器。

请手动将其从 Finder 中弹出。 | 無法強制卸載 %lld 個容器。

請手動將其從 Finder 中彈出。 |
| `(拡張子なし)` | (no extension) | (无扩展名) | (無擴展名) |
| `) 用の ASIF ディスクイメージを作成しますか？` | ) would you like to create an ASIF disk image for it? | )您想为其创建一个 ASIF 磁盘映像吗？ | )您想為其創建一個 ASIF 磁盤映像嗎？ |
| `+\(analyzedIPAs.count - 6) 個のアプリ` | +\(analyzedIPAs.count - 6) apps | +\(analyzedIPAs.count - 6) 个应用 | +\(analyzedIPAs.count - 6) 個應用 |
| `+\(selectedAppInfos.count - 6) 個のアプリ` | +\(selectedAppInfos.count - 6) apps | +\(selectedAppInfos.count - 6) 个应用 | +\(selectedAppInfos.count - 6) 個應用 |
| `.%@` | .%@ | .%@ | .%@ |
| `5分以内に完了しませんでした` | Did not complete within 5 minutes | 5分钟内未完成 | 5分鐘內未完成 |
| `=== デバッグコンソール ===` | === Debug console === | ===调试控制台=== | ===調試控制台=== |
| `ASIF ディスクイメージの保存先を選択してください。外部ストレージがおすすめですが強制ではありません。` | Select a destination for the ASIF disk image.External storage is recommended but not required. | 选择 ASIF 磁盘映像的目标。建议使用外部存储，但不是必需的。 | 選擇 ASIF 磁盤映像的目標。建議使用外部存儲，但不是必需的。 |
| `ASIF ディスクイメージを保存するフォルダを選択してください。` | Select a folder to save the ASIF disk image. | 选择一个文件夹来保存 ASIF 磁盘映像。 | 選擇一個文件夾來保存 ASIF 磁盤映像。 |
| `ASIF ディスクイメージ形式対応` | Supports ASIF disk image format | 支持ASIF磁盘镜像格式 | 支持ASIF磁盤鏡像格式 |
| `ASIF（macOS Tahoe 専用）` | ASIF (macOS Tahoe only) | ASIF(仅限 macOS Tahoe) | ASIF(僅限 macOS Tahoe) |
| `App: %@` | App: %@ | 应用程序: %@ | 應用程式: %@ |
| `Apple Silicon Mac 専用` | Apple Silicon Mac only | 仅适用于 Apple Silicon Mac | 僅適用於 Apple Silicon Mac |
| `Bundle Identifier の取得に失敗しました` | Failed to get Bundle Identifier | 获取包标识符失败 | 獲取包標識符失敗 |
| `Enter` | Enter | 进入 | 進入 |
| `Escキーまたは背景をクリックして閉じる` | Press Esc key or click background to close | 点击Esc键或背景关闭 | 點擊Esc鍵或背景關閉 |
| `Finder での表示設定` | Finder Display Settings | 取景器显示设置 | 取景器顯示設置 |
| `Finder でアプリを表示` | Show apps in Finder | 在 Finder 中显示应用程序 | 在 Finder 中顯示應用程序 |
| `Finder でコンテナを表示` | Show containers in Finder | 在 Finder 中显示容器 | 在 Finder 中顯示容器 |
| `Finder で表示` | View in Finder | 在 Finder 中查看 | 在 Finder 中查看 |
| `Finder に表示しない (-nobrowse)` | Do not show in Finder (-nobrowse) | 不在 Finder 中显示 (-nobrowse) | 不在 Finder 中顯示 (-nobrowse) |
| `Finderに表示しない` | Don't show in Finder | 不显示在 Finder 中 | 不顯示在 Finder 中 |
| `Finderに表示する` | Show in Finder | 在 Finder 中显示 | 在 Finder 中顯示 |
| `GitHub リポジトリ` | GitHub Repository | GitHub 存储库 | GitHub 存儲庫 |
| `IPA をインストール` | Install IPA | 安装IPA | 安裝IPA |
| `IPA をインストール (⌘I)` | Install IPA (⌘I) | 安装 IPA (⌘I) | 安裝 IPA (⌘I) |
| `IPA を選択` | Select IPA | 选择IPA | 選擇IPA |
| `IPA インストーラー` | IPA Installer | IPA安装程序 | IPA安裝程序 |
| `IPA インストール、アプリ起動、アンインストール、ストレージ管理などの機能を提供します。` | Provides IPA installation, app launching, uninstallation, and storage management features. | 提供IPA安装、应用启动、卸载、存储管理等功能。 | 提供IPA安裝、應用啟動、卸載、存儲管理等功能。 |
| `IPA ファイルをインストールすると、ここに表示されます。` | Once the IPA file is installed, it will appear here. | 安装 IPA 文件后，它将出现在此处。 | 安裝 IPA 文件後，它將出現在此處。 |
| `IPA ファイルを解析中...` | Parsing IPA file... | 正在解析 IPA 文件... | 正在解析 IPA 文件... |
| `IPA ファイルを選択してください` | Select IPA Files | 请选择一个 IPA 文件 | 請選擇一個 IPA 文件 |
| `IPA 内に .app が見つかりません` | .app not found in IPA | 在 IPA 中找不到 .app | 在 IPA 中找不到 .app |
| `IPA 内に Info.plist が見つかりません` | Info.plist not found in IPA | IPA 中未找到 Info.plist | IPA 中未找到 Info.plist |
| `Info.plist の読み取りに失敗しました` | Failed to read Info.plist | 无法读取 Info.plist | 無法讀取 Info.plist |
| `MIT ライセンスで提供` | Licensed under MIT License | 根据 MIT 许可提供 | 根據 MIT 許可提供 |
| `MacBook Air での長時間プレイに推奨（低解像度だが安定した 60 FPS）` | Recommended for long-term play on MacBook Air (low resolution but stable 60 FPS) | 建议在 MacBook Air 上长期玩(低分辨率但稳定的 60 FPS) | 建議在 MacBook Air 上長期玩(低分辨率但穩定的 60 FPS) |
| `OK` | OK | 好的 | 好的 |
| `PlayCover Manager` | PlayCover Manager | PlayCover 管理器 | PlayCover 管理器 |
| `PlayCover Manager は PlayCover を補完するアプリです。

ディスクイメージの管理と IPA インストールを簡単にします。` | PlayCover Manager is a companion app for PlayCover.

It simplifies disk image management and IPA installation. | PlayCover Manager 是一款对 PlayCover 进行补充的应用程序。

轻松管理磁盘映像和 IPA 安装。 | PlayCover Manager 是一款對 PlayCover 進行補充的應用程序。

輕鬆管理磁盤映像和 IPA 安裝。 |
| `PlayCover Manager は PlayCover を補完するアプリです。\n\nディスクイメージの管理と IPA インストールを簡単にします。` | PlayCover Manager is a companion app for PlayCover.\n\nIt simplifies disk image management and IPA installation. | PlayCover Manager 是一款对 PlayCover 进行补充的应用程序。\n\n轻松的磁盘映像管理和 IPA 安装。 | PlayCover Manager 是一款對 PlayCover 進行補充的應用程序。\n\n輕鬆的磁盤映像管理和 IPA 安裝。 |
| `PlayCover Manager は、PlayCover でインストールした iOS アプリを統合的に管理するための GUI ツールです。` | PlayCover Manager is a GUI tool for comprehensive management of iOS apps installed with PlayCover. | PlayCover Manager 是一个 GUI 工具，用于全面管理随 PlayCover 安装的 iOS 应用程序。 | PlayCover Manager 是一個 GUI 工具，用於全面管理隨 PlayCover 安裝的 iOS 應用程序。 |
| `PlayCover Manager を終了` | Quit PlayCover Manager | 退出 PlayCover Manager | 退出 PlayCover Manager |
| `PlayCover が作成する不要なショートカットを削除します。PlayCover.app 起動時に再作成されます。` | Remove unnecessary shortcuts created by PlayCover. They will be recreated when PlayCover.app is launched. | 删除 PlayCover 创建的不必要的快捷方式。启动 PlayCover.app 时将重新创建。 | 刪除 PlayCover 創建的不必要的快捷方式。啟動 PlayCover.app 時將重新創建。 |
| `PlayCover が実行中の可能性があります。

エラー: %@` | PlayCover may be running.

Error: %@ | PlayCover 可能正在运行。

错误: %@ | PlayCover 可能正在運行。

錯誤: %@ |
| `PlayCover が実行中の可能性があります。\n\nエラー: \(error.localizedDescription)` | PlayCover may be running.\n\nError: \(error.localizedDescription) | PlayCover 可能正在运行。\n\n错误:\(error.localizedDescription) | PlayCover 可能正在運行。\n\n錯誤:\(error.localizedDescription) |
| `PlayCover が終了しました` | PlayCover has ended | PlayCover 已结束 | PlayCover 已結束 |
| `PlayCover が見つかりました` | PlayCover Found | 发现 PlayCover | 發現 PlayCover |
| `PlayCover が見つかりません` | PlayCover not found | 未找到 PlayCover | 未找到 PlayCover |
| `PlayCover でインストール中` | Installing with PlayCover | 使用 PlayCover 安装 | 使用 PlayCover 安裝 |
| `PlayCover の Bundle ID を取得できません` | Unable to get PlayCover Bundle ID | 无法获取 PlayCover 捆绑包 ID | 無法獲取 PlayCover 捆綁包 ID |
| `PlayCover の Info.plist を読み込めません` | Unable to load PlayCover's Info.plist | 无法加载 PlayCover 的 Info.plist | 無法加載 PlayCover 的 Info.plist |
| `PlayCover の検出` | PlayCover detection | PlayCover检测 | PlayCover檢測 |
| `PlayCover の準備` | Preparing PlayCover | 准备 PlayCover | 準備 PlayCover |
| `PlayCover の確認に失敗` | PlayCover verification failed | PlayCover 验证失败 | PlayCover 驗證失敗 |
| `PlayCover の起動に失敗しました` | PlayCover failed to start | PlayCover 无法启动 | PlayCover 無法啟動 |
| `PlayCover を /Applications にインストールしてください。` | Please install PlayCover in /Applications. | 请在 /Applications 中安装 PlayCover。 | 請在 /Applications 中安裝 PlayCover。 |
| `PlayCover をインストールして再試行してください` | Please install PlayCover and try again | 请安装 PlayCover 并重试 | 請安裝 PlayCover 並重試 |
| `PlayCover を開く (⌘⇧P)` | Open PlayCover (⌘⇧P) | 打开 PlayCover (⌘⇧P) | 打開 PlayCover (⌘⇧P) |
| `PlayCover アプリを開く (⌘⇧P)` | Open PlayCover App (⌘⇧P) | 打开 PlayCover 应用 (⌘⇧P) | 打開 PlayCover 應用 (⌘⇧P) |
| `PlayCover コンテナのアンマウントに失敗しました` | Unmounting PlayCover container failed | 卸载 PlayCover 容器失败 | 卸載 PlayCover 容器失敗 |
| `PlayCover コンテナのマウントに失敗` | Failed to mount PlayCover container | 无法挂载 PlayCover 容器 | 無法掛載 PlayCover 容器 |
| `PlayCover コンテナをアンマウントしています…` | Unmounting PlayCover container... | 正在卸载 PlayCover 容器... | 正在卸載 PlayCover 容器... |
| `PlayCover サイトを開く` | Open PlayCover site | 打开 PlayCover 网站 | 打開 PlayCover 網站 |
| `PlayCover ショートカット` | PlayCover Shortcuts | PlayCover 快捷方式 | PlayCover 快捷方式 |
| `PlayCover プロジェクト` | PlayCover Project | PlayCover项目 | PlayCover項目 |
| `PlayCover 用のディスクイメージを作成します` | Create a disk image for PlayCover | 为 PlayCover 创建磁盘映像 | 為 PlayCover 創建磁盤映像 |
| `PlayCover 用ディスクイメージが存在しません` | Disk image for PlayCover does not exist | PlayCover 的磁盘映像不存在 | PlayCover 的磁盤映像不存在 |
| `PlayCover.app が /Applications に存在する必要があります。` | PlayCover.app must be present in /Applications. | PlayCover.app 必须存在于 /Applications 中。 | PlayCover.app 必須存在於 /Applications 中。 |
| `PlayCover.app が検出できません` | PlayCover.app cannot be detected | 无法检测到 PlayCover.app | 無法檢測到 PlayCover.app |
| `PlayCover.app が見つかりません` | PlayCover.app not found | 找不到 PlayCover.app | 找不到 PlayCover.app |
| `PlayCover.app を /Applications にインストールしてください` | Install PlayCover.app in /Applications | 在 /Applications 中安装 PlayCover.app | 在 /Applications 中安裝 PlayCover.app |
| `PlayCover.app を再インストールしてください。` | Please reinstall PlayCover.app. | 请重新安装 PlayCover.app。 | 請重新安裝 PlayCover.app。 |
| `PlayCover.app を確認してください。` | Check out PlayCover.app. | 查看 PlayCover.app。 | 查看 PlayCover.app。 |
| `PlayCover.app を開く` | Open PlayCover.app | 打开 PlayCover.app | 打開 PlayCover.app |
| `PlayCoverがクラッシュしました - 再試行中 (%lld/%lld)` | PlayCover crashed - Retrying (%lld/%lld) | PlayCover 崩溃 - 正在重试 (%lld/%lld) | PlayCover 崩潰 - 正在重試 (%lld/%lld) |
| `PlayCoverでIPAをインストール中` | Installing IPA with PlayCover | 使用 PlayCover 安装 IPA | 使用 PlayCover 安裝 IPA |
| `PlayCoverでIPAをインストール中 (%lld秒経過)` | Installing IPA with PlayCover (%lld seconds elapsed) | 正在使用 PlayCover 安装 IPA(已用 %lld 秒) | 正在使用 PlayCover 安裝 IPA(已用 %lld 秒) |
| `PlayCoverでIPAをインストール中 (\(i)秒経過)` | Installing IPA with PlayCover (\(i) seconds elapsed) | 使用 PlayCover 安装 IPA(\(i) 秒已过去) | 使用 PlayCover 安裝 IPA(\(i) 秒已過去) |
| `PlayCoverの起動を待機中...` | Waiting for PlayCover to launch... | 等待 PlayCover 启动... | 等待 PlayCover 啟動... |
| `PlayCover終了検知 - 検証中...` | PlayCover quit detected - Verifying... | PlayCover 结束检测 - 正在验证中... | PlayCover 結束檢測 - 正在驗證中... |
| `Version %@ (Build %@)` | Version %@ (Build %@) | 版本%@(内部版本%@) | 版本%@(內部版本%@) |
| `\(analyzedIPAs.count) 個のアプリをインストールしますか？` | Would you like to install \(analyzedIPAs.count) apps? | 您想安装 \(analyzedIPAs.count) 个应用程序吗？ | 您想安裝 \(analyzedIPAs.count) 個應用程序嗎？ |
| `\(app.displayName) を準備しています…` | Preparing \(app.displayName)... | 正在准备 \(app.displayName)... | 正在準備 \(app.displayName)... |
| `\(app.displayName) 用のディスクイメージを作成しています…` | Creating disk image for \(app.displayName)... | 为 \(app.displayName) 创建磁盘映像... | 為 \(app.displayName) 創建磁盤映像... |
| `\(capabilities) 個` | \(capabilities) items | \(capability)个 | \(capability)個 |
| `\(completed) / \(totalItems) 完了` | \(completed) / \(totalItems) completed | \(已完成) / \(totalItems) 已完成 | \(已完成) / \(totalItems) 已完成 |
| `\(failedCount) 個のコンテナをアンマウントできませんでした。` | Failed to unmount \(failedCount) containers. | 无法卸载 \(failedCount) 个容器。 | 無法卸載 \(failedCount) 個容器。 |
| `\(failedCount) 個のコンテナを強制アンマウントできませんでした。\n\nFinderから手動でイジェクトしてから、再度保存先の変更を試してください。` | Failed to force unmount \(failedCount) containers.\n\nPlease eject it manually from Finder and try changing the save location again. | 无法强制卸载 \(failedCount) 个容器。\n\n请从 Finder 中手动将其弹出，然后再次尝试更改保存位置。 | 無法強制卸載 \(failedCount) 個容器。\n\n請從 Finder 中手動將其彈出，然後再次嘗試更改保存位置。 |
| `\(failedCount) 個のコンテナを強制アンマウントできませんでした。\n\n手動でFinderからイジェクトしてください。` | Failed to force unmount \(failedCount) containers.\n\nPlease eject it manually from Finder. | 无法强制卸载 \(failedCount) 个容器。\n\n请从 Finder 中手动将其弹出。 | 無法強制卸載 \(failedCount) 個容器。\n\n請從 Finder 中手動將其彈出。 |
| `\(failedCount) 個のディスクイメージをアンマウントできませんでした。` | Failed to unmount \(failedCount) disk images. | 无法卸载 \(failedCount) 个磁盘映像。 | 無法卸載 \(failedCount) 個磁盤映像。 |
| `\(fileType.count) 個` | \(fileType.count) items | \(fileType.count) 个 | \(fileType.count) 個 |
| `\(info.appName) をインストール中` | Installing \(info.appName) | 安装 \(info.appName) | 安裝 \(info.appName) |
| `\(ipaURL.lastPathComponent): 解析失敗 - \(error.localizedDescription)` | \(ipaURL.lastPathComponent): Parsing failed - \(error.localizedDescription) | \(ipaURL.lastPathComponent): 解析失败 - \(error.localizedDescription) | \(ipaURL.lastPathComponent): 解析失敗 - \(error.localizedDescription) |
| `\(newInstalls) 個` | \(newInstalls) new | \(newInstalls) 个 | \(newInstalls) 個 |
| `\(others) 個` | \(others) others | \(其他)件 | \(其他)件 |
| `\(request.app.displayName) の内部ストレージにデータが存在します。どのように処理しますか？` | Data exists in internal storage at \(request.app.displayName).How do you handle it? | 数据存在于内部存储中的\(request.app.displayName)。你如何处理？ | 數據存在於內部存儲中的\(request.app.displayName)。你如何處理？ |
| `\(result.totalFiles) 個` | \(result.totalFiles) files | \(result.totalFiles) 个 | \(result.totalFiles) 個 |
| `\(selectedAppInfos.count) 個のアプリをアンインストールしますか？` | Do you want to uninstall \(selectedAppInfos.count) apps? | 您想卸载\(selectedAppInfos.count)个应用程序吗？ | 您想卸載\(selectedAppInfos.count)個應用程序嗎？ |
| `\(upgrades) 個` | \(upgrades) items | \(升级)个 | \(升級)個 |
| `iOS %@+` | iOS %@+ | iOS%@+ | iOS%@+ |
| `iPhone 専用アプリ向け` | For iPhone exclusive apps | 适用于 iPhone 专属应用程序 | 適用於 iPhone 專屬應用程序 |
| `io.playcover.PlayCover 用の ASIF イメージを作成しマウントします。` | Create and mount an ASIF image for io.playcover.PlayCover. | 为 io.playcover.PlayCover 创建并安装 ASIF 映像。 | 為 io.playcover.PlayCover 創建並安裝 ASIF 映像。 |
| `macOS Tahoe 26.0 以降` | macOS Tahoe 26.0 or later | macOS Tahoe 26.0 以降 | macOS Tahoe 26.0 以降 |
| `macOS のセキュリティ設定により、保存先ディレクトリへのアクセスが拒否されました。

対処方法：
1. システム設定 > プライバシーとセキュリティ > フルディスクアクセス
2. 「+」ボタンをクリックし、PlayCover Manager を追加
3. アプリを再起動してください

パス: %@` | macOS security settings have denied access to the destination directory.

How to deal with it:
1. System Settings > Privacy and Security > Full Disk Access
2. Click the “+” button and add PlayCover Manager
3. Restart the app

Path: %@ | macOS 安全设置拒绝访问目标目录。

如何处理:
1. 系统设置 > 隐私和安全 > 全磁盘访问
2. 单击“+”按钮并添加 PlayCover Manager
3. 重新启动应用程序

路径:%@ | macOS 安全設置拒絕訪問目標目錄。

如何處理:
1. 系統設置 > 隱私和安全 > 全磁盤訪問
2. 單擊“+”按鈕並添加 PlayCover Manager
3. 重新啟動應用程序

路徑:%@ |
| `macOS のセキュリティ設定により、保存先ディレクトリへのアクセスが拒否されました。\n\n対処方法：\n1. システム設定 > プライバシーとセキュリティ > フルディスクアクセス\n2. 「+」ボタンをクリックし、PlayCover Manager を追加\n3. アプリを再起動してください\n\nパス: \(parentDir.path)` | macOS security settings have denied access to the destination directory.\n\nSolution:\n1. System Settings > Privacy & Security > Full Disk Access\n2. Click the "+" button and add PlayCover Manager\n3. Restart the app\n\nPath: \(parentDir.path) | macOS 安全设置拒绝访问目标目录。\n\n解决方案:\n1.系统设置 > 隐私和安全 > 全磁盘访问\n2.单击“+”按钮并添加 PlayCover Manager\n3.重新启动应用\n\n路径: \(parentDir.path) | macOS 安全設置拒絕訪問目標目錄。\n\n解決方案:\n1.系統設置 > 隱私和安全 > 全磁盤訪問\n2.單擊“+”按鈕並添加 PlayCover Manager\n3.重新啟動應用\n\n路徑: \(parentDir.path) |
| `macOS のバージョンが古すぎます` | macOS version is too old | macOS 版本太旧 | macOS 版本太舊 |
| `macOS をアップデート` | Update macOS | 更新macOS | 更新macOS |
| `~/Applications/PlayCover は既に削除されています。` | ~/Applications/PlayCover has already been deleted. | ~/Applications/PlayCover 已被删除。 | ~/Applications/PlayCover 已被刪除。 |
| `~/Applications/PlayCover を削除` | Remove ~/Applications/PlayCover | 删除 ~/Applications/PlayCover | 刪除 ~/Applications/PlayCover |
| `~/Applications/PlayCover を削除しました。` | ~/Applications/PlayCover has been removed. | ~/Applications/PlayCover 已删除。 | ~/Applications/PlayCover 已刪除。 |
| `~/Library/Containers/ へのマウントには「フルディスクアクセス」権限が必要です。

対処方法：
1. システム設定を開く（⌘Space で「システム設定」を検索）
2. プライバシーとセキュリティ > フルディスクアクセス
3. 「+」ボタンで PlayCover Manager を追加
4. アプリを再起動してください

マウント先: %@` | Mounting to ~/Library/Containers/ requires "Full Disk Access" permission.

How to deal with it:
1. Open System Settings (search for “System Settings” in ⌘Space)
2. Privacy and Security > Full Disk Access
3. Add PlayCover Manager using the “+” button
4. Please restart the app

Mount to: %@ | 安装到 ~/Library/Containers/ 需要“完全磁盘访问”权限。

如何处理:
1.打开系统设置(在⌘空格中搜索“系统设置”)
2. 隐私和安全 > 全磁盘访问
3. 使用“+”按钮添加 PlayCover Manager
4. 请重新启动应用程序

安装到:%@ | 安裝到 ~/Library/Containers/ 需要“完全磁盤訪問”權限。

如何處理:
1.打開系統設置(在⌘空格中搜索“系統設置”)
2. 隱私和安全 > 全磁盤訪問
3. 使用“+”按鈕添加 PlayCover Manager
4. 請重新啟動應用程序

安裝到:%@ |
| `© 2025 HEHEX8` | © 2025 HEHEX8 | © 2025 HEHEX8 | © 2025 HEHEX8 |
| `• %@` | • %@ | •%@ | •%@ |
| `※ アプリ本体 + ディスクイメージファイル` | * App body + disk image file | * 应用程序主体+磁盘镜像文件 | * 應用程序主體+磁盤鏡像文件 |
| `※ イメージ内のデータ使用量（合計に含まれません）` | *Data usage in the image (not included in total) | *图中数据使用量(不包含在总数中) | *圖中數據使用量(不包含在總數中) |
| `※ 内部データ使用量は合計に含まれません` | *Internal data usage is not included in the total | *内部数据使用量不包含在总量中 | *內部數據使用量不包含在總量中 |
| `※ 合計 = アプリ本体 + ディスクイメージファイル` | *Total = app itself + disk image file | *总计 = 应用程序本身 + 磁盘映像文件 | *總計 = 應用程序本身 + 磁盤映像文件 |
| `⚠️ 強制アンマウントはデータ損失のリスクがあります` | ⚠️ Forced unmounting risks data loss | ⚠️强制卸载有数据丢失的风险 | ⚠️強制卸載有數據丟失的風險 |
| `⚠️ 強制イジェクトはデータ損失のリスクがあります` | ⚠️ Forced eject risks data loss | ⚠️强制弹出可能导致数据丢失 | ⚠️強制彈出可能導致數據丟失 |
| `✅ %@ をアンインストールしました` | ✅ I uninstalled %@ | ✅ 我卸载了%@ | ✅ 我卸載了%@ |
| `✅ \(app.appName) をアンインストールしました` | ✅ I uninstalled \(app.appName) | ✅ 我卸载了 \(app.appName) | ✅ 我卸載了 \(app.appName) |
| `「%@」をイジェクトできませんでした。` | Failed to eject "%@". | 弹出“%@”失败。 | 彈出“%@”失敗。 |
| `「\(volumeName)」をイジェクトできませんでした。` | Failed to eject "\(volumeName)". | 无法弹出“\(volumeName)”。 | 無法彈出“\(volumeName)”。 |
| `「イジェクトしない」を選択すると、イジェクトせずにアプリを終了します` | Select "Do not eject" to exit the app without ejecting. | 选择“不弹出”以退出应用程序而不弹出。 | 選擇“不彈出”以退出應用程序而不彈出。 |
| `「完了」ボタンをクリックして PlayCover Manager を起動します。` | Click the "Finish" button to launch PlayCover Manager. | 单击“完成”按钮启动 PlayCover Manager。 | 單擊“完成”按鈕啟動 PlayCover Manager。 |
| `お使いの macOS バージョン: %@` | Your macOS version: %@ | 您的 macOS 版本:%@ | 您的 macOS 版本:%@ |
| `お使いの macOS バージョン: \(Self.currentOSVersion)` | Your macOS version: \(Self.currentOSVersion) | 您的 macOS 版本:\(Self.currentOSVersion) | 您的 macOS 版本:\(Self.currentOSVersion) |
| `このアプリで使用する言語を設定します。` | Set the language to use for this app. | 设置此应用使用的语言。 | 設置此應用使用的語言。 |
| `このアプリのディスクイメージを Finder に表示するかどうかを設定します。` | Set whether to display this app's disk image in Finder. | 设置是否在 Finder 中显示该应用程序的磁盘映像。 | 設置是否在 Finder 中顯示該應用程序的磁盤映像。 |
| `このアプリは ASIF ディスクイメージフォーマットを使用しており、macOS Tahoe (バージョン 26) 以降でのみ動作します。` | This app uses the ASIF disk image format and only works on macOS Tahoe (version 26) or later. | 此应用程序使用 ASIF 磁盘映像格式，仅适用于 macOS Tahoe(版本 26)或更高版本。 | 此應用程序使用 ASIF 磁盤映像格式，僅適用於 macOS Tahoe(版本 26)或更高版本。 |
| `このアプリは macOS Tahoe 26.0 以降が必要です` | This app requires macOS Tahoe 26.0 or later | 此应用程序需要 macOS Tahoe 26.0 或更高版本 | 此應用程序需要 macOS Tahoe 26.0 或更高版本 |
| `このアプリは macOS Tahoe 26.0 以降が必要です。

現在のバージョン: macOS %@
必要なバージョン: macOS Tahoe 26.0 以降

システムをアップデートしてから再度お試しください。` | This app requires macOS Tahoe 26.0 or later.

Current version: macOS %@
Required version: macOS Tahoe 26.0 or later

Please update your system and try again. | 此应用程序需要 macOS Tahoe 26.0 或更高版本。

当前版本:macOS %@
所需版本:macOS Tahoe 26.0 或更高版本

请更新您的系统并重试。 | 此應用程序需要 macOS Tahoe 26.0 或更高版本。

當前版本:macOS %@
所需版本:macOS Tahoe 26.0 或更高版本

請更新您的系統並重試。 |
| `このアプリは macOS Tahoe 26.0 以降が必要です。\n\n現在のバージョン: macOS \(versionString)\n必要なバージョン: macOS Tahoe 26.0 以降\n\nシステムをアップデートしてから再度お試しください。` | This app requires macOS Tahoe 26.0 or later.\n\nCurrent version: macOS \(versionString)\nRequired version: macOS Tahoe 26.0 or later\n\nPlease update your system and try again. | 此应用程序需要 macOS Tahoe 26.0 或更高版本。\n\n当前版本:macOS \(versionString)\n所需版本:macOS Tahoe 26.0 或更高版本\n\n请更新您的系统并重试。 | 此應用程序需要 macOS Tahoe 26.0 或更高版本。\n\n當前版本:macOS \(versionString)\n所需版本:macOS Tahoe 26.0 或更高版本\n\n請更新您的系統並重試。 |
| `このアプリは ~/Library/Containers/ にアクセスする必要があります。

対処方法：
1. システム設定を開く（⌘Space で「システム設定」を検索）
2. プライバシーとセキュリティ > フルディスクアクセス
3. 「+」ボタンで PlayCover Manager を追加
4. アプリを再起動してください` | This app needs to access ~/Library/Containers/.

How to fix:
1. Open System Settings (search for "System Settings" in ⌘Space)
2. Privacy and Security > Full Disk Access
3. Add PlayCover Manager using the "+" button
4. Restart the app | 此应用需要访问 ~/Library/Containers/。

如何修复：
1. 打开系统设置（在 ⌘空格 中搜索"系统设置"）
2. 隐私与安全性 > 完全磁盘访问权限
3. 使用"+"按钮添加 PlayCover Manager
4. 重新启动应用 | 此應用需要訪問 ~/Library/Containers/。

如何修復：
1. 打開系統設定（在 ⌘空格 中搜索"系統設定"）
2. 隱私與安全性 > 完全磁盤訪問權限
3. 使用"+"按鈕添加 PlayCover Manager
4. 重新啟動應用 |
| `このアプリをアンインストールしますか？` | Uninstall this app? | 您想卸载这个应用程序吗？ | 您想卸載這個應用程序嗎？ |
| `このアプリを新しくインストールします。` | Install this app anew. | 重新安装此应用程序。 | 重新安裝此應用程序。 |
| `このヘルプを表示` | Show this help | 显示此帮助 | 顯示此幫助 |
| `この操作は取り消せません。` | This action cannot be undone. | 此操作无法撤消。 | 此操作無法撤消。 |
| `すべての IPA の解析に失敗しました` | Failed to parse all IPAs | 无法解析所有 IPA | 無法解析所有 IPA |
| `すべてのアプリを終了してからアンマウントを実行してください。` | Please close all apps before unmounting. | 卸载前请关闭所有应用程序。 | 卸載前請關閉所有應用程序。 |
| `すべてのコンテナをアンマウントしてから保存先を変更します` | Unmount all containers and then change the save location | 卸载所有容器，然后更改保存位置 | 卸載所有容器，然後更改保存位置 |
| `すべてのディスクイメージをアンマウントし、アプリを終了します。

外部ドライブの場合、ドライブごと安全に取り外せる状態にします。` | Unmount all disk images and exit the app.

For external drives, make sure you can safely remove the entire drive. | 卸载所有磁盘映像并退出应用程序。

对于外部驱动器，请确保每个驱动器都可以安全移除。 | 卸載所有磁盤映像並退出應用程序。

對於外部驅動器，請確保每個驅動器都可以安全移除。 |
| `すべてのディスクイメージをアンマウントし、アプリを終了します。\n\n外部ドライブの場合、ドライブごと安全に取り外せる状態にします。` | Unmount all disk images and exit the app.\n\nFor external drives, make sure you can safely remove the entire drive. | 卸载所有磁盘映像并退出应用程序。\n\n对于外部驱动器，请确保您可以安全地删除整个驱动器。 | 卸載所有磁盤映像並退出應用程序。\n\n對於外部驅動器，請確保您可以安全地刪除整個驅動器。 |
| `すべてのディスクイメージをアンマウント中…` | Unmounting all disk images... | 正在卸载所有磁盘映像... | 正在卸載所有磁盤映像... |
| `すべての設定を初期値に戻します（ディスクイメージとアプリは削除されません）。` | Resets all settings to defaults (disk images and apps are not deleted). | 将所有设置恢复为默认值(磁盘映像和应用程序不被删除)。 | 將所有設置恢復為默認值(磁盤映像和應用程序不被刪除)。 |
| `すべてアンマウント` | Unmount All | 全部卸载 | 全部卸載 |
| `すべてアンマウント (⌘⇧U)` | Unmount all (⌘⇧U) | 全部卸载(⌘⇧U) | 全部卸載(⌘⇧U) |
| `すべてアンマウントして終了` | Unmount everything and exit | 卸载所有内容并退出 | 卸載所有內容並退出 |
| `すべてマウント解除` | Unmount All | 全部卸载 | 全部卸載 |
| `すべて終了` | Quit All | 全部退出 | 全部退出 |
| `なし` | none | 没有任何 | 沒有任何 |
| `ほとんどの Apple Silicon Mac に最適` | Suitable for most Apple Silicon Macs | 适用于大多数 Apple Silicon Mac | 適用於大多數 Apple Silicon Mac |
| `アイコンキャッシュがクリアされ、次回起動時に再読み込みされます。` | Icon cache cleared. Icons will reload on next launch. | 图标缓存将被清除并在下次启动时重新加载。 | 圖標緩存將被清除並在下次啟動時重新加載。 |
| `アイコンキャッシュをクリア` | Clear Icon Cache | 清除图标缓存 | 清除圖標緩存 |
| `アクセス権がありません` | No access rights | 无访问权限 | 無訪問權限 |
| `アップグレード` | upgrade | 升级 | 升級 |
| `アプリ:` | App: | 应用： | 應用： |
| `アプリ: %@` | App: %@ | 应用：%@ | 應用：%@ |
| `アプリ: \(app.displayName)` | App: \(app.displayName) | 应用程序:\(app.displayName) | 應用程序:\(app.displayName) |
| `アプリが再起動され、初期設定ウィザードが表示されます。` | App will restart and show the setup wizard. | 该应用程序将重新启动并显示初始设置向导。 | 該應用程序將重新啟動並顯示初始設置嚮導。 |
| `アプリが実行中のため、アンインストールできません` | Cannot uninstall because app is running | 无法卸载，因为应用程序正在运行 | 無法卸載，因為應用程序正在運行 |
| `アプリが実行中のため、インストールできません` | Cannot install because the app is running | 无法安装，因为应用程序正在运行 | 無法安裝，因為應用程序正在運行 |
| `アプリが見つかりません` | No Apps Found | 找不到应用程序 | 找不到應用程序 |
| `アプリのコンテナに内部データが残っていた場合のデフォルト処理です。ランチャーから起動する際に変更できます。` | Default behavior when internal data remains in app container. Can be changed when launching from launcher. | 当内部数据保留在应用程序容器中时，这是默认过程。从启动器启动时您可以更改它。 | 當內部數據保留在應用程序容器中時，這是默認過程。從啟動器啟動時您可以更改它。 |
| `アプリの基本情報とストレージ` | App basic information and storage | 应用基本信息及存储 | 應用基本信息及存儲 |
| `アプリの実行状態を確認中` | Checking the running status of the app | 检查应用程序的运行状态 | 檢查應用程序的運行狀態 |
| `アプリの言語` | App Language | 应用语言 | 應用語言 |
| `アプリの言語設定` | App Language | 应用语言 | 應用語言 |
| `アプリの起動に失敗` | Failed to start app | 无法启动应用程序 | 無法啟動應用程序 |
| `アプリをアンインストール` | Uninstall Apps | 卸载应用程序 | 卸載應用程序 |
| `アプリをアンインストール (⌘D)` | Uninstall App (⌘D) | 卸载应用程序 (⌘D) | 卸載應用程序 (⌘D) |
| `アプリを再起動すると、アイコンが再読み込みされます。` | Restart the app and the icon will reload. | 重新启动应用程序，图标将重新加载。 | 重新啟動應用程序，圖標將重新加載。 |
| `アプリを削除中...` | Deleting app... | 正在删除应用程序... | 正在刪除應用程序... |
| `アプリを削除中: %@` | Deleting app: %@ | 正在删除应用程序:%@ | 正在刪除應用程序:%@ |
| `アプリを削除中: \(app.appName)` | Removing app: \(app.appName) | 正在删除应用程序:\(app.appName) | 正在刪除應用程序:\(app.appName) |
| `アプリを検索` | search app | 搜索应用程序 | 搜索應用程序 |
| `アプリを検索中...` | Searching for apps... | 正在搜索应用程序... | 正在搜索應用程序... |
| `アプリを終了しています...` | Terminating app... | 正在终止应用... | 正在終止應用... |
| `アプリを終了してから再度お試しください` | Please close the app and try again | 请关闭应用程序并重试 | 請關閉應用程序並重試 |
| `アプリを終了してから再度お試しください(句点付き)` | Please close the app and try again. | 请关闭应用程序并重试。 | 請關閉應用程序並重試。 |
| `アプリを解析して詳細情報を表示します` | Analyze your app and view detailed information | 分析您的应用程序并查看详细信息 | 分析您的應用程序並查看詳細信息 |
| `アプリアイコンのキャッシュをクリアします。次回起動時に再読み込みされます。` | Clears app icon cache. Icons will reload on next launch. | 清除应用程序图标缓存。它将在下次启动时重新加载。 | 清除應用程序圖標緩存。它將在下次啟動時重新加載。 |
| `アプリアンインストーラー` | App Uninstaller | 应用程序卸载程序 | 應用程序卸載程序 |
| `アプリコンテナをアンマウントしています…` | Unmounting app container... | 正在卸载应用程序容器... | 正在卸載應用程序容器... |
| `アプリコンテナを確認しています…` | Checking app container... | 正在检查应用容器... | 正在檢查應用容器... |
| `アプリサイズ:` | App Size: | 应用程序大小: | 應用程序大小: |
| `アプリフォルダを開く` | Open app folder | 打开应用程序文件夹 | 打開應用程序文件夾 |
| `アプリ一覧の取得に失敗` | Failed to get list of apps | 获取应用列表失败 | 獲取應用列表失敗 |
| `アプリ一覧の更新に失敗` | Failed to update app list | 更新应用列表失败 | 更新應用列表失敗 |
| `アプリ一覧を更新` | Updated app list | 更新的应用程序列表 | 更新的應用程序列表 |
| `アプリ一覧を読み込み中...` | Loading app list... | 正在加载应用程序列表... | 正在加載應用程序列表... |
| `アプリ名` | App name | 应用名称 | 應用名稱 |
| `アプリ名の取得に失敗しました` | Failed to get app name | 获取应用名称失败 | 獲取應用名稱失敗 |
| `アプリ固有の設定` | App-Specific Settings | 应用程序特定设置 | 應用程序特定設置 |
| `アプリ情報が見つかりません` | App information not found | 未找到应用程序信息 | 未找到應用程序信息 |
| `アプリ情報を取得しています…` | Getting app information... | 正在获取应用程序信息... | 正在獲取應用程序信息... |
| `アプリ本体` | App itself | 应用程序本身 | 應用程序本身 |
| `アプリ本体を Finder で表示` | Show App in Finder | 在 Finder 中显示应用 | 在 Finder 中顯示應用 |
| `アプリ本体を表示` | Show App | 显示应用 | 顯示應用 |
| `アプリ検出 - 署名完了を待機中...` | App detected - Waiting for signing to complete... | 检测到应用 - 等待签名完成... | 檢測到應用 - 等待簽名完成... |
| `アプリ概要` | App Overview | 应用概述 | 應用概述 |
| `アプリ解析` | App analysis | 应用分析 | 應用分析 |
| `アプリ設定` | App settings | 应用程序设置 | 應用程序設置 |
| `アプリ設定を削除中...` | Deleting app settings... | 正在删除应用程序设置... | 正在刪除應用程序設置... |
| `アプリ設定を閉じる (Esc)` | Close app settings (Esc) | 关闭应用程序设置 (Esc) | 關閉應用程序設置 (Esc) |
| `アプリ間を移動` | Move between apps | 在应用程序之间移动 | 在應用程序之間移動 |
| `アンインストール` | Uninstall | 卸载 | 解除安裝 |
| `アンインストール (%lld 個)` | Uninstall (%lld) | 卸载(%lld 件) | 卸載(%lld 件) |
| `アンインストール (\(selectedApps.count) 個)` | Uninstall (\(selectedApps.count) pieces) | 卸载(\(selectedApps.count) 件) | 卸載(\(selectedApps.count) 件) |
| `アンインストール中` | Uninstalling | 卸载 | 解除安裝 |
| `アンインストール中(進行中)` | Uninstalling... | 正在卸载... | 正在卸載... |
| `アンインストール可能なアプリがありません` | No apps available to uninstall | 没有可以卸载的应用程序 | 沒有可以卸載的應用程序 |
| `アンインストール完了` | Uninstallation completed | 卸载完成 | 卸載完成 |
| `アンインストール結果` | Uninstall Results | 卸载结果 | 卸載結果 |
| `アンマウントされたボリューム: %lld 個` | Unmounted volumes: %lld | 已卸载的卷:%lld | 已卸載的捲:%lld |
| `アンマウントされたボリューム: \(unmountedCount) 個` | Unmounted volumes: \(unmountedCount) volumes | 已卸载的卷:\(unmountedCount) 个卷 | 已卸載的捲:\(unmountedCount) 個卷 |
| `アンマウントして終了` | Unmount and exit | 卸载并退出 | 卸載並退出 |
| `アンマウントして続行` | unmount and continue | 卸载并继续 | 卸載並繼續 |
| `アンマウントに失敗しました` | Unmount failed | 卸载失败 | 卸載失敗 |
| `アンマウント中` | Unmounting | 卸载 | 解除安裝 |
| `アンマウント処理がタイムアウトしました` | Unmount processing timed out | 卸载处理超时 | 卸載處理超時 |
| `アンマウント処理を完了しています…` | Completing unmount process... | 正在完成卸载过程... | 正在完成卸載過程... |
| `アンマウント処理を続行しています…` | Continuing unmount process... | 正在继续卸载过程... | 正在繼續卸載過程... |
| `アンマウント完了` | Unmount completed | 卸载完成 | 卸載完成 |
| `アーキテクチャ` | architecture | 建筑学 | 建築學 |
| `イジェクト` | eject | 喷射 | 噴射 |
| `イジェクトしない` | do not eject | 不弹出 | 不彈出 |
| `イジェクト完了` | Ejection Complete | 弹出完成 | 彈出完成 |
| `イメージ:` | Image: | 镜像： | 鏡像： |
| `インストールが完了していません` | Installation not completed | 安装未完成 | 安裝未完成 |
| `インストールする IPA ファイルを選択してください` | Select IPA file to install | 选择要安装的IPA文件 | 選擇要安裝的IPA文件 |
| `インストールエラー: \(msg)` | Installation error: \(msg) | 安装错误:\(msg) | 安裝錯誤:\(msg) |
| `インストール中` | Installing | 安装中 | 安裝中 |
| `インストール完了` | Installation Complete | 安装完成 | 安裝完成 |
| `インストール済みアプリ (%lld 個)` | Installed Apps (%lld) | 已安装的应用程序 (%lld) | 已安裝的應用程序 (%lld) |
| `インストール済みアプリ (\(apps.count) 個)` | Installed apps (\(apps.count)) | 已安装的应用程序 (\(apps.count)) | 已安裝的應用程序 (\(apps.count)) |
| `インストール済みアプリがありません` | No Installed Apps | 没有安装的应用程序 | 沒有安裝的應用程序 |
| `インストール結果` | Installation result | 安装结果 | 安裝結果 |
| `インストール開始` | Start installation | 开始安装 | 開始安裝 |
| `エラー: %@` | Error: %@ | 错误: %@ | 錯誤: %@ |
| `エラー: \(error.localizedDescription)` | Error: \(error.localizedDescription) | 错误:\(error.localizedDescription) | 錯誤:\(error.localizedDescription) |
| `カスタム` | custom | 风俗 | 風俗 |
| `カメラ` | camera | 相机 | 相機 |
| `カレンダー` | calendar | 日历 | 日曆 |
| `キャッシュ` | Cache | 缓存 | 快取 |
| `キャッシュをクリアしました` | cleared cache | 清除缓存 | 清除緩存 |
| `キャッシュをクリアしますか?` | Do you want to clear your cache? | 您想清除缓存吗？ | 您想清除緩存嗎？ |
| `キャッシュを削除中...` | Deleting cache... | 正在删除缓存... | 正在刪除緩存... |
| `キャッシュを更新中...` | Updating cache... | 正在更新缓存... | 正在更新緩存... |
| `キャンセル` | Cancel | 取消 | 取消 |
| `キーボードショートカット` | keyboard shortcuts | 键盘快捷键 | 鍵盤快捷鍵 |
| `クリア` | clear | 清除 | 清除 |
| `グローバル` | global | 全球的 | 全球的 |
| `グローバル設定に戻す` | Revert to global settings | 恢复到全局设置 | 恢復到全局設置 |
| `グローバル設定を使用` | Use global settings | 使用全局设置 | 使用全局設置 |
| `コンテナ: マウント済み` | Container: Mounted | 容器:已安装 | 容器:已安裝 |
| `コンテナを Finder で表示` | Show Container in Finder | 在 Finder 中显示容器 | 在 Finder 中顯示容器 |
| `コンテナ確認中...` | Checking container... | 检查容器... | 檢查容器... |
| `コード署名` | code signing | 代码签名 | 代碼簽名 |
| `システムデフォルト` | System Default | 系统默认 | 系統默認 |
| `システムプロセス（cfprefsdなど）がファイルを使用している可能性があります。` | A system process (such as cfprefsd) may be using the file. | 系统进程(例如 cfprefsd)可能正在使用该文件。 | 系統進程(例如 cfprefsd)可能正在使用該文件。 |
| `システム要件` | System Requirements | 系统要求 | 系統要求 |
| `システム設定に従う` | Follow System | 遵循系统设置 | 遵循系統設置 |
| `システム設定を開く` | Open system settings | 打开系统设置 | 打開系統設置 |
| `ショートカットを削除中...` | Removing shortcuts... | 正在删除快捷方式... | 正在刪除快捷方式... |
| `ストレージ` | Storage | 贮存 | 貯存 |
| `ストレージ内訳` | Storage breakdown | 存储故障 | 存儲故障 |
| `ストレージ情報` | Storage information | 存储信息 | 存儲信息 |
| `セットアップが完了しました。` | Setup is complete. | 设置完成。 | 設置完成。 |
| `セットアップを準備しています…` | Preparing setup... | 正在准备设置... | 正在準備設置... |
| `セットアップ完了` | Setup complete | 设置完成 | 設置完成 |
| `タイムアウト` | timeout | 暂停 | 暫停 |
| `ダウン` | Down | 停止 | 停止 |
| `ダウングレード` | downgrade | 降级 | 降級 |
| `ディスクイメージ` | disk image | 磁盘映像 | 磁盤映像 |
| `ディスクイメージ (マウント中)` | Disk image (mounting) | 磁盘映像(安装) | 磁盤映像(安裝) |
| `ディスクイメージ(ラベル)` | Disk Image: | 磁盘镜像: | 磁盤鏡像: |
| `ディスクイメージが存在しません` | Disk image does not exist | 磁盘映像不存在 | 磁盤映像不存在 |
| `ディスクイメージが見つかりません` | Disk image not found | 未找到磁盘映像 | 未找到磁盤映像 |
| `ディスクイメージのアンマウントに失敗` | Failed to unmount disk image | 卸载磁盘映像失败 | 卸載磁盤映像失敗 |
| `ディスクイメージのアンマウントに時間がかかっています。

強制終了しますか？（データが失われる可能性があります）` | Unmounting disk images is taking a long time.

Force quit? (Data may be lost) | 卸载磁盘映像需要很长时间。

您想强制退出吗？(数据可能会丢失) | 卸載磁盤映像需要很長時間。

您想強制退出嗎？(數據可能會丟失) |
| `ディスクイメージのアンマウントに時間がかかっています。\n\n強制終了しますか？（データが失われる可能性があります）` | Unmounting disk images is taking a long time.\n\nForce quit? (Data may be lost) | 卸载磁盘映像需要很长时间。\n\n您想强制退出吗？(数据可能会丢失) | 卸載磁盤映像需要很長時間。\n\n您想強制退出嗎？(數據可能會丟失) |
| `ディスクイメージの作成に失敗` | Failed to create disk image | 创建磁盘映像失败 | 創建磁盤映像失敗 |
| `ディスクイメージの保存先` | Where to save the disk image | 磁盘映像的保存位置 | 磁盤映像的保存位置 |
| `ディスクイメージの保存先が未設定` | Disk image save destination not set | 未设置磁盘映像保存目的地 | 未設置磁盤映像保存目的地 |
| `ディスクイメージの保存先を選択してください` | Choose where to save the disk image | 选择保存磁盘映像的位置 | 選擇保存磁盤映像的位置 |
| `ディスクイメージの準備` | Preparing the disk image | 准备磁盘映像 | 準備磁盤映像 |
| `ディスクイメージの準備に失敗` | Failed to prepare disk image | 准备磁盘映像失败 | 準備磁盤映像失敗 |
| `ディスクイメージは大容量になる場合があります。
十分な空き容量のあるドライブを選択してください。` | Disk images can become very large.
Please select a drive with sufficient free space. | 磁盘映像可能很大。
请选择具有足够可用空间的驱动器。 | 磁盤映像可能很大。
請選擇具有足夠可用空間的驅動器。 |
| `ディスクイメージは大容量になる場合があります。\n十分な空き容量のあるドライブを選択してください。` | Disk images can become very large.\nPlease select a drive with sufficient free space. | 磁盘映像可能很大。\n请选择具有足够可用空间的驱动器。 | 磁盤映像可能很大。\n請選擇具有足夠可用空間的驅動器。 |
| `ディスクイメージをアンマウントしています…` | Unmounting disk image... | 正在卸载磁盘映像... | 正在卸載磁盤映像... |
| `ディスクイメージをアンマウントしました。` | I unmounted the disk image. | 我卸载了磁盘映像。 | 我卸載了磁盤映像。 |
| `ディスクイメージをアンマウント中...` | Unmounting disk image... | 正在卸载磁盘映像... | 正在卸載磁盤映像... |
| `ディスクイメージを作成しています…` | Creating disk image... | 正在创建磁盘映像... | 正在創建磁盤映像... |
| `ディスクイメージを削除中...` | Deleting disk image... | 正在删除磁盘映像... | 正在刪除磁盤映像... |
| `ディスクイメージを表示` | Show Disk Image | 显示磁盘镜像 | 顯示磁盤鏡像 |
| `ディスクイメージ作成` | Disk image creation | 磁盘镜像创建 | 磁盤鏡像創建 |
| `ディスクイメージ作成エラー: \(msg)` | Disk image creation error: \(msg) | 磁盘映像创建错误:\(msg) | 磁盤映像創建錯誤:\(msg) |
| `ディスクイメージ作成中` | Creating disk image | 创建磁盘映像 | 創建磁盤映像 |
| `ディスクイメージ保存先` | Disk image storage destination | 磁盘映像存储目的地 | 磁盤映像存儲目的地 |
| `ディスクイメージ保存先にアクセスできません` | Unable to access disk image storage location | 无法访问磁盘映像存储位置 | 無法訪問磁盤映像存儲位置 |
| `ディスクイメージ保存先を選択してください` | Please select the disk image save destination | 请选择磁盘映像保存目的地 | 請選擇磁盤映像保存目的地 |
| `ディレクトリが存在しません` | Directory does not exist | 目录不存在 | 目錄不存在 |
| `ディレクトリは作成できましたが、ファイルの書き込みテストに失敗しました。

対処方法：
• 設定画面で別の保存先を選択してください
• 外部ドライブの場合、マウントされているか確認してください
• ドライブが読み取り専用でないか確認してください

パス: %@
エラー: %@` | I was able to create the directory, but the file write test failed.

How to deal with it:
• Please select a different save location on the settings screen
• If it's an external drive, make sure it's mounted
• Check if the drive is not read-only

Path: %1$@
Error: %2$@ | 我能够创建目录，但文件写入测试失败。

如何处理:
• 请在设置屏幕上选择不同的保存位置
• 如果是外部驱动器，请确保已安装它
• 检查驱动器是否不是只读的

路径:%1$@
错误:%2$@ | 我能夠創建目錄，但文件寫入測試失敗。

如何處理:
• 請在設置屏幕上選擇不同的保存位置
• 如果是外部驅動器，請確保已安裝它
• 檢查驅動器是否不是只讀的

路徑:%1$@
錯誤:%2$@ |
| `ディレクトリは作成できましたが、ファイルの書き込みテストに失敗しました。\n\n対処方法：\n• 設定画面で別の保存先を選択してください\n• 外部ドライブの場合、マウントされているか確認してください\n• ドライブが読み取り専用でないか確認してください\n\nパス: \(parentDir.path)\nエラー: \(error.localizedDescription)` | I was able to create the directory, but the file write test failed.\n\nSolution:\n• Please select a different destination in the settings screen.\n• If it is an external drive, make sure it is mounted.\n• Make sure the drive is not read-only.\n\nPath: \(parentDir.path)\nError: \(error.localizedDescription) | 我能够创建目录，但文件写入测试失败。\n\n解决方案:\n• 请在设置屏幕中选择不同的目标。\n• 如果是外部驱动器，请确保已安装它。\n• 确保驱动器不是只读的。\n\n路径: \(parentDir.path)\n错误: \(error.localizedDescription) | 我能夠創建目錄，但文件寫入測試失敗。\n\n解決方案:\n• 請在設置屏幕中選擇不同的目標。 \n• 如果是外部驅動器，請確保已安裝它。 \n• 確保驅動器不是只讀的。 \n\n路徑: \(parentDir.path)\n錯誤: \(error.localizedDescription) |
| `デバイスIDの取得に失敗` | Failed to get device ID | 获取设备ID失败 | 獲取設備ID失敗 |
| `デバイスパスの取得に失敗` | Failed to get device path | 获取设备路径失败 | 獲取設備路徑失敗 |
| `デバッグコンソールで起動` | Start in debug console | 在调试控制台中启动 | 在調試控制台中啟動 |
| `データ` | data | 数据 | 數據 |
| `データの保存先が外部ドライブまたはネットワークドライブ（%@）にあります。

ドライブをイジェクトしますか？` | The data storage location is on an external or network drive (%@).

Would you like to eject the drive? | 数据存储在外部驱动器或网络驱动器 (%@) 上。

您想弹出驱动器吗？ | 數據存儲在外部驅動器或網絡驅動器 (%@) 上。

您想彈出驅動器嗎？ |
| `データの保存先が外部ドライブまたはネットワークドライブ（\(volumeName)）にあります。\n\nドライブをイジェクトしますか？` | The data is saved to an external drive or network drive (\(volumeName)).\n\nDo you want to eject the drive? | 数据保存到外部驱动器或网络驱动器 (\(volumeName))。\n\n您想弹出驱动器吗？ | 數據保存到外部驅動器或網絡驅動器 (\(volumeName))。\n\n您想彈出驅動器嗎？ |
| `データ処理` | Data Handling | 数据处理 | 數據處理 |
| `ドライブが接続されていないか、パスが無効です。
別の保存先を選択してください。` | The drive is not connected or the path is invalid.
Please select a different storage location. | 驱动器未连接或路径无效。
请选择其他目的地。 | 驅動器未連接或路徑無效。
請選擇其他目的地。 |
| `ドライブが接続されていないか、パスが無効です。\n別の保存先を選択してください。` | The drive is not connected or the path is invalid.\nPlease select a different storage location. | 驱动器未连接或路径无效。\n请选择另一个保存目的地。 | 驅動器未連接或路徑無效。\n請選擇另一個保存目的地。 |
| `ドライブのイジェクトに失敗` | Drive eject failed | 驱动器弹出失败 | 驅動器彈出失敗 |
| `ドライブの取り外し完了` | Drive removal completed | 驱动器删除完成 | 驅動器刪除完成 |
| `ドライブをイジェクト中` | Ejecting drive | 正在弹出驱动器 | 正在彈出驅動器 |
| `ドライブを強制イジェクトできませんでした。

Finderから手動でイジェクトしてください。` | Failed to force eject the drive.

Please eject it manually from Finder. | 无法强制弹出驱动器。

请从 Finder 中手动将其弹出。 | 無法強制彈出驅動器。

請從 Finder 中手動將其彈出。 |
| `ドライブを強制イジェクトできませんでした。\n\nFinderから手動でイジェクトしてください。` | Failed to force eject the drive.\n\nPlease eject it manually from Finder. | 无法强制弹出驱动器。\n\n请从 Finder 中手动将其弹出。 | 無法強制彈出驅動器。\n\n請從 Finder 中手動將其彈出。 |
| `ドライブ上のボリュームが使用中の可能性があります。` | The volume on the drive may be in use. | 驱动器上的卷可能正在使用中。 | 驅動器上的捲可能正在使用中。 |
| `ナビゲーション` | navigation | 导航 | 導航 |
| `バイト` | byte | 字节 | 位元組 |
| `バイナリサイズ` | binary size | 二进制大小 | 二進制大小 |
| `バイナリ情報` | binary information | 二进制信息 | 二進制信息 |
| `バックグラウンド位置情報` | Background location information | 后台位置信息 | 後台位置信息 |
| `バックグラウンド取得` | Background acquisition | 后台采集 | 後台採集 |
| `バックグラウンド音声` | background audio | 背景音频 | 背景音頻 |
| `バンドル構造` | bundle structure | 束结构 | 束結構 |
| `バージョン` | Version | 版本 | 版本 |
| `バージョン %@` | Version %@ | 版本 %@ | 版本 %@ |
| `バージョン \(version)` | version \(version) | 版本 \(版本) | 版本 \(版本) |
| `バージョン(ラベル)` | Version: | 版本: | 版本(標籤) |
| `パスが存在しません` | path does not exist | 路径不存在 | 路徑不存在 |
| `パッケージ種別` | Package type | 封装类型 | 封裝類型 |
| `ビルド番号` | build number | 内部版本号 | 內部版本號 |
| `ファイルサイズ` | file size | 文件大小 | 文件大小 |
| `ファイルサイズ(ラベル)` | File size: | 文件大小: | 文件大小(標籤) |
| `ファイル名` | file name | 文件名 | 文件名 |
| `ファイル種別` | File type | 文件类型 | 文件類型 |
| `フォーカスされたアプリを起動` | Launch focused app | 启动重点应用程序 | 啟動重點應用程序 |
| `フォーカスをクリア` | clear focus | 清晰的焦点 | 清晰的焦點 |
| `フルディスクアクセス権限が必要です` | Full Disk Access permission required | 需要完全磁盘访问权限 | 需要完全磁盤訪問權限 |
| `フレームワーク (%lld)` | Framework (%lld) | 框架 (%lld) | 框架 (%lld) |
| `フレームワーク (\(result.frameworks.count))` | Frameworks (\(result.frameworks.count)) | 框架 (\(result.frameworks.count)) | 框架 (\(result.frameworks.count)) |
| `プロセス終了 (終了コード:` | Process terminated (exit code: | 进程已终止（退出代码： | 進程已終止（退出代碼： |
| `プロセス終了 (終了コード: $EXIT_CODE)` | Process exit (exit code: $EXIT_CODE) | 进程退出(退出代码:$EXIT_CODE) | 進程退出(退出代碼:$EXIT_CODE) |
| `マイク` | microphone | 麦克风 | 麥克風 |
| `マウントエラー: \(msg)` | Mount error: \(msg) | 安装错误:\(msg) | 安裝錯誤:\(msg) |
| `マウント中` | Mounting | 安装 | 安裝 |
| `マウント中: %lld 個のコンテナ` | Mounted: %lld containers | 安装:%lld 个容器 | 安裝:%lld 個容器 |
| `マウント中: \(mountedCount) 個のコンテナ` | Mounting: \(mountedCount) containers | 挂载:\(mountedCount)个容器 | 掛載:\(mountedCount)個容器 |
| `マウント先へのアクセス権限がありません` | You do not have permission to access the mount destination | 您无权访问挂载目标 | 您無權訪問掛載目標 |
| `マウント完了` | Mount completed | 挂载完成 | 掛載完成 |
| `マウント時に Finder に表示しない (-nobrowse)` | Hide from Finder when mounted (-nobrowse) | 安装时不显示在 Finder 中 (-nobrowse) | 安裝時不顯示在 Finder 中 (-nobrowse) |
| `マウント状態` | Mount status | 挂载状态 | 掛載狀態 |
| `マウント設定` | Mount Settings | 安装设置 | 安裝設置 |
| `メニュー` | Menu | 菜单 | 菜單 |
| `メニュー (⌘M)` | Menu (⌘M) | 菜单 (⌘M) | 菜單 (⌘M) |
| `メニューを表示` | show menu | 显示菜单 | 顯示菜單 |
| `メニューを開く/閉じる` | Open/close menu | 打开/关闭菜单 | 打開/關閉菜單 |
| `メンテナンス` | Maintenance | 维护 | 維護 |
| `モーションセンサー` | motion sensor | 运动传感器 | 運動傳感器 |
| `リストから外す` | Remove from List | 从列表中删除 | 從列表中刪除 |
| `リセット` | Reset | 重置 | 重置 |
| `リマインダー` | reminder | 提醒 | 提醒 |
| `リモート通知` | remote notification | 远程通知 | 遠程通知 |
| `リンク` | Links | 关联 | 關聯 |
| `・` |  |  |  |
| `一般` | General | 一般 | 一般 |
| `一部のディスクイメージをアンマウントできません` | Unable to unmount some disk images | 无法卸载某些磁盘映像 | 無法卸載某些磁盤映像 |
| `一部のディスクイメージをアンマウントできませんでした。

手動でアンマウントしてから再度終了してください。` | Some disk images could not be unmounted.

Please unmount them manually and try quitting again. | 无法卸载部分磁盘镜像。

请手动卸载后再次尝试退出。 | 無法卸載部分磁盤鏡像。

請手動卸載後再次嘗試退出。 |
| `上書き` | Overwrite | 覆盖 | 覆蓋 |
| `上書き・その他` | Overwrite/Other | 覆盖/其他 | 覆蓋/其他 |
| `下のボタンから IPA をインストールしてください。` | Please install IPA from the button below. | 请通过下面的按钮安装 IPA。 | 請通過下面的按鈕安裝 IPA。 |
| `不明` | not clear | 不清楚 | 不清楚 |
| `中国語 (簡体字)` | Chinese (Simplified) | 中文 (简体) | 中文 (簡體) |
| `中国語 (繁体字)` | Chinese (Traditional) | 中文 (繁体) | 中文 (繁體) |
| `互換性重視` | interchangeability emphasis | 互换性重视 | 強調兼容性 |
| `今すぐ再起動` | Restart Now | 立即重新启动 | 立即重新啟動 |
| `以下のアプリが実行中です。` | The following apps are running: | 以下应用正在运行： | 以下應用正在運行： |
| `以下のアプリが実行中です。アンマウントするには先にこれらのアプリを終了してください。\n\n\(appsList)` | The following apps are currently running.Please close these apps before unmounting.\n\n\(appsList) | 当前正在运行以下应用程序。卸载前请关闭这些应用程序。\n\n\(应用程序列表) | 當前正在運行以下應用程序。卸載前請關閉這些應用程序。\n\n\(應用程序列表) |
| `任意のキーを押してウィンドウを閉じる...` | Press any key to close the window... | 按任意键关闭窗口... | 按任意鍵關閉窗口... |
| `任意のキーを押してウィンドウを閉じる... ` | Press any key to close the window... | 按任意键关闭窗口... | 按任意鍵關閉窗口... |
| `位置情報（使用中）` | Location information (in use) | 位置情报(使用中) | 位置信息(使用中) |
| `位置情報（常に）` | Location information (always) | 位置信息(始终) | 位置信息(始終) |
| `何もしない` | do nothing | 什么都不做 | 什麼都不做 |
| `何もせずにマウント` | Mount without changes | 不执行任何操作即可安装 | 不執行任何操作即可安裝 |
| `作成` | create | 创造 | 創造 |
| `作成完了` | Finished | 作成完了 | 創建完成 |
| `使用中: %@` | In Use: %@ | 使用中: %@ | 使用中: %@ |
| `使用容量` | Usage capacity | 使用容量 | 使用容量 |
| `使用量` | Usage | 使用量 | 使用量 |
| `保存先` | Location | 保存先 | 保存先 |
| `保存先が選択されていません` | No save destination selected | 未选择保存目的地 | 未選擇保存目的地 |
| `保存先に書き込み権限がありません` | You do not have write permission to save destination | 您没有保存目的地的写入权限 | 您沒有保存目的地的寫入權限 |
| `保存先のドライブが接続されていない可能性があります。

保存先: %@` | The destination drive may not be connected.

Save to: %@ | 目标驱动器可能未连接。

保存至:%@ | 目標驅動器可能未連接。

保存至:%@ |
| `保存先のドライブが接続されていない可能性があります。\n\n保存先: \(baseDirectory.path)` | The destination drive may not be connected.\n\nSave location: \(baseDirectory.path) | 目标驱动器可能未连接。\n\n保存位置:\(baseDirectory.path) | 目標驅動器可能未連接。\n\n保存位置:\(baseDirectory.path) |
| `保存先の選択` | Select save destination | 选择保存目的地 | 選擇保存目的地 |
| `保存先へのアクセス権限がありません` | You do not have permission to access the storage location | 您无权访问存储位置 | 您無權訪問存儲位置 |
| `保存先を変更` | Change save destination | 更改保存目的地 | 更改保存目的地 |
| `保存先を変更(アクション)` | Change Location... | 更改保存目的地... | 更改保存目的地... |
| `保存先を変更すると、PlayCover コンテナのマウント状態を確認し、必要に応じて再マウントします。` | Changing the location will check PlayCover container mount status and remount if necessary. | 当您更改存储位置时，请检查 PlayCover 容器的安装状态，并在必要时重新安装。 | 當您更改存儲位置時，請檢查 PlayCover 容器的安裝狀態，並在必要時重新安裝。 |
| `保存先を変更すると、マウント中のコンテナをすべてアンマウントしてから新しい保存先に環境を構築します。` | If you change the storage location, all mounted containers will be unmounted and the environment will be built in the new storage location. | 如果更改存储位置，所有已挂载的容器将被卸载，环境将在新的存储位置构建。 | 如果更改存儲位置，所有已掛載的容器將被卸載，環境將在新的存儲位置構建。 |
| `保存先を変更するには、先にこれらのアプリを終了してください。

%@` | To change the save location, please close these apps first.

%@ | 要更改保存位置，请先关闭这些应用程序。

%@ | 要更改保存位置，請先關閉這些應用程序。

%@ |
| `保存先を変更するには、先にこれらのアプリを終了してください。\n\n\(appsList)` | To change the save location, please close these apps first.\n\n\(appsList) | 要更改保存位置，请先关闭这些应用程序。\n\n\(应用程序列表) | 要更改保存位置，請先關閉這些應用程序。\n\n\(應用程序列表) |
| `保存先を変更するには、現在マウント中のすべてのディスクイメージをアンマウントする必要があります。` | To change the storage location, you must unmount all currently mounted disk images. | 要更改存储位置，您必须卸载当前安装的所有磁盘映像。 | 要更改存儲位置，您必須卸載當前安裝的所有磁盤映像。 |
| `保存先を選択` | Select save destination | 选择保存目的地 | 選擇保存目的地 |
| `先にディスクイメージを作成してください。` | Please create a disk image first. | 请先创建磁盘映像。 | 請先創建磁盤映像。 |
| `内部データ (参考情報)` | Internal data (reference information) | 内部数据(参考信息) | 內部數據(參考信息) |
| `内部データが見つかりました` | Internal data found | 找到内部数据 | 找到內部數據 |
| `内部データのデフォルト処理` | Default Internal Data Handling | 内部数据的默认处理 | 內部數據的默認處理 |
| `内部データの削除に失敗` | Failed to delete internal data | 删除内部数据失败 | 刪除內部數據失敗 |
| `内部データはそのまま残してマウントします` | Mount leaving internal data intact | 安装保持内部数据完好无损 | 安裝保持內部數據完好無損 |
| `内部データをコンテナに統合してから削除してマウントします` | Integrate internal data into container then remove and mount | 将内部数据集成到容器中然后移除并挂载 | 將內部數據集成到容器中然後移除並掛載 |
| `内部データを処理しています…` | Processing internal data... | 处理内部数据... | 處理內部數據... |
| `内部データを破棄` | Discard internal data | 丢弃内部数据 | 丟棄內部數據 |
| `内部データを破棄してからマウント` | Discard internal data before mount | 丢弃内部数据后挂载 | 丟棄內部數據後掛載 |
| `内部データを破棄してから新しくマウントします` | Discard internal data and mount a new one | 丢弃内部数据并安装新数据 | 丟棄內部數據並安裝新數據 |
| `内部データを統合` | Integrate internal data | 整合内部数据 | 整合內部數據 |
| `内部データを統合してから削除しマウント` | Merge internal data, then delete and mount | 整合内部数据，然后删除并挂载 | 整合內部數據，然後刪除並掛載 |
| `内部データ使用量 (参考)` | Internal data usage (reference) | 内部数据使用(参考) | 內部數據使用(參考) |
| `内部データ処理に失敗` | Internal data processing failed | 内部数据处理失败 | 內部數據處理失敗 |
| `内部データ処理の既定値` | Internal data processing defaults | 内部数据处理默认值 | 內部數據處理默認值 |
| `内部データ処理方法` | Internal data processing method | 内部数据处理方法 | 內部數據處理方法 |
| `再インストール` | reinstall | 重新安装 | 重新安裝 |
| `再解析` | Analyze again | 再解析 | 重新分析 |
| `再試行` | Try again | 再试行 | 重試 |
| `写真ライブラリ` | photo library | 照片库 | 照片庫 |
| `処理中(和点)` | Processing... | 加工... | 處理(求和點) |
| `処理中...` | Processing... | 加工... | 加工... |
| `初期セットアップが必要です` | Initial setup required | 需要初始设置 | 需要初始設置 |
| `初期設定ウィザードを開いて保存先を変更します` | Opens setup wizard to change storage location | 打开初始设置向导并更改保存位置 | 打開初始設置嚮導並更改保存位置 |
| `別の IPA を追加` | Add another IPA | 添加另一个 IPA | 添加另一個 IPA |
| `別のキーワードで検索してみてください。` | Please try searching with a different keyword. | 请尝试使用不同的关键字进行搜索。 | 請嘗試使用不同的關鍵字進行搜索。 |
| `削除失敗` | Deletion Failed | 删除失败 | 刪除失敗 |
| `削除完了` | Deletion Complete | 删除完成 | 刪除完成 |
| `前回起動したアプリ` | Last launched app | 最后启动的应用程序 | 最後啟動的應用程序 |
| `合計:` | Total: | 全部的: | 全部的: |
| `合計: %@` | Total: %@ | 全部的: %@ | 全部的: %@ |
| `合計: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))` | Total: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)) | 总计: \(ByteCountFormatter.string(fromByteCount:totalSize, countStyle:.file)) | 總計:\(ByteCountFormatter.string(fromByteCount:totalSize, countStyle:.file)) |
| `合計サイズ:` | Total size: | 总尺寸: | 總尺寸: |
| `合計使用容量:` | Total usage capacity: | 合计使用容量: | 使用的總容量: |
| `合計容量` | Total capacity | 总容量 | 總容量 |
| `同じバージョンで上書きインストールします。` | Overwrite installation with the same version. | 使用相同版本覆盖安装。 | 使用相同版本覆蓋安裝。 |
| `問題を報告` | Report a problem | 报告问题 | 報告問題 |
| `基本情報` | Basic information | 基本情报 | 基本信息 |
| `外部ストレージの使用を推奨` | External storage recommended | 推荐外部存储 | 推薦外部存儲 |
| `外部ドライブ「%@」を安全に取り外せる状態にしました。` | External drive "%@" is now safe to remove. | 现在可以安全删除外部驱动器“%@”。 | 現在可以安全刪除外部驅動器“%@”。 |
| `外部ドライブ「\(driveName)」を安全に取り外せる状態にしました。` | The external drive "\(driveName)" is now safe to remove. | 现在可以安全删除外部驱动器“\(driveName)”。 | 現在可以安全刪除外部驅動器“\(driveName)”。 |
| `外部ドライブのデバイスパスを取得できませんでした。

Finderから手動でイジェクトしてください。` | Failed to obtain device path for external drive.

Please eject it manually from Finder. | 无法获取外部驱动器的设备路径。

请从 Finder 中手动将其弹出。 | 無法獲取外部驅動器的設備路徑。

請從 Finder 中手動將其彈出。 |
| `外部ドライブのデバイスパスを取得できませんでした。\n\nFinderから手動でイジェクトしてください。` | Failed to obtain device path for external drive.\n\nPlease eject it manually from Finder. | 无法获取外部驱动器的设备路径。\n\n请从 Finder 中手动将其弹出。 | 無法獲取外部驅動器的設備路徑。\n\n請從 Finder 中手動將其彈出。 |
| `外部ドライブをイジェクトしますか？` | Eject external drive? | 弹出外部驱动器？ | 彈出外部驅動器？ |
| `外部ドライブを取り外し可能な状態にしています…` | Making the external drive removable... | 使外部驱动器可移动... | 使外部驅動器可移動... |
| `失敗` | Failed | 失败 | 失敗 |
| `完了` | completion | 完成 | 完成 |
| `完了検知 - 最終確認中...` | Completion detected - Final verification... | 完成检测-最终确认... | 完成檢測-最終確認... |
| `完了（PlayCover終了後）` | Completed (after PlayCover ends) | 已完成(PlayCover 结束后) | 已完成(PlayCover 結束後) |
| `完了（イジェクト失敗）` | Complete (Ejection Failed) | 完成（弹出失败） | 完成（彈出失敗） |
| `実行` | execution | 执行 | 執行 |
| `実行すると、ディスクイメージの作成とマウントを行います。` | When executed, it creates and mounts a disk image. | 执行时，它会创建并安装磁盘映像。 | 執行時，它會創建並安裝磁盤映像。 |
| `実行ファイル` | executable file | 可执行文件 | 可執行文件 |
| `実行ファイル: %@` | Executable: %@ | 可执行文件：%@ | 可執行文件：%@ |
| `実行ファイル: \(executableName)` | Executable file: \(executableName) | 可执行文件:\(可执行文件名称) | 可執行文件:\(可執行文件名稱) |
| `実行中のアプリ:` | Running app: | 运行应用程序: | 運行應用程序: |
| `実行中のアプリがあります` | I have a running app | 我有一个正在运行的应用程序 | 我有一個正在運行的應用程序 |
| `対応デバイス` | Compatible devices | 兼容设备 | 兼容設備 |
| `対応言語 (%lld)` | Supported languages ​​(%lld) | 支持的语言(%lld) | 支持的語言(%lld) |
| `対応言語 (\(result.localizations.count))` | Supported languages ​​(\(result.localizations.count)) | 支持的语言​​(\(result.localizations.count)) | 支持的語言​​(\(result.localizations.count)) |
| `小型ディスプレイ向け` | For small displays | 适用于小型显示器 | 適用於小型顯示器 |
| `強制アンマウント` | Forced unmount | 强制卸载 | 強制卸載 |
| `強制アンマウントに失敗` | Forced unmount failed | 强制卸载失败 | 強制卸載失敗 |
| `強制アンマウント中…` | Forced unmounting... | 强制卸载... | 強制卸載... |
| `強制イジェクト` | Forced eject | 强制弹出 | 強制彈出 |
| `強制イジェクトに失敗` | Forced eject failed | 强制弹出失败 | 強制彈出失敗 |
| `強制イジェクト中…` | Forced ejecting... | 强制弹出... | 強制彈出... |
| `強制的にアンマウントを試行しますか？` | Do you want to try force unmounting? | 您想尝试强制卸载吗？ | 您想嘗試強制卸載嗎？ |
| `強制的にイジェクトを試行しますか？` | Do you want to try to force eject? | 您想尝试强制弹出吗？ | 您想嘗試強制彈出嗎？ |
| `強制終了` | Forced termination | 强制终止 | 強制終止 |
| `待機` | Waiting | 支持 | 支持 |
| `後で再起動` | Restart Later | 稍后重新启动 | 稍後重新啟動 |
| `情報` | information | 信息 | 資訊 |
| `成功` | Success | 成功 | 成功 |
| `戻る` | Back | 返回 | 返回 |
| `所在地` | location | 所在地 | 地點 |
| `技術情報` | technical information | 技术情报 | 技術資料 |
| `技術情報と解析` | Technical information and analysis | 技术信息和分析 | 技術信息和分析 |
| `新規` | New | 新建 | 新建 |
| `新規インストール` | New installation | 新安装 | 新安裝 |
| `方法 1` | Method 1 | 方法 1 | 方法一 |
| `方法 2` | Method 2 | 方法 2 | 方法2 |
| `既にマウント済み` | already mounted | 已经安装了 | 已經安裝了 |
| `既存のアプリを古いバージョンにダウングレードします。` | Downgrade your existing app to an older version. | 将您现有的应用程序降级到旧版本。 | 將您現有的應用程序降級到舊版本。 |
| `既存のアプリを新しいバージョンにアップグレードします。` | Upgrade existing apps to new versions. | 将现有应用程序升级到新版本。 | 將現有應用程序升級到新版本。 |
| `既存のディスクイメージを使用` | Use existing disk image | 使用现有磁盘映像 | 使用現有磁盤映像 |
| `既定の処理` | Default processing | 默认处理 | 默認處理 |
| `日本語` | Japanese | 日本人 | 日本人 |
| `更新` | Update | 更新 | 更新 |
| `最大ファイル` | max file | 最大文件 | 最大文件 |
| `最大ファイルサイズ` | Maximum file size | 最大文件大小 | 最大文件大小 |
| `最小OS` | Minimal OS | 最小OS | 最低操作系統 |
| `最小iOS` | Minimal iOS | 最小iOS | 最低 iOS 版本 |
| `有効にすると、マウントされたディスクイメージが Finder のサイドバーに表示されなくなります。` | When enabled, mounted disk images won't appear in Finder sidebar. | 启用后，已安装的磁盘映像将不会出现在 Finder 侧栏中。 | 啟用後，已安裝的磁盤映像將不會出現在 Finder 側欄中。 |
| `未作成` | Not created | 未创建 | 未創建 |
| `未署名` | unsigned | 未署名 | 未簽名 |
| `未設定` | Not Set | 未设置 | 未設置 |
| `検索` | Search | 搜索 | 搜尋 |
| `検索結果が見つかりません` | No search results found | 没有找到搜索结果 | 沒有找到搜索結果 |
| `概要` | About | 概述 | 概述 |
| `権限要求` | authority request | 授权请求 | 授權請求 |
| `機能・権限` | Features & Permissions | 职能/权限 | 職能/權限 |
| `次へ` | Next | 到下一个 | 到下一個 |
| `残存ディレクトリを削除中...` | Deleting residual directories... | 正在删除残留目录... | 正在刪除殘留目錄... |
| `準備中...` | In preparation... | 准备中... | 正在準備... |
| `現在のグローバル設定: %@` | Current global setting: %@ | 当前全局设置:%@ | 當前全局設置:%@ |
| `現在のグローバル設定: \(settingsStore.defaultDataHandling.localizedDescription)` | Current global settings: \(settingsStore.defaultDataHandling.localizedDescription) | 当前全局设置:\(settingsStore.defaultDataHandling.localizedDescription) | 當前全局設置:\(settingsStore.defaultDataHandling.localizedDescription) |
| `現在のグローバル設定: \(settingsStore.nobrowseEnabled ? ` | Current global settings: \(settingsStore.nobrowseEnabled ? | 当前全局设置:\(settingsStore.nobrowseEnabled ? | 當前全局設置:\(settingsStore.nobrowseEnabled ? |
| `現在のシステム言語:` | Current system language: | 当前系统语言： | 當前系統語言： |
| `環境を再確認しています…` | Rechecking the environment... | 重新检查环境... | 重新檢查環境... |
| `環境を確認しています…` | Checking the environment... | 检查环境... | 檢查環境... |
| `確認` | confirmation | 确认 | 確認 |
| `简体中文` | Simplified Chinese | 简体中文 | 簡體中文 |
| `終了` | Quit | 结尾 | 結尾 |
| `終了しています…` | Finished... | 完成的... | 完成的... |
| `総サイズ` | total size | 总尺寸 | 總尺寸 |
| `総ファイル数` | Total number of files | 文件总数 | 文件總數 |
| `繁體中文` | Traditional Chinese | 繁体中文 | 繁體中文 |
| `署名日` | Signing date | 签约日期 | 簽約日期 |
| `署名済み` | signed | 签署 | 簽署 |
| `署名状態` | signature status | 签名状态 | 簽名狀態 |
| `自動（ディスプレイに基づく）` | Automatic (based on display) | 自动(基于显示) | 自動(基於顯示) |
| `致命的なエラー: %@` | Fatal error: %@ | 致命错误：%@ | 致命錯誤：%@ |
| `英語名` | English name | 英文名 | 英文名 |
| `著作権` | Copyright | 版权 | 版權 |
| `解析` | parse | 解析 | 分析 |
| `解析中...` | Parsing... | 解析中... | 正在分析... |
| `解析中: %@` | Parsing: %@ | 解析:%@ | 解析:%@ |
| `解析中: \(ipaURL.lastPathComponent)` | Parsing: \(ipaURL.lastPathComponent) | 解析中: \(ipaURL.lastPathComponent) | 解析:\(ipaURL.lastPathComponent) |
| `解析開始` | Parsing starts | 解析开始 | 開始分析 |
| `言語` | Language | 语言 | 語言 |
| `言語の変更を完全に反映するには、アプリを再起動する必要があります。` | To fully apply the language change, the app needs to restart. | 必须重新启动应用程序才能使语言更改完全生效。 | 必須重新啟動應用程序才能使語言更改完全生效。 |
| `言語を変更しました` | Language Changed | 改变语言 | 改變語言 |
| `言語を変更すると、アプリを再起動する必要があります。` | Changing the language requires restarting the app. | 更改语言需要重新启动应用程序。 | 更改語言需要重新啟動應用程序。 |
| `計算中...` | Calculating... | 计算中... | 正在計算... |
| `設定` | Settings | 环境 | 環境 |
| `設定 (ショートカット)` | Settings (⌘,) | 设置 (⌘,) | 設置(快捷方式) |
| `設定(メニュー)` | setting... | 环境... | 設置(菜單) |
| `設定をリセット` | Reset Settings | 重置设置 | 重置設置 |
| `設定をリセットしますか？` | Do you want to reset your settings? | 您想重置您的设置吗？ | 您想重置您的設置嗎？ |
| `設定を閉じる (Esc)` | Close settings (Esc) | 关闭设置(Esc) | 關閉設置(Esc) |
| `設定を開く` | Open settings | 打开设置 | 打開設置 |
| `設定ファイルを削除中...` | Deleting configuration file... | 正在删除配置文件... | 正在刪除配置文件... |
| `設定画面から保存先を指定してください。` | Please specify the save destination from the settings screen. | 请从设置屏幕指定保存目的地。 | 請從設置屏幕指定保存目的地。 |
| `詳細` | detailed | 详细 | 細節 |
| `詳細と設定` | Details and settings | 详细信息和设置 | 詳細信息和設置 |
| `詳細情報` | Detailed information | 详情 | 詳情 |
| `説明` | explanation | 解释 | 解釋 |
| `起動` | boot | 启动 | 啟動 |
| `起動時に内部データが見つかった場合の処理方法を設定します。` | Sets what to do if internal data is found during startup. | 设置在启动期间发现内部数据时要执行的操作。 | 設置在啟動期間發現內部數據時要執行的操作。 |
| `起動時の検証に失敗しました` | Startup validation failed | 启动验证失败 | 啟動驗證失敗 |
| `連絡先` | Contacts | 联系地址 | 聯繫地址 |
| `選択` | choice | 选择 | 選擇 |
| `選択を解除` | Deselect | 取消选择 | 取消選擇 |
| `閉じる` | Close | 关闭 | 關閉 |
| `閉じる (Esc)` | Close (Esc) | 关闭(Esc) | 關閉(Esc) |
| `開発者情報` | Developer information | 开发者信息 | 開發者信息 |
| `（PlayCoverコンテナと関連するアプリコンテナが含まれます）` | (Includes PlayCover container and associated app container) | (包括 PlayCover 容器和关联的应用程序容器) | (包括 PlayCover 容器和關聯的應用程序容器) |
| `（既定）` | (established) | (既定) | (預設) |
