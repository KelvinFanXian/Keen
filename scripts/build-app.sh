#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.build/module-cache"
SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache" \
CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache" \
swift build -c release --disable-sandbox -debug-info-format none

ICONSET_DIR="$ROOT_DIR/.build/Keen.iconset"
SWIFT_MODULECACHE_PATH="$ROOT_DIR/.build/module-cache" \
swift -module-cache-path "$ROOT_DIR/.build/module-cache" "$ROOT_DIR/scripts/generate-icon.swift" "$ROOT_DIR/Resources/AppIcon.png" "$ICONSET_DIR"

ASSET_CATALOG_DIR="$ROOT_DIR/.build/KeenAssets.xcassets"
APPICONSET_DIR="$ASSET_CATALOG_DIR/AppIcon.appiconset"
rm -rf "$ASSET_CATALOG_DIR"
mkdir -p "$APPICONSET_DIR"
cp "$ICONSET_DIR"/*.png "$APPICONSET_DIR/"
cp "$ROOT_DIR/Resources/AppIconContents.json" "$APPICONSET_DIR/Contents.json"

APP_DIR="$ROOT_DIR/.build/app/Keen.app"
CONTENTS_DIR="$APP_DIR/Contents"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$ROOT_DIR/.build/release/Keen" "$CONTENTS_DIR/MacOS/Keen"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
xcrun actool "$ASSET_CATALOG_DIR" \
    --compile "$CONTENTS_DIR/Resources" \
    --platform macosx \
    --minimum-deployment-target 15.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$ROOT_DIR/.build/AppIconPartialInfo.plist" \
    --enable-on-demand-resources NO >/dev/null

RESOURCE_BUNDLE="$ROOT_DIR/.build/release/Keen_Keen.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$CONTENTS_DIR/Resources/"
fi

KEEN_SIGNING_IDENTITY="${KEEN_SIGNING_IDENTITY:-}"
if [[ -z "$KEEN_SIGNING_IDENTITY" ]]; then
    KEEN_SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' \
        | head -n 1)"
fi
if [[ -z "$KEEN_SIGNING_IDENTITY" ]]; then
    KEEN_SIGNING_IDENTITY="-"
fi

codesign --force --deep --sign "$KEEN_SIGNING_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "签名：$KEEN_SIGNING_IDENTITY"
echo "$APP_DIR"
