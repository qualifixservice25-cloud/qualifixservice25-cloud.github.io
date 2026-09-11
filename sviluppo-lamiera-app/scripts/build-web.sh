#!/usr/bin/env bash
#
# Compila la versione web di Sviluppo Lamiera.
#
#   ./sviluppo-lamiera-app/scripts/build-web.sh [base-href] [cartella-uscita]
#
# Valori predefiniti: base-href "/" e uscita in "build/web", cioè quello che
# serve al sito Netlify dedicato all'app.
#
# Questo script è l'unico posto in cui vive la logica di compilazione: lo usa la
# GitHub Action e lo usi tu in locale, così quello che finisce online è
# esattamente quello che hai provato sulla tua macchina.
#
# Il base-href è il dettaglio che si sbaglia più spesso con Flutter web: se non
# corrisponde al percorso da cui il sito serve l'app, tutti gli asset vengono
# cercati nel posto sbagliato e resta una pagina bianca, senza alcun errore
# visibile. Con un sito dedicato va "/"; se un giorno l'app tornasse in una
# sottocartella, "/nome-cartella/" con entrambe le barre.

set -euo pipefail

BASE_HREF="${1:-/}"
USCITA="${2:-build/web}"

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$(dirname "$QUI")/app"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter non è nel PATH." >&2
  echo "Scarica l'SDK da https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

cd "$APP"

echo "==> Compilazione release (base-href $BASE_HREF)"
flutter pub get
flutter build web --release --base-href "$BASE_HREF"

echo "==> Potatura di quello che il browser non scarica mai"

# I .symbols servono solo a simbolicare gli stack trace fuori linea: a runtime
# non vengono mai richiesti.
find build/web -name "*.symbols" -delete

# web/flutter_bootstrap.js fissa il renderer su CanvasKit, quindi le varianti
# skwasm non vengono mai caricate. Toglierle più che dimezza il peso.
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
sed -i.bak "s/sviluppo-lamiera-BUILD_ID/sviluppo-lamiera-$BUILD_ID/" build/web/sw.js
rm -f build/web/sw.js.bak
echo "    versione cache: sviluppo-lamiera-$BUILD_ID"

# Uscita in un posto diverso da build/web solo se richiesto.
if [ "$USCITA" != "build/web" ]; then
  echo "==> Copia in $USCITA"
  rm -rf "$USCITA"
  mkdir -p "$USCITA"
  cp -r build/web/. "$USCITA/"
fi

FINALE="$APP/$USCITA"
echo
echo "Fatto: $(du -sh "$FINALE" | cut -f1) in $FINALE"
echo
echo "Per provarla in locale (il base-href è \"$BASE_HREF\", quindi va servita"
echo "dalla radice di un server, non aperta con file://):"
echo "    npx http-server \"$FINALE\" -p 8080"
