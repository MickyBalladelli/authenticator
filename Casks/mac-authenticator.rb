cask "mac-authenticator" do
  version "1.0.0"
  sha256 "138ecc0388c91c43839879986072752d8ab41e6f9fa29292e8c1bfee502b1f8e"

  url "https://github.com/MickyBalladelli/authenticator/releases/download/v#{version}/MacAuthenticator-#{version}.zip"
  name "Mac Authenticator"
  desc "Menu-bar TOTP authenticator for macOS"
  homepage "https://github.com/MickyBalladelli/authenticator"

  depends_on macos: ">= :ventura"

  app "MacAuthenticator.app"

  zap trash: [
    "~/Library/Application Support/MacAuthenticator",
    "~/Library/Preferences/com.micky.MacAuthenticator.plist",
  ]
end
