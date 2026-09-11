#!/usr/bin/env bash
#
# Compila la versione web di Sviluppo Lamiera e la mette dove GitHub Pages la
# serve, cioè nella cartella `sviluppo-lamiera/` alla radice del repository.
#
#   ./sviluppo-lamiera-app/scripts/build-web.sh
#
# Da rilanciare SOLO sui commit di rilascio, mai a ogni modifica di codice: la
# build committata pesa una quindicina di megabyte e rigenerarla di continuo
# gonfierebbe la storia del repository senza motivo.

set -euo pipefail

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$(dirname "$QUI")/app"
RADICE="$(cd "$(dirname "$QUI")/.." && pwd)"
PUBBLICA="$RADICE/sviluppo-lamiera"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter non è nel PATH." >&2
  echo "Scarica l'SDK da https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

echo "==> Compilazione release"
cd "$APP"
flutter pub get
flutter build web \
  --release \
  --base-href /sviluppo-lamiera/ \
  --pwa-strategy offline-first

echo "==> Potatura di quello che non viene mai scaricato"

# I .symbols servono solo a simbolicare gli stack trace fuori linea: a runtime
# il browser non li richiede mai.
find build/web -name "*.symbols" -delete

# web/flutter_bootstrap.js fissa il renderer su CanvasKit, quindi le varianti
# skwasm non vengono mai caricate. Toglierle dimezza abbondantemente il peso.
rm -rf \
  build/web/canvaskit/skwasm.js \
  build/web/canvaskit/skwasm.wasm \
  build/web/canvaskit/skwasm_heavy.js \
  build/web/canvaskit/skwasm_heavy.wasm \
  build/web/canvaskit/wimp.js \
  build/web/canvaskit/wimp.wasm \
  build/web/canvaskit/webparagraph

echo "==> Marchiatura del service worker"

# Il nome della cache deve cambiare a ogni rilascio, altrimenti chi ha già
# aperto l'app continuerebbe a vedere la versione vecchia servita dalla cache.
BUILD_ID="$(date -u +%Y%m%d%H%M%S)"
sed -i "s/sviluppo-lamiera-BUILD_ID/sviluppo-lamiera-$BUILD_ID/" build/web/sw.js
echo "    versione cache: sviluppo-lamiera-$BUILD_ID"

echo "==> Pubblicazione in $PUBBLICA"
rm -rf "$PUBBLICA"
mkdir -p "$PUBBLICA"
cp -r build/web/. "$PUBBLICA/"

echo
echo "Fatto: $(du -sh "$PUBBLICA" | cut -f1) in $PUBBLICA"
echo "Controlla con:  git status --short sviluppo-lamiera/"
echo "Online su:      https://qualifixservice25-cloud.github.io/sviluppo-lamiera/"
