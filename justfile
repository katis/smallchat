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

# Reserved for the future distributable-image build (load baseline into a
# clean seed, configure Iceberg for end users, strip dev state, save as
# a separate artifact). Not implemented yet — use `install` / `rebuild`
# for the dev image.
build:
    @echo "unimplemented: build — reserved for the distributable-image recipe. Use \`just install\` or \`just rebuild\` for the dev image." >&2
    @exit 1

# Run SUnit tests in every SmallChat-* package; exits non-zero on any failure or error.
# Depends on `rebuild` so the image always reflects the on-disk src/ tree.
test *PATTERNS="SmallChat.*": rebuild
    {{pharo}} --headless {{image}} test --fail-on-failure --fail-on-error {{PATTERNS}}

# Run the Critiques linter over every SmallChat-* package; exits non-zero on any critique.
# Depends on `rebuild` so the image always reflects the on-disk src/ tree.
lint: rebuild
    {{pharo}} --headless {{image}} st --quit lib/lint.st
