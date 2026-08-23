cask "mac-authenticator" do
  version "1.1.2"
  sha256 "8c8ef916e1326c017e08b4bc3c496ca05f5678d1abdc069ac6cc34997b6f629c"

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
