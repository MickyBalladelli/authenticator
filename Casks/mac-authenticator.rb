cask "mac-authenticator" do
  version "1.0.0"
  sha256 "bde56aaf5a0984b46bb7feb95bb7b887f40ff67a6bcfe267ba02887f96a16de2"

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
