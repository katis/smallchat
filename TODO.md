# TODO

Planning snapshot. See `docs/architecture.md` for the layer map,
`plans/` for per-subsystem design. This file tracks what to do, in
what order, and what's still unknown.

Status conventions: `[ ]` = not started, `[~]` = in progress,
`[x]` = done, `[!]` = blocked. Datestamps use ISO 8601.

---

## Spikes — state at end of planning pass (2026-04-24)

- [x] **Spike 1 - tsgo LSP maturity.** Viable for navigation,
  rename, symbols, diagnostics, hover, completion, signature
  help, call hierarchy. Invocation `npx tsgo --lsp --stdio`.
  `codeAction` / `refactor.*` is the weak spot today; moving
  weekly. Plan fallback to `typescript-language-server` when
  refactor kinds are the gating need. See `plans/01`.
- [x] **Spike 2 - existing Pharo LSP client.** Nothing usable off
  the shelf. `badetitou/Pharo-LanguageServer` is a server;
  `juliendelplanque/JRPC` has no stdio, no `Content-Length`.
  Build a thin `SmallChat-LSP` package (~300-500 LOC). See
  `plans/01`.
- [x] **Spike 3 - Pharo-Tree-Sitter grammars.** Use
  `Evref-BL/Pharo-Tree-Sitter` v1.1.1. TS and Python are
  auto-built; JS and CSS wrappers exist as packages but likely
  need local dylib build. TSX vs TS exposure unverified.
  arm64-darwin dylib validation pending. See `plans/02`.
- [x] **Spike 4 - FamixTypeScript reuse.** Fuhrmanator's model
  is the only live candidate. Recommendation is a minimal new
  FamixNG-X metamodel (~13 entity classes) including CSS
  Modules, cross-referencing fuhrmanator's class names for
  future interop. See `plans/03`.
- [x] **Spike 5 - LSP->Famix feasibility.** Feasibility confirmed
  from LSP spec + spike 1 coverage; real-project prototype
  deferred to the first implementation milestone (see Milestone
  group M2 below). See `plans/03`.
- [x] **Spike 6 - WorkspaceEdit application.** Edge cases
  enumerated (overlapping edits as error, reverse-order apply,
  resource ops ordering, line-ending preservation, UTF-16
  position encoding, snapshot-based rollback). Real prototype
  folded into the implementation milestone. See `plans/04`.
- [x] **Spike 7 - Agent tool surface unification.**
  `SmallChatToolRegistry` uses reflective discovery via
  `SmallChatTool allSubclasses`; native harness uses a hardcoded
  `toolFor:` with one tool. No shared abstraction. Migration
  path: introduce `SmallChatCapability`, migrate tools one by
  one. See `plans/05`.
- [x] **Spike 8 - RBRefactoring exposure.** Pharo 13 has 437 RB/Re
  classes rooted at `ReAbstractTransformation -> ReRefactoring
  -> {RB,Re}*Refactoring`. Execute via `#execute`. Expose via the
  same capability registry as TS refactorings. See `plans/04`.

---

## Pre-implementation spikes (to run before committing code)

These are small, scoped verifications whose answers will change
how we implement. Run each, update the relevant plan's Open
Questions section, commit the update.

- [ ] **S1. OSSubprocess load and tsgo launch.** Add OSSubprocess
  to the dev baseline. Launch tsgo via `npx tsgo --lsp --stdio`,
  write `initialize` bytes, read bytes back. Confirm: stdin EOF
  behaviour, zombie cleanup on image quit, stderr visibility.
  **Updates:** `plans/01` Open Questions.
- [ ] **S2. Pharo-Tree-Sitter binding surface.** Load
  `Evref-BL/Pharo-Tree-Sitter` v1.1.1 into dev image. Verify:
  does the `TreeSitter-Typescript` package expose both
  `tree_sitter_typescript` and `tree_sitter_tsx` symbols, or
  only one? Parse a TSX fixture either way. **Updates:**
  `plans/02` Open Questions.
- [ ] **S3. arm64-darwin dylibs.** Build or acquire
  `libtree-sitter-typescript.dylib`, `libtree-sitter-javascript
  .dylib`, `libtree-sitter-css.dylib` for arm64. Document the
  build recipe in `plans/02`. `file` output pinned.
- [ ] **S4. FamixNG / Moose pin.** Pick a specific Moose release
  that loads cleanly on Pharo 13 and provides FamixNG generator
  traits. Pin in baseline. **Updates:** `plans/03` Open
  Questions.
- [ ] **S5. Epicea-backed Smalltalk rollback.** Can we replay or
  invert an Epicea event log to roll back a `ReRefactoring
  #execute`? If not, snapshot compiled methods and class state
  manually. **Updates:** `plans/04` Open Questions.
- [ ] **S6. Real-project LSP->Famix dry-run.** Pick a small TS
  project (~50 files, React + CSS Modules). Script a one-off
  Famix build end-to-end (imports resolved, CSS bridge). Measure
  time, identify gaps. **Updates:** `plans/03` (feasibility
  confirmed or problems identified).

---

## Implementation order

Dependencies force a sequential backbone, but smaller tracks can
parallelise once each foundation is green. Each milestone is a
meaningful integration point; per-milestone tasks are detailed in
the matching plan.

### M0 - Foundations (no external deps on other milestones)

- [ ] Add `OSSubprocess` to `BaselineOfSmallChat` `dev` group.
- [ ] Add `TreeSitter` (Evref-BL) to `BaselineOfSmallChat` `dev`
  group. `default` / verifier group stays lean.
- [ ] Vendor arm64 dylibs under `lib/tree-sitter/arm64-darwin/`.
  Add a dylib-presence self-check at startup (loud warning on
  missing).
- [ ] FamixNG load into `dev` group (after S4).

### M1 - LSP client

See `plans/01`. Depends on: M0 (OSSubprocess).

- [ ] Stdio transport + `Content-Length` framing.
- [ ] JSON-RPC correlation + notifications.
- [ ] Document sync (`didOpen`/`didChange`/`didClose`).
- [ ] Capability value object.
- [ ] Reader process hardening + logging.
- [ ] Stub transport for tests.

### M2 - Tree-sitter adapter + Famix metamodel

See `plans/02`, `plans/03`. Depends on: M0.

- [ ] `SmallChatTSParser` + TS/TSX/JS/CSS grammar singletons.
- [ ] Range helpers (byte <-> UTF-16 LSP position).
- [ ] Named-child walker helpers.
- [ ] Minimal Famix-X metamodel (13 classes), STON round-trip
  tested.

### M3 - Famix population pipeline

See `plans/03`. Depends on: M1, M2.

- [ ] `documentSymbol`-backed per-file importer.
- [ ] Tree-sitter + LSP-definition imports resolution.
- [ ] CSS-module importer.
- [ ] CSS-module bridge (TS `styles.X` refs).
- [ ] Regeneration API keyed on changed URIs.

### M4 - Capability registry + transport rewires

See `plans/05`. Depends on: nothing blocking, but best done
alongside M1 so new LSP-backed tools can consume it.

- [ ] Core types (`SmallChatCapability`,
  `SmallChatCapabilitySchema`, `SmallChatCapabilityResult`,
  `SmallChatCapabilityCall`, registry).
- [ ] JSON-Schema + OpenAI function-schema emitters.
- [ ] MCP transport adapter wrapping the legacy registry.
- [ ] Migrate existing 16 MCP tools to `SmallChatCapability`,
  one per commit.
- [ ] LM native transport adapter; replace `toolFor:` with
  registry lookup.
- [ ] Retire `SmallChatTool` in favour of `SmallChatCapability`.

### M5 - Refactoring API

See `plans/04`. Depends on: M1, M2, M3, M4.

- [ ] `SmallChatWorkspaceEditApplier` with snapshot/rollback.
- [ ] `SmallChatRefactoringCommand` abstract + value types.
- [ ] First LSP-backed command: `ts.rename-symbol`.
- [ ] First Smalltalk-side command: `smalltalk.rename-method`
  (depends on S5 outcome).
- [ ] First tree-sitter-backed command: `css.rename-class`
  (single file).
- [ ] Cross-language: `css.rename-class` with TS consumers.
- [ ] `ts.extract-function`, `ts.move-to-file` (tsgo codeAction
  with fallback).
- [ ] Diagnostics-delta verification wired.

### M6 - Workspace scoping

See `plans/06`. Depends on: M4, M5.

- [ ] `SmallChatWorkspace` abstract + `SmallChatPharoWorkspace`
  default.
- [ ] `workspace.list` / `workspace.current` capabilities.
- [ ] `SmallChatTsWorkspace` attach/detach.
- [ ] Capability workspace-kind filtering at registry boundary.
- [ ] Workspace-dispatched `vcs.commit`.

---

## Cross-cutting concerns

### UI non-blocking (hard rule)

LSP requests can take seconds (references over a large project,
diagnostics settle-wait after an edit, codeActions that fan out).
The UI process (Morphic) must never wait on one. Enforced at two
layers, neither is optional:

- **Plan 01** — every blocking LSP entry point asserts
  `Processor activeProcess ~~ UIManager default uiProcess` and
  fails loudly. An async `#requestAsync:` surface is provided for
  UI-originated calls; those fork a worker and post results back
  via `UIManager default defer:`. Cancellation via LSP
  `$/cancelRequest` is wired in from day one.
- **Plan 05** — capability `#run:with:` asserts the same at the
  registry boundary. MCP transport is on a fork already; the LM
  native transport must relocate its tool-call dispatch off the
  UI process as part of the capability-registry migration.

- [ ] Unit test: calling `SmallChatLSPClient #request:` from
  `UIManager default uiProcess` raises. Regression guard against
  future accidental wiring.
- [ ] Unit test: closing the LM chat window cancels in-flight
  capability workers and their pending LSP requests.

### Testing

- [ ] Each new package gets a `SmallChat-*-Tests` package. `just
  test` matches `SmallChat.*` so they're picked up automatically.
- [ ] LSP-dependent tests must not require a live tsgo process.
  Use the stub transport (M1).
- [ ] Tree-sitter-dependent tests need real dylibs; gate them
  with an `isPresent` check so headless CI without dylibs can
  skip.
- [ ] Famix importer tests use fixture projects under `lib/
  fixtures/ts-small/`. Small, deterministic.
- [ ] Refactoring tests use the applier against fixture files,
  verify byte-for-byte output; LSP interactions stubbed.
- [ ] Self-hosting refactoring tests operate on a scratch
  package, not on the live SmallChat-* packages, to avoid
  corrupting the dev image.
- [ ] Keep `just test` and `just lint` green on each
  micro-commit. No exceptions.

### CI

- [ ] No external CI runner beyond the existing `just test` /
  `just lint` locally. If that changes, add a note here. The
  verifier image already enforces a fresh-rebuild gate.
- [ ] When OSSubprocess + dylibs land in `dev` group, the
  `default` (verifier) group should stay lean so `just test`
  doesn't regress in startup time. See `plans/01`.

### Docs

- [ ] Update `CLAUDE.md` when M4 lands — capability naming
  conventions, how to add a new capability, migration notes for
  the legacy `SmallChatTool` pattern.
- [ ] Per-plan Open Questions: when a spike answers one, delete
  the question from the plan (don't leave stale).
- [ ] Add `docs/refactoring-cookbook.md` once a handful of
  commands are shipped (M5+). Deferred.

### Tooling hygiene

- [ ] Any in-image state we care about must round-trip through
  Tonel before commit. The existing micro-commit discipline
  holds; new packages get attached to Iceberg via
  `basicAddPackage:` + `refreshPackages`.
- [ ] When adding a new package that depends on another, update
  `BaselineOfSmallChat.class.st` `spec requires:` **in the same
  change**. Missed deps surface as `NewUndeclaredWarning` on
  verifier rebuild. See CLAUDE.md.

---

## Deferred / parking lot

Ideas mentioned during planning that are explicitly not on the
roadmap. Revisit when someone asks.

- Streaming capability results (progress notifications).
- Workspace persistence across image restarts.
- Multi-TS-workspace orchestration.
- Remote/managed tsgo instances (non-subprocess).
- `ts.run-tests` (vitest / jest wrapper capability).
- Famix model persistence / on-disk cache.
- JSX component detection beyond the trivial case (forwardRef,
  memo, styled(...)).
- Dynamic import / `require()` resolution beyond best-effort.
- Re-export modelling in Famix.
- Cross-language Smalltalk<->TS refactorings.
- Capability versioning.
- Remote capability marketplace.
