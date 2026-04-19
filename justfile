# smallchat task runner. Run `just` with no args to list recipes.

set shell := ["bash", "-euo", "pipefail", "-c"]

pharo := "pharo/vm/Pharo.app/Contents/MacOS/Pharo"
image := "pharo/Pharo.image"

_default:
    @just --list

# One-time bootstrap: fetch Pharo VM, materialise verifier image, load baseline.
install:
    ./install.sh

# Wipe pharo/Pharo.image and re-materialise the verifier image (no MCP, no Iceberg).
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

# Remove the working image; keep the VM and seed so install is fast.
clean:
    rm -f pharo/Pharo.image pharo/Pharo.changes

# Reserved for the future distributable-image build (load baseline into a
# clean seed, configure Iceberg for end users, strip dev state, save as
# a separate artifact). Not implemented yet -- use `install` / `rebuild`
# for the dev image.
build:
    @echo "unimplemented: build -- reserved for the distributable-image recipe. Use \`just install\` or \`just rebuild-mcp\` instead." >&2
    @exit 1

# Run SUnit tests in every SmallChat-* package; exits non-zero on any failure or error.
# Always rebuilds the verifier image first so the run reflects on-disk src/.
test *PATTERNS="SmallChat.*": rebuild
    {{pharo}} --headless {{image}} test --fail-on-failure --fail-on-error {{PATTERNS}}

# Run the Critiques linter over every SmallChat-* package; exits non-zero on any critique.
# Always rebuilds the verifier image first.
lint: rebuild
    {{pharo}} --headless {{image}} st --quit lib/lint.st
