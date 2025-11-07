# Homebrew Cask for PlayCover Manager
# 
# インストール方法:
#   brew install --cask playcover-manager
#
# このファイルは homebrew-cask リポジトリに追加する必要があります
# または個人tapを作成してください:
#   brew tap HEHEX8/playcover-manager
#   brew install --cask HEHEX8/playcover-manager/playcover-manager

cask "playcover-manager" do
  version "1.0.0"
  sha256 :no_check  # リリース時に実際のSHA256に置き換える
  
  url "https://github.com/HEHEX8/PlayCoverManagerGUI/releases/download/v#{version}/PlayCoverManager.dmg"
  name "PlayCover Manager"
  desc "GUI tool for managing PlayCover iOS apps on macOS"
  homepage "https://github.com/HEHEX8/PlayCoverManagerGUI"

  # macOS Tahoe 26.0+ が必要
  depends_on macos: ">= :tahoe"
  
  # Apple Silicon専用
  depends_on arch: :arm64

  app "PlayCoverManager.app"

  # アンインストール時の処理
  uninstall quit: "com.hehex8.PlayCoverManager"

  # 関連ファイルの削除
  zap trash: [
    "~/Library/Preferences/com.hehex8.PlayCoverManager.plist",
    "~/Library/Application Support/PlayCoverManager",
    "~/Library/Caches/com.hehex8.PlayCoverManager",
  ]

  # 注意事項
  caveats <<~EOS
    PlayCover Manager には以下が必要です:
    
    1. macOS Tahoe 26.0 以降
    2. Apple Silicon Mac
    3. PlayCover.app (別途インストール必須)
       https://github.com/PlayCover/PlayCover
    
    初回起動時:
    - 右クリック → "開く" で起動してください（署名なし）
    - PlayCover.app の場所を選択
    - ASIF ディスクイメージ保存先を選択
  EOS
end
