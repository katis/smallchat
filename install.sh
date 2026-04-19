#!/bin/bash
# smallchat bootstrap.
#
# One-time setup for a fresh clone. Downloads a Pharo 13 VM + seed image
# into ./pharo/ (gitignored), then runs lib/load-packages.st headlessly
# to Metacello-load BaselineOfSmallChat from the Tonel tree under src/
# into a development image.
#
# Two image flavours:
#   default:        verifier image (used by `just test` and `just lint`).
#                   No MCP, no Iceberg. Wiped and re-materialised every
#                   test run.
#   --mcp:          dev image (used by `just mcp` / Claude Code). Loads
#                   SmallChat-MCP, registers Iceberg. Long-lived.
#
# Safe to re-run: existing VM is reused; the image is rebuilt from the
# seed if missing or if --rebuild is passed.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd -P)"
PHARO_DIR="$REPO/pharo"
VM_DIR="$PHARO_DIR/vm"
SEED_DIR="$PHARO_DIR/seed"
IMAGE="$PHARO_DIR/Pharo.image"
CHANGES="$PHARO_DIR/Pharo.changes"
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
            "$VM" --headless Pharo.image st --quit --save "$LOAD_SCRIPT")
    else
        echo "==> Loading SmallChat baseline (verifier mode, headless)"
        (cd "$PHARO_DIR" && env SMALLCHAT_REPO="$REPO" \
            "$VM" --headless Pharo.image st --quit --save "$LOAD_SCRIPT")
    fi
else
    echo "==> Working image already present; pass --rebuild to recreate"
fi

if [ "$MCP" -eq 1 ]; then
    cat <<EOF

==> Install complete (dev / MCP mode).

Launch the long-lived dev image (Claude Code talks to this):

    just mcp        # or ./bin/smallchat-mcp directly

Rebuild the dev image (drops ./pharo/Pharo.image):

    just rebuild-mcp
EOF
else
    cat <<EOF

==> Install complete (verifier mode).

Run the GUI:

    ./bin/smallchat

Rebuild the verifier image (keeps VM, drops ./pharo/Pharo.image):

    ./install.sh --rebuild

Bring up the dev image with MCP + Iceberg loaded:

    ./install.sh --mcp --rebuild
EOF
fi
