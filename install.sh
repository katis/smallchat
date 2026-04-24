#!/bin/bash
# smallchat bootstrap.
#
# One-time setup for a fresh clone. Downloads a Pharo 13 VM + seed image
# into ./pharo/ (gitignored), then runs lib/load-packages.st headlessly
# to Metacello-load BaselineOfSmallChat from the Tonel tree under src/
# into a development image.
#
# Two image flavours at disjoint on-disk paths so they never collide:
#   default:        verifier image at pharo/Pharo.verifier.image (used
#                   by `just test` and `just lint`). No MCP, no Iceberg.
#                   Wiped and re-materialised every test run.
#   --mcp:          dev image at pharo/Pharo.image (used by `just mcp`
#                   / Claude Code). Loads SmallChat-MCP, registers
#                   Iceberg. Long-lived.
#
# Safe to re-run: existing VM is reused; the image is rebuilt from the
# seed if missing or if --rebuild is passed.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd -P)"
PHARO_DIR="$REPO/pharo"
VM_DIR="$PHARO_DIR/vm"
SEED_DIR="$PHARO_DIR/seed"
LOAD_SCRIPT="$REPO/lib/load-packages.st"

REBUILD=0
MCP=0
for arg in "$@"; do
    case "$arg" in
        --rebuild) REBUILD=1 ;;
        --mcp)     MCP=1 ;;
        -h|--help)
            sed -n '2,18p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

# Dev (--mcp) and verifier flavours live on disjoint image files so
# running `just test` / `just lint` never clobbers a live dev session.
if [ "$MCP" -eq 1 ]; then
    IMAGE_NAME="Pharo.image"
    CHANGES_NAME="Pharo.changes"
else
    IMAGE_NAME="Pharo.verifier.image"
    CHANGES_NAME="Pharo.verifier.changes"
fi
IMAGE="$PHARO_DIR/$IMAGE_NAME"
CHANGES="$PHARO_DIR/$CHANGES_NAME"

mkdir -p "$PHARO_DIR" "$VM_DIR" "$SEED_DIR"

VM="$VM_DIR/Pharo.app/Contents/MacOS/Pharo"

if [ ! -x "$VM" ] || [ ! -f "$SEED_DIR/Pharo.image" ]; then
    echo "==> Fetching Pharo 13 VM + seed image via Zeroconf"
    TMP="$(mktemp -d)"
    (cd "$TMP" && curl -L https://get.pharo.org/64/130+vm | bash)
    if [ -z "$(ls -A "$VM_DIR" 2>/dev/null)" ]; then
        mv "$TMP"/pharo-vm/* "$VM_DIR/"
    fi
    cp "$TMP/Pharo.image"   "$SEED_DIR/Pharo.image"
    cp "$TMP/Pharo.changes" "$SEED_DIR/Pharo.changes"
    for src in "$TMP"/*.sources; do
        [ -f "$src" ] && cp "$src" "$SEED_DIR/"
    done
    rm -rf "$TMP"
    echo "    VM:   $VM"
    echo "    seed: $SEED_DIR/Pharo.image"
else
    echo "==> VM and seed image already present; skipping download"
fi

# Stage vendored tree-sitter dylibs into the VM's Plugins dir where
# FFIMacLibraryFinder discovers them. Rerun-safe: overwrites existing.
# The dev image uses TreeSitter at FFI call time; the verifier image
# doesn't load the binding but the copy is cheap and keeps the two
# flavours in sync.
DYLIB_SRC="$REPO/lib/tree-sitter/arm64-darwin"
DYLIB_DST="$VM_DIR/Pharo.app/Contents/MacOS/Plugins"
if [ -d "$DYLIB_SRC" ] && [ -d "$DYLIB_DST" ]; then
    echo "==> Copying tree-sitter dylibs into $DYLIB_DST"
    for dylib in "$DYLIB_SRC"/*.dylib; do
        [ -f "$dylib" ] || continue
        cp "$dylib" "$DYLIB_DST/"
    done
fi

if [ "$REBUILD" -eq 1 ] || [ ! -f "$IMAGE" ]; then
    echo "==> Materialising working image from seed"
    cp "$SEED_DIR/Pharo.image"   "$IMAGE"
    cp "$SEED_DIR/Pharo.changes" "$CHANGES"
    for src in "$SEED_DIR"/*.sources; do
        [ -f "$src" ] && cp "$src" "$PHARO_DIR/"
    done

    if [ "$MCP" -eq 1 ]; then
        echo "==> Loading SmallChat baseline (dev / MCP mode, headless)"
        (cd "$PHARO_DIR" && env SMALLCHAT_REPO="$REPO" SMALLCHAT_MCP_MODE=1 \
            "$VM" --headless "$IMAGE_NAME" st --quit --save "$LOAD_SCRIPT")
    else
        echo "==> Loading SmallChat baseline (verifier mode, headless)"
        (cd "$PHARO_DIR" && env SMALLCHAT_REPO="$REPO" \
            "$VM" --headless "$IMAGE_NAME" st --quit --save "$LOAD_SCRIPT")
    fi
else
    echo "==> Working image already present; pass --rebuild to recreate"
fi

if [ "$MCP" -eq 1 ]; then
    cat <<EOF

==> Install complete (dev / MCP mode).

The dev image lives at ./pharo/Pharo.image.

Launch the long-lived dev image (Claude Code talks to this):

    just mcp        # or ./bin/smallchat-mcp directly

Rebuild the dev image (drops ./pharo/Pharo.image):

    just rebuild-mcp
EOF
else
    cat <<EOF

==> Install complete (verifier mode).

The verifier image lives at ./pharo/Pharo.verifier.image and is used
by \`just test\` and \`just lint\`. For an interactive session, bring
up the dev image instead:

    just rebuild-mcp    # materialise ./pharo/Pharo.image with MCP + Iceberg
    just mcp            # launch it

Rebuild the verifier image (keeps VM, drops ./pharo/Pharo.verifier.image):

    ./install.sh --rebuild

Bring up the dev image with MCP + Iceberg loaded:

    ./install.sh --mcp --rebuild
EOF
fi
