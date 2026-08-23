cask "mac-authenticator" do
  version "1.1.2"
  sha256 "114b8d78a2c33712dc7137b6e99186cdac2811205a8f4bf046f4d99b005b3289"

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
