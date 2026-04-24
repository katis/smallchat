# smallchat task runner. Run `just` with no args to list recipes.

set shell := ["bash", "-euo", "pipefail", "-c"]

pharo := "pharo/vm/Pharo.app/Contents/MacOS/Pharo"
image := "pharo/Pharo.image"
verifier_image := "pharo/Pharo.verifier.image"

_default:
    @just --list

# One-time bootstrap: fetch Pharo VM, materialise verifier image, load baseline.
install:
    ./install.sh

# Wipe pharo/Pharo.verifier.image and re-materialise the verifier image (no MCP, no Iceberg).
rebuild:
    ./install.sh --rebuild

# Wipe pharo/Pharo.image and re-materialise the dev image (with MCP + Iceberg).
rebuild-mcp:
    ./install.sh --mcp --rebuild

# Open the GUI on the materialised image.
run:
    ./bin/smallchat

# Launch the long-lived dev image (Claude Code talks to this via .mcp.json).
mcp:
    ./bin/smallchat-mcp

# Alias for `mcp`.
dev: mcp

# Remove both working images; keep the VM and seed so install is fast.
clean:
    rm -f pharo/Pharo.image pharo/Pharo.changes pharo/Pharo.verifier.image pharo/Pharo.verifier.changes

# Reserved for the future distributable-image build (load baseline into a
# clean seed, configure Iceberg for end users, strip dev state, save as
# a separate artifact). Not implemented yet -- use `install` / `rebuild`
# for the dev image.
build:
    @echo "unimplemented: build -- reserved for the distributable-image recipe. Use \`just install\` or \`just rebuild-mcp\` instead." >&2
    @exit 1

# Rebuild every arm64-darwin tree-sitter dylib under lib/tree-sitter/.
# Clones each upstream at its pinned tag into $TS_WORK_DIR (default:
# ~/Documents/tree-sitter-libraries, matching the Evref-BL binding's
# auto-build location so existing clones are reused), runs `make`,
# and copies the resulting dylibs into lib/tree-sitter/arm64-darwin/.
# Not invoked by `install` or `rebuild*` -- those use the vendored
# binaries. Run this only when bumping a pinned grammar.
rebuild-dylibs:
    #!/usr/bin/env bash
    set -euo pipefail
    WORK="${TS_WORK_DIR:-$HOME/Documents/tree-sitter-libraries}"
    VENDOR="$(pwd)/lib/tree-sitter/arm64-darwin"
    mkdir -p "$WORK" "$VENDOR"
    clone_and_make() {
        local name="$1" tag="$2" url="$3"
        local dir="$WORK/$name"
        if [ ! -d "$dir" ]; then
            git clone --depth 1 --branch "$tag" "$url" "$dir"
        fi
        make -C "$dir"
    }
    clone_and_make tree-sitter            v0.26.8 https://github.com/tree-sitter/tree-sitter.git
    clone_and_make tree-sitter-typescript v0.23.2 https://github.com/tree-sitter/tree-sitter-typescript.git
    clone_and_make tree-sitter-css        v0.25.0 https://github.com/tree-sitter/tree-sitter-css.git
    clone_and_make tree-sitter-javascript v0.25.0 https://github.com/tree-sitter/tree-sitter-javascript.git
    cp "$WORK/tree-sitter/libtree-sitter.dylib"                              "$VENDOR/"
    cp "$WORK/tree-sitter-typescript/typescript/libtree-sitter-typescript.dylib" "$VENDOR/"
    cp "$WORK/tree-sitter-typescript/tsx/libtree-sitter-tsx.dylib"           "$VENDOR/"
    cp "$WORK/tree-sitter-css/libtree-sitter-css.dylib"                      "$VENDOR/"
    cp "$WORK/tree-sitter-javascript/libtree-sitter-javascript.dylib"        "$VENDOR/"
    echo "==> Vendored dylibs (drift check: should all read 'arm64'):"
    (cd "$VENDOR" && file *.dylib)

# Run SUnit tests in every SmallChat-* package; exits non-zero on any failure or error.
# Always rebuilds the verifier image first so the run reflects on-disk src/.
# Writes to pharo/Pharo.verifier.image only, so a live dev session on
# pharo/Pharo.image is unaffected.
test *PATTERNS="SmallChat.*": rebuild
    {{pharo}} --headless {{verifier_image}} test --fail-on-failure --fail-on-error {{PATTERNS}}

# Run the Critiques linter over every SmallChat-* package; exits non-zero on any critique.
# Always rebuilds the verifier image first. Same disjoint-path property as `just test`.
lint: rebuild
    {{pharo}} --headless {{verifier_image}} st --quit lib/lint.st
