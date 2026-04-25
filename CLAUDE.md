# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project goal

smallchat is a self-modifying agent that lives inside a Pharo 13
Smalltalk image. It connects to a local LM Studio server (target
model: `Qwen3.6-35B-A3B-nvfp4`) and exposes Smalltalk-native tool
calling so the agent can inspect and rewrite classes/methods in the
same image it is running in. The UI, agent loop, and model client
are all in-image; the Tonel tree under `src/` is the on-disk source
of truth.

## Two image flavours

Disjoint on-disk paths so the verifier can rebuild without disturbing
a live dev session:

- **Dev image** (`pharo/Pharo.image`): long-lived, with `SmallChat-MCP`
  loaded and Iceberg registered against the working tree. Claude Code
  talks to it over MCP via `./bin/smallchat-mcp` (see `.mcp.json`).
  In-image changes (compiled methods, defined classes) persist across
  Claude sessions until the image is rebuilt. Brought up by
  `just rebuild-mcp`; launched by `just mcp`.
- **Verifier image** (`pharo/Pharo.verifier.image`): disposable and
  headless. `just test` and `just lint` wipe it and re-materialise
  from `src/` every run — this is what proves the on-disk Tonel
  survives a fresh rebuild. Never edit inside this image.

## Commands

```sh
just install      # first-time bootstrap (./install.sh)
just rebuild      # rebuild verifier image from src/
just rebuild-mcp  # rebuild dev image (MCP + Iceberg)
just mcp          # launch the dev image (Claude Code talks to this)
just dev          # alias for mcp
just run          # open the GUI on the dev image
just test         # headless SUnit over SmallChat-* — rebuilds verifier
just lint         # headless Critiques over SmallChat-* — rebuilds verifier
just clean        # drop both working images, keep VM + seed
```

`just test` / `just lint` rebuild the verifier flavour only, so they
are safe to run while a dev session is live — disjoint image paths.
They are the CI-equivalent gate: fresh image, reloaded from `src/`.

## How the repo maps to the image

`src/` (Tonel) is the source of truth. `pharo/Pharo.image` is a
gitignored build artifact.

Primary workflow (dev image is up):

1. `evaluate` to compile classes/methods into the dev image — the
   image's compiler is the editor.
2. `run_tests` to confirm the change is green.
3. `status` to see what Iceberg considers dirty.
4. To flush in-image state to disk *without* committing (so the next
   `just test` sees it):
   ```smalltalk
   | repo |
   repo := IceRepository registry detect: [ :r | r name = 'smallchat' ].
   repo workingCopy refreshDirtyPackages.
   repo index updateDiskWorkingCopy: repo workingCopyDiff
   ```
5. `just test` (and `just lint`) from a shell to confirm a fresh
   rebuild from `src/` still passes.
6. `commit` writes Tonel back to `src/` and creates the git commit.

Hand-edits to `src/` are appropriate only for files Iceberg doesn't
manage: `justfile`, `install.sh`, `lib/*.st`, `bin/*`, `CLAUDE.md`,
`.mcp.json`, baseline files. Edit on disk and `git commit` directly.

**Code written via Write/Edit is invisible to Iceberg's commit
path.** Iceberg only sees in-image changes. Files written to `src/`
from outside the dev image never appear in a `commit` result, even
if loaded via Metacello on startup. Code goes through `evaluate`;
non-code goes through Write + shell `git commit`. If a hand-edit to
an Iceberg-managed file is unavoidable, `just rebuild-mcp` afterwards
to resync — otherwise the next `commit` will overwrite it.

## MCP tool surface

Core:

| Tool | Purpose |
| --- | --- |
| `evaluate` | Run arbitrary Smalltalk; returns `printString` of the result. Uncaught exceptions land in a captured debug session. The workhorse — all compile/inspect/refactor goes through here. |
| `run_tests` | SUnit over packages matching a regex (default `SmallChat.*`). Returns `{passed, failed, errored, failures[], errors[]}`. Pass `debug_first_failure: true` to capture the first failing test as a debug session. Reflects in-image state, not disk. |
| `lint` | ReCriticEngine over matching packages. Returns `{critiques[]}`. |
| `status` | Iceberg working-copy status: branch, dirty flag, `{changeType, target, definitionClass}` changes. |
| `commit` | Refreshes Tonel from in-image state and runs `commitChanges:withMessage:`. Uses `~/.gitconfig`. **No automated green guard.** |

Debug-session tools (operate on sessions captured by `evaluate`
always or `run_tests debug_first_failure: true` opt-in):

| Tool | Purpose |
| --- | --- |
| `debug_sessions` | List active sessions: `[{id, exceptionClass, messageText, topFrame, createdAtMs}]`. |
| `debug_stack` | Stack summary (args: `sessionId`, optional `limit`). |
| `debug_frame` | Frame detail at index — receiver, selector, args, temps, source. |
| `debug_evaluate` | Evaluate an expression in a frame's context (`self`/args/temps in scope). Sharpest tool for root-causing. |
| `debug_return` | Resume, substituting `expression`'s value for the signalling expression. If user code finishes, returns its final result; re-raise captures a new session. Rejected on stepped sessions. |
| `debug_proceed` | Resume with `nil`. |
| `debug_restart` | Restart a frame from its method entry (args: `sessionId`, optional `index`, default 0). Typically `index: 1` to retry the user frame after compiling a fix. |
| `debug_step_over` | Advance one message-send past the current context, pausing at the new location. First call pops the handler+suspend frames (nil-substituting the signalling expression); subsequent calls advance further. Session keeps its id and is marked stepped. |
| `debug_step_into` | Like `debug_step_over` but enters the called method. Two calls are typically needed from a post-capture DoIt: first reaches the next send-site, second enters the callee. |
| `debug_terminate` | Drop the session and terminate its parked process. |

`evaluate`'s protocol `instructions` string documents the Smalltalk
navigation/compile/snapshot selectors. Anything the dedicated tools
don't cover (creating classes, removing methods, inspecting senders)
composes on top of `evaluate`.

### Debug-session mechanics

Uncaught exceptions from `evaluate` (always) and `run_tests` (opt-in)
are captured by `SmallChatDebugEvaluator`: user code runs on a fork,
an `on: Exception do:` handler builds a `DebugSession` wrapped in a
`SindarinDebugger`, registers it in `SmallChatDebugSessionRegistry`,
and parks the fork in `suspend` with its stack intact. The MCP
reader never blocks — it handles further calls (including `debug_*`
tools against the parked fork) while the fork sleeps.

Registry safety rails:

- **Max 8 concurrent sessions.** The 9th evicts the oldest (LRU) and
  terminates that fork.
- **10-minute idle TTL.** Stale sessions are reaped on next registry
  access. Bump `SmallChatDebugSessionRegistry default ttlMilliseconds:`
  up-front for long cycles.
- `debug_terminate` always kills the parked process — never leak.

### Stray UI debugger windows

Exceptions raised *outside* the `SmallChatDebugEvaluator` fork — on
the Morphic UI process, on user-spawned `[...] fork` blocks, inside
`UIManager default defer: [...]`, or from Morphic step methods — are
not captured. Pharo's default debug-request path opens an `StDebugger`
window on the UI process, which sits there waiting on a human who
isn't present. These windows are **invisible to `debug_sessions`**
and cannot be inspected via the `debug_*` tools.

`SmallChatToolRegistry` detects them and prepends a warning to every
tool reply:

    [smallchat: N stray Pharo UI debugger window(s) open -- these
    block the dev image's UI process. Dismiss via:
    SmallChatDebuggerWatch closeAll]

When you see this prefix:

1. **Don't ignore it.** Stray debuggers pile up, consume UI-process
   cycles, and make `World imageForm` screenshots noisy or useless.
2. **Inspect first if the underlying error matters.**
   - `evaluate 'SmallChatDebuggerWatch openWindows'` — list descriptors
     (`modelClass` / `presenterClass` / `title`).
   - Screenshot `World imageForm` to read the stack from pixels.
   - These debuggers are **not** on the `SmallChatDebugSessionRegistry`,
     so `debug_stack` / `debug_frame` / `debug_evaluate` won't work on
     them.
3. **Reproduce under evaluator control** if you need a real debug
   session. Identify the code path that raised, call it through
   `evaluate` (not `fork`, not `UIManager defer:`), and the exception
   will land in a captured session the `debug_*` tools can drive.
4. **Dismiss** once you're done:
   `evaluate 'SmallChatDebuggerWatch closeAll'`. Returns the number
   of windows dismissed.

The warning is the only channel — the MCP reader never blocks on the
UI process, so without reading the prefix you'd never know debuggers
accumulated.

## Development methodology: Red-Green TDD

All behaviour changes follow strict Red-Green-Refactor TDD. No
production code is written without a failing test demanding it.

1. **Red** — one failing test in the matching `SmallChat-*Tests`
   package describing the next slice. `run_tests` must fail for the
   *right* reason (missing method / wrong result — not syntax or a
   missing class). Don't write more of the test than is needed.
2. **Green** — smallest production code that passes. Smallest means
   smallest, even if silly (return a constant, hard-code the
   expected value).
3. **Refactor** — with the suite green, clean up. Never mix refactor
   edits with behaviour changes; if a refactor needs a new test, go
   back to Red.
4. **Micro-commit** — as soon as Green (or Green+Refactor) is stable,
   call `commit` to flush Tonel and land a small commit. Every Green
   becomes a crash-safe checkpoint: if the dev image freezes, the VM
   is killed, or `updateDiskWorkingCopy:` gets stuck mid-flush (this
   has happened repeatedly), git holds everything up to the last
   micro-commit. Don't batch Greens — a long burst of unflushed
   in-image work is exactly the window an Iceberg CPU-spin can
   swallow. Tiny messages, prefixed by the larger feature:

       chat-client: post to /v1/chat/completions
       chat-client: parse choices[0].message.content
       chat-client: split thinking from content

Rules:

- One failing test at a time. Never leave the suite with more than
  one red test.
- **Never commit on Red.** The feature isn't done until `just test`
  and `just lint` pass from a fresh rebuild — run both at the end of
  a session as the final gate, and fix forward with new commits if
  they uncover divergence. `commit` has no automated green guard; the
  discipline lives here. In-image green does NOT guarantee a fresh
  rebuild will also pass — Metacello load order, dropped-but-still-
  in-image classes, or uncommitted Tonel divergence can mask failures.
- `lint` must be clean (in-image and fresh rebuild) before committing.
  Treat Critiques findings like compile errors.
- Bug reports get a reproducing failing test *first*, then the fix.
  The regression test is the deliverable.
- Tempted to write production code "to see if it works"? That's a
  signal the next test hasn't been written yet. Write the test.
- **Design the test seam before the test.** When behaviour binds to
  real I/O (sockets, Morphic events, HTTP, the listener loop),
  extract the isolating helper first — e.g. `updateRunning:` for a
  `running` flip, `runClientSessionOn:` for the per-connection JSON-
  RPC loop — then test the helper. Back-filling a seam after the
  test has committed to the real thing wastes a cycle.
- **Trust the wire for one-line hooks.** `aWindow whenClosedDo:
  [ self cleanup ]` and similar external callbacks don't need an
  end-to-end test — unit-test `cleanup` as a pure method and eyeball
  the one-liner in `initializeWindow:`. Same for Morphic event
  handlers: test the handler, trust the binding.

## Preferred entry point: program via DNU

**When adding a new method, let a `doesNotUnderstand:` capture drive
the work.** Red-Green-Refactor-Micro-commit still applies in full —
DNU adds the *entry point*: the caller has already pinned receiver
class, selector, and arg shapes, and the captured session survives
across tests, lint, and commit, so you complete a full TDD cycle per
missing method and resume the original caller in place.

The loop for each missing method:

1. **Hit the DNU.** `evaluate` (or `run_tests`) the higher-level
   code. Read the signature off the captured session: `debug_frame 0`
   plus `debug_evaluate 0 'aMessage selector'` /
   `'aMessage arguments'` / `'self class name'`.
2. **Red.** Write one SUnit test in `SmallChat-*Tests` exercising the
   behaviour the DNU implies. `run_tests` narrowed by selector regex
   — confirm it fails for the right reason. The DNU itself is **not**
   a red test — it's suspended on a fork, invisible to `run_tests`.
   You still need a durable SUnit test before Green.
3. **Green.** Compile via
   `evaluate 'ClassName compile: ''…'' classified: ''…'''`.
   `run_tests` — green.
4. **Refactor.** Same rule as usual: no mixing with behaviour.
5. **Micro-commit.** `commit`. The parked debug session is unaffected
   — `commit` walks Iceberg state on the reader process, not the fork.
6. **Continue the debugger.** `debug_restart <sessionId>` on the
   **caller frame** — the one above `doesNotUnderstand:` (typically
   index 1 for a one-liner from `evaluate`, higher when driven
   through test or app code). Restarting the caller re-dispatches
   `self <selector>` and picks up the fresh method. A next missing
   piece captures a new session — loop back to step 1.

**Never restart the `doesNotUnderstand:` frame itself (or the
just-compiled method's frame).** Captured contexts hold direct
`CompiledMethod` pointers; restart-in-place replays old bytecodes
and re-raises the same DNU. Always restart higher, where the next
*send* triggers a fresh lookup.

When *not* to use DNU-driven entry (fall back to plain TDD against
a SUnit test):

- **Pure refactoring** — no new selector, so no DNU.
- **New classes with no caller yet.** Class lookup fails at parse
  time (`OCUndeclaredVariableNotice`), not as a runtime DNU. Create
  the class via `evaluate` first, then let a caller DNU drive the
  methods.
- **Bug in an existing method.** A reproducing test is the entry
  point, not a DNU.
- **Expensive / non-idempotent caller setup** (live network,
  stateful external system). Use a unit test against a fixture.

## Snapshot hygiene

The dev image is long-lived, so a VM crash loses any in-image state
not flushed to Tonel. Two safeguards:

- A successful `commit` flushes in-image changes to `src/` before
  creating the git commit — anything committed survives a crash
  via git.
- For long work between commits, snapshot explicitly:
  ```smalltalk
  Smalltalk snapshot: true andQuit: false
  ```
  **Never `andQuit: true`** — that terminates the MCP server too.

## Baseline layout

- `BaselineOfSmallChat` declares packages and groups:
  - `default` (verifier): `SmallChat`, `SmallChat-LM`, `SmallChat-MCP`,
    `SmallChat-Tests`. The verifier loads MCP too so MCP-dependent
    tests (debug-session family) run in `just test`.
  - `dev` (MCP image): `default` plus Iceberg + session-manager
    wiring.
  - Narrower groups (`core`, `tests`, `mcp`) for ad-hoc loads.

  Add new packages here, not in `lib/load-packages.st`.
- `SmallChat` — application code. `SmallChatApp` is the entry point;
  agent loop, LM Studio client, and chat UI hang off it.
- `SmallChat-Tests` — SUnit cases. `just test` matches `SmallChat.*`,
  so any new `SmallChat-*Tests` package is picked up automatically.
- `SmallChat-MCP` — MCP server (vendored from akkuna) plus the
  in-image debugger runner (`SmallChatDebugEvaluator`,
  `SmallChatDebugSessionRegistry`, `SmallChatDebug*Tool`).
- **Update `spec requires:` in the same change that introduces a
  cross-package reference.** Iceberg doesn't manage the baseline,
  so edit `BaselineOfSmallChat.class.st` on disk and shell-commit.
  Missed deps don't fail `just test`/`just lint` but surface as
  `NewUndeclaredWarning` during rebuild — a real load-order bug
  waiting to bite.

## Pharo gotchas

- **Never trigger Pharo's UI debugger from code not routed through
  `SmallChatDebugEvaluator`.** The MCP reader runs on a fork; a modal
  UI debugger on the reader's stack deadlocks MCP, and dismissing
  via the X often kills the reader. `evaluate` and `run_tests
  debug_first_failure: true` already capture into suspended debug
  sessions. For other code paths (chat agent loop, Morphic handlers,
  test-runner machinery):
  - Use `TestCase>>run` (or `suite run`) for programmatic test runs
    — they return a `TestResult` and never open the debugger. Avoid
    `runCase`, which re-raises into the UI.
  - Wrap risky one-shot expressions with
    `[ ... ] on: Error, TestFailure do: [ :e | e messageText ]` so
    failures return a string.
  - If a debugger does open, click **Return** (not the X) to unwind
    the frame and free the reader.
- Headless loads must use `--save` (as in `install.sh`); otherwise
  the loaded baseline is discarded at VM exit.
- `install.sh` is idempotent. The VM and seed are downloaded only
  if missing; the working image is rebuilt on `--rebuild`. `just
  test`/`just lint` pass `--rebuild` for the verifier flavour;
  `just rebuild-mcp` passes `--rebuild --mcp` for the dev flavour.
- **Creating classes via `evaluate`:** `TestCase subclass: #Name`
  returns the class but leaves it in `_UnpackagedPackage`. Follow
  with `'SmallChat-Tests' asPackage addClass: cls` to place it.
  Instance vars go on via `addInstVarNamed:`. The old one-liner
  `subclass:instanceVariableNames:classVariableNames:package:` is
  gone in Pharo 13.
- **`'pkg' asPackage` raises `NotFound` for empty packages.** A
  newly-declared `package.st` that hasn't yet had a class added is
  invisible to `PackageOrganizer`. `evaluate 'PackageOrganizer
  default ensurePackage: ''SmallChat-X'''` first, then
  `'SmallChat-X' asPackage addClass: cls` succeeds.
- **ASCII only in Smalltalk source — strings AND comments.** Tonel
  round-trips arbitrary unicode as mojibake. BMP non-ASCII (`…`,
  `π`, smart quotes, em-dash) shows up as Latin-1 garbage in the
  UI. Astral chars (`😀`, any 4-byte UTF-8 codepoint) come back as
  invalid UTF-8 and break the next image rebuild outright in
  `ZnUTF8Encoder>>ensureAtBeginOfCodePointOnStream:` — every
  `just rebuild` / `just rebuild-mcp` fails until the offending
  comment is patched. Construct genuine unicode at runtime
  (`Character codePoint: 16r1F600`); in comments, use a
  `<U+XXXX>` placeholder.
- **Screenshot the GUI for visual UI verification.** Spec2 layout
  assertions prove wire-up, not pixels — any UI-touching slice
  deserves a rendered-pixel check at the end:

  ```smalltalk
  | form path |
  form := World imageForm.
  path := '/tmp/smallchat-shot.png'.
  PNGReadWriter putForm: form onFileNamed: path.
  path
  ```

  Then Read the PNG from the harness. Use `aWindow imageForm` for a
  tighter shot of one window. Never call `Screenshot>>makeAScreenshot`
  — it opens a modal chooser that deadlocks the MCP reader. Use
  sparingly (~80 KB per shot); end of a feature, not every Green.

## Subprocesses from `evaluate`

**`evaluate` has no timeout. A blocking call inside it hangs the
tool, and an abort (user cancel) can take the MCP reader with it.**
Every pattern below exists because it was learned the hard way.
When interacting with `OSSubprocess` or anything else that does
blocking I/O, read this section first.

- **Stdout defaults to a NON-BLOCKING pipe.** `proc stdoutStream
  next` returns `nil` **immediately** when no bytes are buffered —
  it does **not** mean EOF. Naive read-until-nil treats "no data
  yet" as end-of-stream and bails before the child has spoken.
- **Switching to a blocking pipe is worse unless you know the child
  will write.** `proc defaultWriteStreamCreationBlock: [ proc
  systemAccessor makeBlockingPipe ]` makes `next` block on an empty
  pipe — if the child never writes, `evaluate` hangs forever.
  Silent child + blocking read = the canonical deadlock.
- **Always poll with an absolute deadline AND check `isRunning`.**
  Distinguish three cases: got-a-char, timeout-expired, child-died.

      | readOneChar |
      readOneChar := [ :deadlineMs | | c |
        c := nil.
        [ c := proc stdoutStream next.
          c notNil ] whileFalse: [
            Time millisecondClockValue > deadlineMs
              ifTrue: [ ^ #timeout ].
            proc isRunning ifFalse: [ ^ #eof ].
            (Delay forMilliseconds: 20) wait ].
        c ].

  Short per-char deadline (~3-5s) keeps `evaluate` responsive even
  when the child wedges.
- **Wrap every subprocess in an `ensure:` teardown.**

      proc := OSSUnixSubprocess new command: …; run.
      [ "…protocol code…" ] ensure: [
        proc isRunning ifTrue: [
          proc stdinStream close.  "let the child exit cleanly"
          (Delay forMilliseconds: 200) wait.
          proc isRunning ifTrue: [ proc terminate ] ] ].

  Without this, an unhandled exception (or a canceled `evaluate`)
  leaves the child alive and holding its stdin. `OSSubprocess
  child watcher` auto-reaps *exited* children, but a child blocked
  on stdin never exits — that's the real leak hazard.
- **PATH is not inherited from your shell.** fnm / volta / asdf /
  pnpm shims that live under `~/Library/Caches/...` or
  `~/.local/share/...` are invisible to the subprocess. Pass
  absolute binary paths or set `proc envVariables:
  (Dictionary new at: 'PATH' put: '...'; …)`.
- **Don't launch long-lived servers inside `evaluate`.** One-shot
  probes are fine (LSP handshake, version check). For anything
  that stays alive across tool calls (LSP client, watcher
  processes), own the subprocess on a dedicated Pharo Process,
  register it in a class-side registry, and expose
  lifecycle/teardown selectors — the same model `SmallChatMCP
  TcpServer` uses.
- **Recovery when `evaluate` hangs.**
  1. From a shell, `pkill` the stuck child (`pkill -9 -f
     '<command-fragment>'`). That often unblocks the evaluate.
  2. If the evaluate is already canceled but the child persists:
     `ps aux | grep <cmd>` to confirm, then `pkill`. Don't trust
     OSSubprocess to clean up abandoned children.
  3. If the MCP session dies outright, `/mcp` reconnects — the
     Pharo image survived, only the reader's stdin died. Run
     `ps aux | grep Pharo` to confirm the VM is still up before
     reaching for `just rebuild-mcp`.

## MCP server hard constraints (inherited from akkuna)

Non-negotiable for code in `SmallChat-MCP/` — hard-won from akkuna:

- **Stdout is reserved for MCP JSON-RPC framing.** Any stdout write
  from Pharo corrupts the channel. `muteTranscriptToStdout` runs on
  server start; never `Transcript show:` from reader-path code. Use
  `SmallChatMCPServer logToFile:` (writes to
  `pharo/smallchat-mcp.log`) or `logToStderr:`.
- **No embedded newlines in MCP messages.** Use `STONJSON toString:`
  (compact). NeoJSON isn't in base Pharo.
- **`Stdio stdin next` returns bytes vs Characters inconsistently** —
  `readLine` normalises via `isInteger`/`asInteger`. Don't simplify.
- **Launch via `open -n -a Pharo.app --args IMAGE`** (macOS
  LaunchServices). Direct `exec` beachballs on first window click.
- **TCP bridge via BSD `nc`** without `-N` (macOS doesn't recognise
  it; BSD default already half-closes on stdin EOF, which is what
  Claude Code expects).
- **`pharo/mcp.port` handshake.** Shell polls; Pharo writes on
  `SmallChatMCPTcpServer>>start`. Stale port files are removed
  before relaunch.
- **`SMALLCHAT_NO_GUI=1` opt-in headless mode** uses
  `eval --no-quit '1'` to keep the VM alive while the MCP reader
  pumps stdin.
- **`Smalltalk vm imageFile parent`**, NOT `imageDirectory` (latter
  doesn't exist in newer VMs).
- **`waitForStdinData` uses a fresh Semaphore per call.** The shared
  one in `AbstractBinaryFileStream` stops signalling on stdin after
  ~3 reads on Pharo 14; fresh-Semaphore pattern is defensive on
  Pharo 13 and required on 14.
- **`UIManager default defer: [ ... ]`** for any Morphic/Spec2 window
  op from tool code. Opening a window from the forked reader can
  deadlock the VM.
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
  on every iterated package; without the shim, `workingCopyDiff` and
  `modifiedPackages` raise DNU. `lib/iceberg-setup.st` installs it
  unconditionally.
- **`IceRepositoryCreator>>addLocalRepository` ignores
  `subdirectory:`.** Correct sequence: `location:; subdirectory:;
  ensureProjectFile; addLocalRepository`, so `IceBasicProject` is
  created with `src/` as its source directory. `addLocalRepository`
  also doesn't register — call `IceRepository registerRepository:`
  afterward.
- **Newly-attached packages look like all-additions.** After
  `basicAddPackage:`, `workingCopyDiff` reports every class and
  method as `IceAddition` because Iceberg's package state is empty.
  Call `workingCopy refreshPackages` after attaching to reconcile
  against HEAD.
- **`commit` only sees in-image changes made during the session.**
  Files added to `src/` via Write (or anything other than in-image
  compilation) are invisible to `workingCopyDiff`. See "How the repo
  maps to the image".
- **Shell `git commit` desyncs the in-image working copy.** Hand-edit
  on disk and `git commit` while the dev image is up →
  `workingCopy referenceCommit` still points at the old HEAD → next
  MCP `commit` raises `IceWorkingCopyDesyncronized` (Iceberg's
  invariant is reference == HEAD). Re-anchor:
  ```smalltalk
  | repo wc |
  repo := IceRepository registry detect: [ :r | r name = 'smallchat' ].
  wc := repo workingCopy.
  wc referenceCommit: repo headCommit.
  wc refreshDirtyPackages
  ```
  Then retry `commit`. **Caveat:** `referenceCommit:` followed by
  `refreshDirtyPackages` clears the in-image diff (in-image classes
  are now considered "matching reference"). To re-surface modified
  methods after a re-anchor, recompile each affected method via
  `evaluate 'ClassName compile: ''…'' classified: ''…'''` so the
  SystemAnnouncer fires and Iceberg re-marks them dirty.
- **A failed `commit` mid-flight can leave half-written Tonel files
  on disk.** If `mcp__smallchat__commit` errors out (or the MCP
  connection drops, or the VM hangs during `updateDiskWorkingCopy:`),
  some `.class.st` files may already have been wiped or rewritten
  empty before the git commit step. The next `just rebuild` then
  fails in `TonelParser` with `bitAnd: was sent to nil` — Tonel
  reading an empty file. **Recovery:** before triggering any
  rebuild after a commit hang, check `git status` for unexpected
  modifications/deletions; revert any 0-byte `.class.st` and any
  spurious deletions with `git checkout HEAD -- <files>`. Only my
  intended in-image changes (which the commit already wrote
  successfully) should remain in the diff.
- **Empty packages are dropped by `wc refreshPackages`.** After
  `basicAddPackage:` for a brand-new package that has no classes
  yet, `refreshPackages` removes it again because nothing in HEAD
  matches. Either compile a class into the package first (so HEAD
  isn't empty after the next commit), or skip `refreshPackages` on
  the freshly-attached set and let the next `commit` reconcile.
