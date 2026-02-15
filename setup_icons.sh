#!/bin/bash
# Gera todos os tamanhos do iconset a partir do LOGO.png
ICONSET="/Users/thalesmoura/Documents/OpenCorePatchBR/SafeMyHack/Resources/AppIcon.iconset"
SRC="$ICONSET/LOGO.png"

if [ ! -f "$SRC" ]; then
    echo "❌ LOGO.png não encontrado em $ICONSET"
    exit 1
fi

echo "🎨 Gerando iconset a partir de LOGO.png..."

sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png" > /dev/null 2>&1
sips -z 512 512 "$SRC" --out "$ICONSET/icon_512x512.png" > /dev/null 2>&1
sips -z 512 512 "$SRC" --out "$ICONSET/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 256 256 "$SRC" --out "$ICONSET/icon_256x256.png" > /dev/null 2>&1
sips -z 256 256 "$SRC" --out "$ICONSET/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 128 128 "$SRC" --out "$ICONSET/icon_128x128.png" > /dev/null 2>&1
sips -z 64 64 "$SRC" --out "$ICONSET/icon_32x32@2x.png" > /dev/null 2>&1
sips -z 32 32 "$SRC" --out "$ICONSET/icon_32x32.png" > /dev/null 2>&1
sips -z 32 32 "$SRC" --out "$ICONSET/icon_16x16@2x.png" > /dev/null 2>&1
sips -z 16 16 "$SRC" --out "$ICONSET/icon_16x16.png" > /dev/null 2>&1

# Copiar logo para Resources (uso no app)
cp "$SRC" "/Users/thalesmoura/Documents/OpenCorePatchBR/SafeMyHack/Resources/AppIcon.png"

echo "✅ Iconset gerado:"
ls -la "$ICONSET"/*.png
echo ""
echo "Agora rode: iconutil -c icns '$ICONSET' -o '/Users/thalesmoura/Documents/OpenCorePatchBR/SafeMyHack/Resources/AppIcon.icns'"
