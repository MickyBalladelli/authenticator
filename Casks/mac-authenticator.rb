cask "mac-authenticator" do
  version "1.1.1"
  sha256 "38cb17fa567195a102ef3603b39fa9003280fb10c03f8c735a637039e85cb728"

  url "https://github.com/MickyBalladelli/authenticator/releases/download/v#{version}/MacAuthenticator-#{version}.zip"
  name "Mac Authenticator"
  desc "Menu-bar TOTP authenticator for macOS"
  homepage "https://github.com/MickyBalladelli/authenticator"

  depends_on macos: :ventura

  app "MacAuthenticator.app"

  zap trash: [
    "~/Library/Application Support/MacAuthenticator",
    "~/Library/Preferences/com.micky.MacAuthenticator.plist",
  ]
end
