#!/usr/bin/env bash
# Build zxPluginsInject.dylib from source in modules/zxPluginsInject.
#
# Used by GitHub Actions and local builds. Output: extra_dylibs/zxPluginsInject.dylib
#
# Requires THEOS (CI installs it in a prior step). Falls back to ~/theos locally.

set -euo pipefail

REPO_DIR="$(pwd)"
MOD_DIR="$REPO_DIR/modules/zxPluginsInject"

if [ -z "${THEOS:-}" ]; then
    if [ -d "$HOME/theos" ]; then
        export THEOS="$HOME/theos"
    else
        echo "THEOS not set and ~/theos not found" >&2
        exit 1
    fi
fi

cd "$MOD_DIR"

if [ "${1:-}" = "--clean" ]; then
    make clean >/dev/null 2>&1 || true
fi

make FINALPACKAGE=1

# Cerca il dylib sia nella cartella standard che in quella debug/obj per sicurezza
if [ -f "$MOD_DIR/.theos/obj/zxPluginsInject.dylib" ]; then
    DYLIB_OUT="$MOD_DIR/.theos/obj/zxPluginsInject.dylib"
elif [ -f "$MOD_DIR/.theos/obj/debug/zxPluginsInject.dylib" ]; then
    DYLIB_OUT="$MOD_DIR/.theos/obj/debug/zxPluginsInject.dylib"
else
    echo "zxPluginsInject.dylib not produced" >&2
    exit 1
fi

# Crea la cartella extra_dylibs richiesta dal workflow principale
mkdir -p "$REPO_DIR/extra_dylibs"
cp "$DYLIB_OUT" "$REPO_DIR/extra_dylibs/zxPluginsInject.dylib"

install_name_tool -id "@rpath/zxPluginsInject.dylib" \
    "$REPO_DIR/extra_dylibs/zxPluginsInject.dylib" 2>/dev/null || true

echo "Saved: $REPO_DIR/extra_dylibs/zxPluginsInject.dylib"
ls -lh "$REPO_DIR/extra_dylibs/zxPluginsInject.dylib"
