# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project goal

smallchat is a self-modifying agent that lives inside a Pharo 13 Smalltalk
image. It connects to a local LM Studio server (target model:
`qwen3.6-35b-a3b`) and exposes Smalltalk-native tool calling so the agent
can inspect and rewrite classes/methods in the same image it is running
in. The UI, agent loop, and model client are all in-image; `src/` is the
on-disk source of truth.

## Two image flavours

Two distinct images, sharing the same on-disk path (`pharo/Pharo.image`)
but never coexisting:

- **Dev image** (the working environment): a long-lived Pharo image with
  `SmallChat-MCP` loaded and Iceberg registered against the working
  tree. Claude Code talks to it over MCP via `./bin/smallchat-mcp` (per
  `.mcp.json`). The image survives across Claude sessions; in-image
  changes (compiled methods, defined classes) persist until the image
  is rebuilt or the session is replaced. Brought up by
  `just rebuild-mcp` (which calls `./install.sh --mcp --rebuild`) and
  launched by `just mcp`.

- **Verifier image**: a disposable, headless Pharo image used only for
  CI-equivalent verification. No MCP, no Iceberg, just SmallChat +
  SmallChat-Tests loaded fresh from the seed. `just test` and
  `just lint` wipe `pharo/Pharo.image` and re-materialise from `src/`
  every time. The verifier is what proves "the on-disk Tonel survives a
  fresh rebuild." Never edit anything in this image — every run wipes
  it.

- **Distributable image** (end-user artifact, not yet built): the
  shipped image will have its own Iceberg setup (different from the dev
  image's, since end users won't be cloning smallchat itself). That
  build step lives in the unimplemented `just build` slot.

## Development methodology: Red-Green TDD

All behaviour changes in this repo follow strict Red-Green-Refactor TDD.
No production code is written without a failing test that demands it.

1. **Red** — write exactly one failing test in the matching
   `SmallChat-Tests` package that describes the next slice of behaviour.
   Run `run_tests` (in-image, via MCP) and confirm it fails for the
   *right* reason (missing method / wrong result, not a syntax error or
   missing class you forgot to create). Do not write more of the test
   than is needed to fail.
2. **Green** — write the smallest amount of production code in the
   `SmallChat` package (or a sibling) that makes the failing test pass.
   "Smallest" means smallest, even if it looks silly (return a constant,
   hard-code the expected value). Run `run_tests` and confirm the suite
   is green before touching anything else.
3. **Refactor** — with the suite green, clean up duplication, rename,
   extract, or restructure. Run `run_tests` after each refactor step.
   Never mix refactor edits with behaviour changes; if a refactor
   requires a new test, stop and go back to Red.

Rules that follow from this:

- One failing test at a time. Never leave the suite with more than one
  red test.
- **Never commit on Red**, and never commit until `just test` from a
  shell also passes. The MCP `commit` tool has no automated green
  guard — the discipline lives here. In-image green via `run_tests`
  does NOT guarantee a fresh rebuild via `just test` will also pass;
  Metacello load order, dropped-but-still-in-image classes, or
  uncommitted Tonel divergence can mask real failures.
- `lint` (in-image) and `just lint` (fresh rebuild) must both be clean
  before committing; treat Critiques findings like compile errors.
- When a bug is reported, reproduce it as a failing test *first*, then
  fix it. The regression test is the deliverable, not the patch.
- If you are tempted to write production code "to see if it works",
  that's a signal the next test hasn't been written yet. Write the
  test.

## Commands

All common tasks go through `just` (see `justfile`):

```sh
just install      # first-time bootstrap (./install.sh)
just rebuild      # wipe pharo/Pharo.image and reload the verifier image
just rebuild-mcp  # wipe pharo/Pharo.image and reload the dev image (MCP + Iceberg)
just mcp          # launch the long-lived dev image (Claude Code talks to this)
just dev          # alias for mcp
just run          # open the GUI on whatever image is currently materialised
just test         # headless SUnit over every SmallChat-* package — rebuilds verifier
just lint         # headless Critiques over every SmallChat-* package — rebuilds verifier
just clean        # drop the working image, keep VM + seed
just build        # reserved for the future distributable-image recipe (not implemented)
```

`test` and `lint` always rebuild the verifier image first (they depend
on `rebuild`, which materialises the verifier flavour, NOT the dev
flavour). They are CI-equivalent: they prove the on-disk `src/` tree
plus the baseline produces a green image. They never touch the dev
image's in-memory state.

The dev image and the verifier image share `pharo/Pharo.image`. Running
`just test` while a dev session is open kills the dev image (because
`just rebuild` wipes the file). Either close the dev image first or
copy the file out of the way.

## How the repo maps to the image

The source of truth is the **Tonel tree under `src/`**. The image at
`pharo/Pharo.image` is a build artifact and is gitignored.

Primary workflow (dev image is up):

1. Use the MCP `evaluate` tool to compile classes/methods into the
   long-lived dev image. The image's compiler is the editor.
2. Use the MCP `run_tests` tool to confirm the change is green.
3. Use the MCP `status` tool to see what Iceberg considers dirty.
4. Run `just test` from a shell to confirm the change also passes a
   fresh rebuild from `src/`.
5. Use the MCP `commit` tool to write Tonel back to `src/` and create
   a git commit on the current branch.

Hand-edits to `src/` are still appropriate for files Iceberg doesn't
manage (`justfile`, `install.sh`, `lib/*.st`, `bin/*`, `CLAUDE.md`,
`.mcp.json`, baseline files). For those, edit on disk and `git commit`
directly.

**Critical caveat: code written via the Write/Edit tools is invisible
to Iceberg's commit path.** Iceberg only sees changes made in-image
during the live session. Files written to `src/` from outside the dev
image will never appear in a `commit` tool result, even if they're on
disk and even if the dev image loaded them via Metacello on startup.
Code changes go through `evaluate`; non-code changes go through Write
+ shell `git commit`.

If a hand-edit to `src/` is needed (rare), it must be followed by
`just rebuild-mcp` to bring the dev image back in sync — otherwise
the dev image's in-memory state diverges silently from disk and the
next `commit` tool call will overwrite the hand-edit.

## MCP tool surface

The dev image exposes five MCP tools (defined in `src/SmallChat-MCP/`):

| Tool | Purpose |
| --- | --- |
| `evaluate` | Run arbitrary Smalltalk; returns `printString` of the result. The workhorse — all compile/inspect/refactor goes through here. |
| `run_tests` | SUnit over packages matching a regex (default `SmallChat.*`). Returns structured `{passed, failed, errored, failures[], errors[]}`. Reflects in-image state, not disk. |
| `lint` | ReCriticEngine over matching packages. Structured `{critiques[]}`. |
| `status` | Iceberg working-copy status: branch, dirty flag, list of changes (`{changeType, target, definitionClass}`). |
| `commit` | Refreshes Tonel from in-image state and runs `commitChanges:withMessage:`. Uses git config from `~/.gitconfig`. No automated green guard. |

`evaluate` documents the Smalltalk navigation/compile/snapshot
selectors via the protocol's `instructions` string. Anything the
dedicated tools don't cover (creating classes, removing methods,
inspecting senders) is composed on top of `evaluate`.

## Snapshot hygiene

The dev image is long-lived, so a VM crash loses any in-image state
that hasn't been written to Tonel. Two safeguards:

- A successful `commit` flushes in-image changes to `src/` on disk
  before creating the git commit. Anything that's been committed
  survives a crash via git.
- For long-running work between commits (large refactor, exploration),
  snapshot explicitly:
  ```smalltalk
  Smalltalk snapshot: true andQuit: false
  ```
  This saves the image state in place. **Never `andQuit: true`** —
  that terminates the MCP server too.

## Baseline layout

- `BaselineOfSmallChat` — declares the packages and groups:
  - `default` (verifier): `SmallChat`, `SmallChat-Tests`
  - `dev` (MCP image): adds `SmallChat-MCP`
  - Plus narrower groups (`core`, `tests`, `mcp`) for ad-hoc loads.
  Add new packages here, not in `lib/load-packages.st`.
- `SmallChat` package — application code. `SmallChatApp` is the entry
  point; the agent loop, LM Studio client, and chat UI hang off it.
- `SmallChat-Tests` package — SUnit test cases. `just test` matches
  packages against `SmallChat.*`, so any new test package whose name
  starts with `SmallChat-` is picked up automatically.
- `SmallChat-MCP` package — MCP server, vendored from akkuna. Loaded
  only in the dev image (via the `dev` group). Lint and tests run
  against it just like any other package when the dev image is up.

## Pharo gotchas (general)

- `install.sh` is idempotent. The VM and seed are downloaded only if
  missing; the working image is rebuilt if absent or if `--rebuild` is
  passed. `just test` and `just lint` both trigger `--rebuild` for the
  verifier flavour; `just rebuild-mcp` triggers `--rebuild --mcp` for
  the dev flavour.
- Headless loads must use `--save` (as in `install.sh`); otherwise the
  loaded baseline is discarded when the VM exits.
- The verifier image is disposable. Nothing inside it survives the
  next `just test` run — anything that matters belongs in `src/`.
- The dev image is long-lived. In-image changes survive between MCP
  calls, but a `just rebuild-mcp` (or any `just test` / `just lint`)
  wipes it.

## MCP server hard constraints (inherited from akkuna)

These are non-negotiable for any code in `SmallChat-MCP/`. They are
encoded in the vendored akkuna source and were hard-won:

- **Stdout is reserved for MCP JSON-RPC framing.** Any write to stdout
  from Pharo code corrupts the channel. `muteTranscriptToStdout` runs
  on server start; never `Transcript show:` from reader-path code.
  Use `SmallChatMCPServer logToFile:` (writes to
  `pharo/smallchat-mcp.log`) or `logToStderr:`.
- **No embedded newlines in MCP messages.** Use `STONJSON toString:`
  (compact). NeoJSON is not in the base Pharo image.
- **`Stdio stdin next` returns bytes vs Characters inconsistently** —
  `readLine` normalises via `isInteger`/`asInteger`. Don't simplify.
- **Launch via `open -n -a Pharo.app --args IMAGE`** (macOS
  LaunchServices). Direct `exec` beachballs on first window click.
- **TCP bridge via BSD `nc`** without `-N` (macOS doesn't recognise
  it; the BSD default already half-closes on stdin EOF, which is what
  Claude Code expects).
- **`pharo/mcp.port` handshake.** Shell polls; Pharo writes on
  `SmallChatMCPTcpServer>>start`. Stale port files are removed before
  relaunch.
- **`SMALLCHAT_NO_GUI=1` opt-in headless mode** uses
  `eval --no-quit '1'` to keep the VM alive while the MCP reader pumps
  stdin.
- **`Smalltalk vm imageFile parent`**, NOT `imageDirectory` (latter
  doesn't exist in newer VMs).
- **`waitForStdinData` uses a fresh Semaphore per call.** The shared
  one in `AbstractBinaryFileStream` stops signalling on stdin after
  ~3 reads on Pharo 14; the fresh-Semaphore pattern is defensive on
  Pharo 13 and required on 14.
- **`UIManager default defer: [ ... ]`** for any Morphic/Spec2 window
  op from tool code. The MCP reader runs on a forked process; opening
  a window from it can deadlock the VM.
- **`on: Notification do: [:n | n resume]`** wraps tool execution in
  `SmallChatToolRegistry>>run:with:`. Pharo's default notification
  handler writes to stdout (deprecation warnings, Metacello progress)
  and would corrupt MCP framing.
- **SessionManager `startUp:/shutDown:` fire on save-and-continue**,
  not just on quit. Both `SmallChatMCPServer` and
  `SmallChatMCPTcpServer` clear `running` on `shutDown:` and rebind
  stdio on `start`.

## Iceberg gotchas (Pharo 13)

- **`Package>>isLoaded` shim.** Pharo 13 renamed `RPackage` to
  `Package` and dropped `#isLoaded`. Iceberg's `IceCommit` calls it
  on every iterated package; without the shim,
  `workingCopyDiff` and `modifiedPackages` raise
  DoesNotUnderstand. `lib/iceberg-setup.st` installs the shim
  unconditionally.
- **`IceRepositoryCreator>>addLocalRepository` ignores
  `subdirectory:`.** The right sequence is `location:; subdirectory:;
  ensureProjectFile; addLocalRepository` so `IceBasicProject` is
  created with `src/` as its source directory. `addLocalRepository`
  also doesn't register the repo — call `IceRepository
  registerRepository:` afterward.
- **Newly-attached packages look like all-additions.** After
  `basicAddPackage:`, `workingCopyDiff` reports every class and method
  as `IceAddition` because Iceberg's package state is empty. Call
  `workingCopy refreshPackages` after attaching to reconcile against
  HEAD.
- **`commit` only sees in-image changes made during the session.**
  Files added to `src/` via the Write tool (or any path other than
  in-image compilation) are invisible to `workingCopyDiff` and won't
  appear in a `commit` tool call. See "How the repo maps to the
  image" above.
