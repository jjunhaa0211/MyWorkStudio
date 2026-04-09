cask "doffice" do
  version "0.0.56"
  sha256 :no_check

  url "https://github.com/jjunhaa0211/Doffice/releases/download/v#{version}/Doffice-v#{version}.zip"
  name "Doffice"
  desc "Gamified Claude Code session manager with pixel-art visualization"
  homepage "https://github.com/jjunhaa0211/Doffice"

  auto_updates true

  app "Doffice.app"

  zap trash: [
    "~/Library/Preferences/com.doffice.app.plist",
    "~/Library/Application Support/Doffice",
  ]
end
