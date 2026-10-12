#!/bin/zsh
# Builds "Milo.app" into build/ from the Swift package. Works with just the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product GooglyMac

# Assemble and sign outside the project: iCloud-synced folders (like Documents) attach Finder
# info to the bundle, which codesign rejects. The signed app is then copied into build/.
FINAL="build/Milo.app"
STAGE=$(mktemp -d)
APP="$STAGE/Milo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/GooglyMac" "$APP/Contents/MacOS/GooglyMac"
cp Mac/Info.plist "$APP/Contents/Info.plist"
cp Shared/Fonts/*.ttf "$APP/Contents/Resources/"

# Local prototypes use ad hoc signing. Set MILO_SIGN_IDENTITY explicitly for a trusted
# development identity; never pick an unrelated certificate from the user's keychain.
IDENTITY="${MILO_SIGN_IDENTITY:--}"
codesign --force --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

rm -rf "$FINAL"
mkdir -p build
ditto --norsrc --noextattr "$APP" "$FINAL"
rm -rf "$STAGE"

echo "Built $FINAL"
echo "Run it with: open \"$FINAL\""
