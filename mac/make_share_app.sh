#!/bin/zsh
# Builds the share edition of 毎日にほんご帳.app (universal: Apple silicon + Intel).
# The pages are bundled (Resources/web), so it runs without Python or a local server.
# Output: build/mac/毎日にほんご帳.app and build/mac/Nihongo-Cho-mac.zip
set -e
HERE="${0:A:h}"
ROOT="${HERE:h}"
NAME="毎日にほんご帳"
VER="${1:-1.1.2}"
OUT="$ROOT/build/mac"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
python3 "$ROOT/tools/build.py"
rm -rf "$OUT"; mkdir -p "$OUT"
APP="$WORK/app/$NAME.app"  # assembled outside Documents so codesign sees no extra attributes
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos12.0" "$HERE/main.swift" -o "$WORK/bin-$arch" -framework Cocoa -framework WebKit
done
lipo -create "$WORK/bin-arm64" "$WORK/bin-x86_64" -output "$APP/Contents/MacOS/NihongoCho"
swiftc -target "$(uname -m)-apple-macos12.0" "$HERE/make_icon.swift" -o "$WORK/make_icon" -framework Cocoa
"$WORK/make_icon" "$WORK/icon.png"
ICONSET="$WORK/AppIcon.iconset"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$WORK/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$WORK/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp -R "$ROOT/docs" "$APP/Contents/Resources/web"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>io.github.caffecayu.nihongo-cho</string>
  <key>CFBundleExecutable</key><string>NihongoCho</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VER</string>
  <key>CFBundleVersion</key><string>$VER</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>口语练习时听你的日语回答。</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>把你的日语回答转成文字，用来检查句型。</string>
</dict></plist>
PLIST
xattr -cr "$APP"
codesign --force --deep -s - "$APP"
ditto -c -k --keepParent "$APP" "$OUT/Nihongo-Cho-mac.zip"
ditto "$APP" "$OUT/$NAME.app"
echo "OK: $OUT/Nihongo-Cho-mac.zip ($(du -h "$OUT/Nihongo-Cho-mac.zip" | cut -f1))"
