# ByteHide Shield iOS

Protect your iOS apps with obfuscation, anti-debug, anti-jailbreak, string encryption, and more.

## Quick Setup

Run this one-liner from your Xcode project directory:

```bash
bash <(curl -sL https://raw.githubusercontent.com/bytehide/shield-ios/main/scripts/setup.sh)
```

This will:
1. Install the `shield-ios` CLI (via Homebrew or pip)
2. Install the `xcodeproj` Ruby gem
3. Create a `shield-ios.json` configuration file
4. Add the config to your Xcode project
5. Configure a post-archive action so Shield runs automatically on every Archive

## Manual Installation

```bash
# Install CLI
brew install bytehide/tap/shield-ios
# or
pip install bytehide-shield-ios

# Initialize config
shield-ios init
```

## Documentation

- [CLI Usage](https://docs.bytehide.com/platforms/ios/products/shield)
- [Xcode Integration](https://docs.bytehide.com/platforms/ios/products/shield/xcode)
- [Fastlane Plugin](https://docs.bytehide.com/platforms/ios/products/shield/fastlane)

## License

Copyright (c) ByteHide. All rights reserved.
