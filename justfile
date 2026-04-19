# smallchat task runner. Run `just` with no args to list recipes.

set shell := ["bash", "-euo", "pipefail", "-c"]

pharo := "pharo/vm/Pharo.app/Contents/MacOS/Pharo"
image := "pharo/Pharo.image"

_default:
    @just --list

# One-time bootstrap: fetch Pharo VM, materialise image, load baseline.
install:
    ./install.sh

# Wipe pharo/Pharo.image and re-materialise from the seed + src/ baseline.
rebuild:
    ./install.sh --rebuild

# Open the GUI on the materialised image.
run:
    ./bin/smallchat

# Remove the working image; keep the VM and seed so `just install` is fast.
clean:
    rm -f pharo/Pharo.image pharo/Pharo.changes

# Unimplemented: Pharo has no separate build step (use `install` / `rebuild`).
build:
    @echo "unimplemented: build — use \`just install\` (first run) or \`just rebuild\` (from source)." >&2
    @exit 1

# Run SUnit tests in every SmallChat-* package; exits non-zero on any failure or error.
test *PATTERNS="SmallChat.*":
    {{pharo}} --headless {{image}} test --fail-on-failure --fail-on-error {{PATTERNS}}

# Run the Critiques linter over every SmallChat-* package; exits non-zero on any critique.
lint:
    {{pharo}} --headless {{image}} st --quit lib/lint.st
