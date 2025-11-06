cask "playcovermanager" do
  version "1.0.0"
  sha256 "YOUR_SHA256_HASH_HERE"  # build_release_unsigned.sh実行後に表示されるSHA256に置き換え
  
  url "https://github.com/HEHEX8/PlayCoverManagerGUI/releases/download/v#{version}/PlayCoverManager.dmg"
  name "PlayCover Manager"
  desc "GUI launcher and manager for PlayCover iOS apps on macOS"
  homepage "https://github.com/HEHEX8/PlayCoverManagerGUI"
  
  # macOS 11.0 Big Sur以降
  depends_on macos: ">= :big_sur"
  
  app "PlayCoverManager.app"
  
  # Quarantine属性を自動削除（Gatekeeper警告をスキップ）
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/PlayCoverManager.app"],
                   sudo: false
  end
  
  # アンインストール時のクリーンアップ
  uninstall quit: "com.hehexe.PlayCoverManager"
  
  zap trash: [
    "~/Library/Preferences/com.hehexe.PlayCoverManager.plist",
    "~/Library/Application Support/PlayCoverManager",
  ]
end
