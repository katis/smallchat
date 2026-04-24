# Vendored tree-sitter dylibs (arm64-darwin)

These are the native libraries the Evref-BL/Pharo-Tree-Sitter
binding loads via FFI. `install.sh` copies them into
`pharo/vm/Pharo.app/Contents/MacOS/Plugins/` so
`FFIMacLibraryFinder` resolves them on first FFI call.

Rebuild any or all with `just rebuild-dylibs`. See `justfile`.

## Pinned upstreams

| Dylib                             | Repo                                                | Tag      | Commit     |
| --------------------------------- | --------------------------------------------------- | -------- | ---------- |
| `libtree-sitter.dylib`            | `github.com/tree-sitter/tree-sitter`                | `v0.26.8`| `cd5b087c` |
| `libtree-sitter-typescript.dylib` | `github.com/tree-sitter/tree-sitter-typescript`     | `v0.23.2`| `f975a621` |
| `libtree-sitter-tsx.dylib`        | (same repo, `tsx/` subdir)                          | `v0.23.2`| `f975a621` |
| `libtree-sitter-css.dylib`        | `github.com/tree-sitter/tree-sitter-css`            | `v0.25.0`| `dda5cfc5` |
| `libtree-sitter-javascript.dylib` | `github.com/tree-sitter/tree-sitter-javascript`     | `v0.25.0`| `44c892e0` |

## `file` output (drift check)

```
libtree-sitter.dylib:            Mach-O 64-bit dynamically linked shared library arm64
libtree-sitter-typescript.dylib: Mach-O 64-bit dynamically linked shared library arm64
libtree-sitter-tsx.dylib:        Mach-O 64-bit dynamically linked shared library arm64
libtree-sitter-css.dylib:        Mach-O 64-bit dynamically linked shared library arm64
libtree-sitter-javascript.dylib: Mach-O 64-bit dynamically linked shared library arm64
```

Re-run `file *.dylib` after a rebuild and compare; a diff in this
file means the architecture or format changed and that is a
review-worthy signal.

## Build recipe (manual, per grammar)

Clone into an out-of-tree work dir (default:
`~/Documents/tree-sitter-libraries/` — same location the binding's
auto-build uses, so existing clones are reused):

```sh
# Core runtime
git clone --depth 1 --branch v0.26.8 \
  https://github.com/tree-sitter/tree-sitter.git
make -C tree-sitter

# TypeScript (produces typescript/ and tsx/ dylibs from one make)
git clone --depth 1 --branch v0.23.2 \
  https://github.com/tree-sitter/tree-sitter-typescript.git
make -C tree-sitter-typescript

# CSS
git clone --depth 1 --branch v0.25.0 \
  https://github.com/tree-sitter/tree-sitter-css.git
make -C tree-sitter-css

# JavaScript
git clone --depth 1 --branch v0.25.0 \
  https://github.com/tree-sitter/tree-sitter-javascript.git
make -C tree-sitter-javascript
```

Copy the resulting dylibs into this directory:

```
tree-sitter/libtree-sitter.dylib
tree-sitter-typescript/typescript/libtree-sitter-typescript.dylib
tree-sitter-typescript/tsx/libtree-sitter-tsx.dylib
tree-sitter-css/libtree-sitter-css.dylib
tree-sitter-javascript/libtree-sitter-javascript.dylib
```

Non-goal: cross-compilation. Build on arm64 macOS.
