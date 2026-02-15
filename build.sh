#!/bin/bash
# SafeMyHack Build Script - INTEL/AMD HACKINTOSH ONLY
# Zero Xcode dependency for distribution

set -e

echo "🔨 SafeMyHack Build Script (Intel/AMD x86_64)"
echo "================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
DIST_DIR="$SCRIPT_DIR/dist"
APP_NAME="SafeMyHack"
VERSION="${SAFEMYHACK_VERSION:-1.0.0}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "   Version: $VERSION"

echo "🧹 Limpando builds anteriores..."
rm -rf "$DIST_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$DIST_DIR"

echo ""
echo "⚙️  Compilando x86_64 (Intel/AMD Hackintosh)..."
swift build -c release --arch x86_64

RELEASE_EXEC="$BUILD_DIR/x86_64-apple-macosx/release/$APP_NAME"

if [ ! -f "$RELEASE_EXEC" ]; then
    echo "❌ ERRO: Executável não encontrado em $RELEASE_EXEC"
    exit 1
fi
echo "   ✓ Executável encontrado"

# CORRIGIR RPATHS
echo ""
echo "🔧 Corrigindo rpaths..."

while IFS= read -r RPATH; do
    if [ -n "$RPATH" ]; then
        RPATH_CLEAN=$(echo "$RPATH" | sed 's/^[[:space:]]*path[[:space:]]*//' | sed 's/[[:space:]]*(offset[[:space:]]*[0-9]*)$//')
        install_name_tool -delete_rpath "$RPATH_CLEAN" "$RELEASE_EXEC" 2>/dev/null || true
    fi
done < <(otool -l "$RELEASE_EXEC" | grep -A2 LC_RPATH | grep path | grep -i -E "(Xcode|Toolchains)")

install_name_tool -delete_rpath "@loader_path" "$RELEASE_EXEC" 2>/dev/null || true

if ! otool -l "$RELEASE_EXEC" | grep -q "path /usr/lib/swift"; then
    install_name_tool -add_rpath /usr/lib/swift "$RELEASE_EXEC" 2>/dev/null || true
fi
if ! otool -l "$RELEASE_EXEC" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath @executable_path/../Frameworks "$RELEASE_EXEC" 2>/dev/null || true
fi

if otool -l "$RELEASE_EXEC" | grep -A2 LC_RPATH | grep path | grep -q -i -E "(Xcode|Toolchains)"; then
    echo "❌ ERRO: rpaths do Xcode remanescentes!"
    exit 1
fi
echo "   ✅ rpaths limpos"

# CRIAR .APP BUNDLE
echo ""
echo "📦 Criando bundle .app..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

cp "$RELEASE_EXEC" "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# RESOURCES
echo "📦 Bundlando Resources..."
# Kexts NÃO são bundladas — o usuário fornece as suas via EFI
if [ -d "$SCRIPT_DIR/Resources/Payloads" ]; then
    cp -R "$SCRIPT_DIR/Resources/Payloads" "$APP_BUNDLE/Contents/Resources/"
    echo "   ✓ Payloads bundled"
fi
if [ -d "$SCRIPT_DIR/Resources/AppIcon.iconset" ]; then
    iconutil -c icns "$SCRIPT_DIR/Resources/AppIcon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "   ✓ Ícone gerado"
elif [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    echo "   ✓ Ícone copiado"
fi

# INFO.PLIST
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST_END
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SafeMyHack</string>
    <key>CFBundleIdentifier</key>
    <string>com.hackintosh.safemyhack</string>
    <key>CFBundleName</key>
    <string>SafeMyHack</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST_END
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"
echo "   ✓ Info.plist criado"

# ASSINATURA
echo "🔐 Assinando..."
xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"
xattr -cr "$APP_BUNDLE"
echo "   ✅ Assinado"

# VALIDAÇÃO
echo ""
echo "🔍 Validação final..."
if otool -l "$APP_BUNDLE/Contents/MacOS/$APP_NAME" | grep -A2 LC_RPATH | grep path | grep -q -i -E "(Xcode|Toolchains)"; then
    echo "❌ rpaths do Xcode no bundle!"; exit 1
fi
echo "   ✅ Build limpo"

# ZIP
echo ""
echo "📁 Criando ZIP..."
cd "$DIST_DIR"
TEMP_DIR="SafeMyHack-v${VERSION}"
mkdir -p "$TEMP_DIR"
cp -R "SafeMyHack.app" "$TEMP_DIR/"

cat > "$TEMP_DIR/LEIA-ME.txt" << 'README_END'
SafeMyHack — Legacy Patcher para Hackintosh
WiFi Broadcom + Audio | macOS Sonoma/Sequoia/Tahoe

PRIMEIRA VEZ:
  Sonoma: Botão direito → Abrir → Confirme
  Sequoia/Tahoe: Terminal → xattr -cr SafeMyHack.app

100% Local • Sem Telemetria • Código Aberto (GPL-3.0)
README_END

ditto -c -k --sequesterRsrc --keepParent "$TEMP_DIR" "SafeMyHack-v${VERSION}-Intel-AMD.zip"
rm -rf "$TEMP_DIR"
shasum -a 256 "SafeMyHack-v${VERSION}-Intel-AMD.zip" > "SafeMyHack-v${VERSION}-Intel-AMD.zip.sha256"

echo ""
echo "════════════════════════════════════════════"
echo "✅ BUILD CONCLUÍDO"
echo "════════════════════════════════════════════"
echo "📦 ZIP: $DIST_DIR/SafeMyHack-v${VERSION}-Intel-AMD.zip"
echo "🔐 SHA256:"
cat "SafeMyHack-v${VERSION}-Intel-AMD.zip.sha256"
echo ""
