# tree-sitter native libraries

The Evref-BL/Pharo-Tree-Sitter binding loads four grammar libraries
and the core runtime via FFI. We keep them out of git and build them
on demand from pinned upstream tags.

## Layout

```
lib/tree-sitter/
  README.md           # this file (tracked)
  sources/            # gitignored; clones written by bin/build-dylibs
    tree-sitter/
    tree-sitter-typescript/
    tree-sitter-css/
    tree-sitter-javascript/
  arm64-darwin/       # per-platform *.dylib (gitignored)
  x86_64-darwin/      # same, future
  x86_64-linux/       # *.so  (future)
  aarch64-linux/      # *.so  (future)
```

Per-platform directories are created on demand. `bin/build-dylibs`
derives `<platform>` from `uname -s` / `uname -m`; `install.sh`
stages the resulting libraries into
`pharo/vm/Pharo.app/Contents/MacOS/Plugins/`, which is where
`FFIMacLibraryFinder` searches.

## Build on demand

`install.sh` counts the shared libraries under
`lib/tree-sitter/<platform>/` and invokes `bin/build-dylibs` when
fewer than five are present. First-time runs clone the four upstream
repos into `sources/` and run `make` in each; subsequent runs are
no-ops (the five files already exist).

```sh
./bin/build-dylibs          # idempotent; builds what is missing
./bin/build-dylibs --force  # wipe sources/ + <platform>/ and rebuild
just rebuild-dylibs         # alias for --force; use after bumping a tag
```

If a build silently fails to produce a library, the
`SmallChatTreeSitterHealth` class (in `src/SmallChat/`) reports
missing libraries at image-load time. `lib/load-packages.st` calls
`reportOn: Transcript` in the MCP branch, and
`SmallChatTreeSitterHealthTest` covers the happy path in `just test`.

## Pinned upstreams

Tags live in `bin/build-dylibs`. Bump the tag there, record the new
SHA below in the same change, and rerun with `--force`.

| Library                       | Repo                                            | Tag      | Commit     |
| ----------------------------- | ----------------------------------------------- | -------- | ---------- |
| `libtree-sitter.*`            | `github.com/tree-sitter/tree-sitter`            | `v0.26.8`| `cd5b087c` |
| `libtree-sitter-typescript.*` | `github.com/tree-sitter/tree-sitter-typescript` | `v0.23.2`| `f975a621` |
| `libtree-sitter-tsx.*`        | (same repo, `tsx/` subdir)                      | `v0.23.2`| `f975a621` |
| `libtree-sitter-css.*`        | `github.com/tree-sitter/tree-sitter-css`        | `v0.25.0`| `dda5cfc5` |
| `libtree-sitter-javascript.*` | `github.com/tree-sitter/tree-sitter-javascript` | `v0.25.0`| `44c892e0` |

## `file` output (drift-check pin, arm64-darwin)

```
libtree-sitter.dylib:            Mach-O 64-bit dynamically linked shared library arm64
libtree-sitter-typescript.dylib: Mach-O 64-bit dynamically linked shared library arm64
libtree-sitter-tsx.dylib:        Mach-O 64-bit dynamically linked shared library arm64
libtree-sitter-css.dylib:        Mach-O 64-bit dynamically linked shared library arm64
libtree-sitter-javascript.dylib: Mach-O 64-bit dynamically linked shared library arm64
```

`bin/build-dylibs` prints this block on success. Refresh the pin
after a legitimate arch change; treat an unexpected diff as a review
signal.

Non-goal: cross-compilation. Each platform builds on its own host.
