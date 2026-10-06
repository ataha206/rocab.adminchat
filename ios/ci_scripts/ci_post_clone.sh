#!/bin/sh
# Xcode Cloud: runs after the repo is cloned, before xcodebuild.
# Installs Flutter and CocoaPods, generates Flutter config and installs pods.
set -e

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.4}"
REPO="$CI_PRIMARY_REPOSITORY_PATH"

# Flutter SDK (pinned to the version used locally)
git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"
flutter --disable-analytics
flutter precache --ios

cd "$REPO"
flutter pub get

# Optional build-time values from the workflow's environment variables:
#   API_BASE_URL  -> --dart-define=API_BASE_URL=...
#   DART_DEFINES  -> space-separated KEY=VALUE pairs, e.g. "DEBUG=false ROUTING_URL=http://..."
DEFINES=""
[ -n "$API_BASE_URL" ] && DEFINES="--dart-define=API_BASE_URL=$API_BASE_URL"
for kv in $DART_DEFINES; do DEFINES="$DEFINES --dart-define=$kv"; done

# Writes ios/Flutter/Generated.xcconfig (release mode, build number from Xcode Cloud)
flutter build ios --config-only --release --no-codesign --build-number="$CI_BUILD_NUMBER" $DEFINES

# CocoaPods only if the project uses it. This app's plugins are Swift packages,
# so there is normally no Podfile; `flutter build --config-only` creates one only
# when a plugin still needs CocoaPods.
if [ -f ios/Podfile ]; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
  (cd ios && pod install)
fi

exit 0
