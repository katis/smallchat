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

- [x] **S1. OSSubprocess load and tsgo launch.** (2026-04-24)
  OSSubprocess pinned to `pharo-contributions/OSSubprocess@01754067`,
  added to `dev` group. Launch the tsgo binary *directly* — the
  `npx`/node-exec wrapper does not forward stdin. Package is
  `@typescript/native-preview`, binary is `tsgo`. LSP handshake
  round-trips; tsgo emits a `window/logMessage` notification before
  the `initialize` response (client must dispatch notifications
  first). tsgo ignores LSP `shutdown`+`exit` — closing stdin is the
  reliable clean-exit path. Auto-reaping works via the background
  `OSSubprocess child watcher` Process; live children still need an
  explicit teardown on image save/quit. Full findings in `plans/01`
  *Spike S1 findings*.
- [x] **S2. Pharo-Tree-Sitter binding surface.** (2026-04-24)
  Evref-BL v.1.1.1 pinned to `e621baf6c...` in baseline `dev`
  group, loaded with `default typescript css` groups. Binding
  ships `TSTypescriptLibrary` with only `tree_sitter_typescript`
  — no `tsx`. TS grammar silently mis-parses TSX (three ERROR
  nodes on `lib/fixtures/ts-small/Button.tsx`); TSX grammar
  parses the same fixture cleanly once we add the ~5-method
  `TSTsxLibrary` delta (recipe in `plans/02`). Auto-build works
  on macOS arm64; tsx dylib is a by-product of the same `make`
  but the binding doesn't copy it to `<vm>/Plugins/` — manual
  copy for S2; S3 vendors both. Full findings in `plans/02`
  *Spike S2 findings*.
- [x] **S3. arm64-darwin dylibs.** (2026-04-24) Vendored five
  dylibs (`libtree-sitter`, `-typescript`, `-tsx`, `-css`,
  `-javascript`) under `lib/tree-sitter/arm64-darwin/`; `install
  .sh` stages them into the VM's Plugins dir. Build recipe and
  pinned SHAs live in `lib/tree-sitter/arm64-darwin/README.md`
  and `plans/02` *Spike S3 findings*; rebuild with
  `just rebuild-dylibs`. `file *.dylib` pinned to arm64 in both
  docs. Includes `SmallChatTreeSitterHealth` class-side
  presence-check wired into `lib/load-packages.st` (dev branch).
- [x] **S4. FamixNG / Moose pin.** (2026-04-24) Pinned
  `moosetechnology/Famix` v1.2.0 (`e841ebfd...`) in baseline
  `dev` group with `loads: 'Basic'` — the narrowest group that
  carries `Famix-MetamodelGeneration` without the visualisation
  stack. Rebuild on Pharo 13 is clean in ~48 s; generator DSL
  (`FamixMetamodelGenerator` subclass + `builder newClassNamed:`
  + `--|>` trait wiring) works end-to-end. Pulls Fame, Deep-
  Traverser, CollectionExtensions, SingularizePluralize and
  their transitives. Full findings in `plans/03` *Spike S4
  findings*.
- [x] **S5. Epicea-backed Smalltalk rollback.** (2026-04-24)
  Epicea is enabled in the dev image with a shared `EpMonitor
  current log` across `evaluate` calls. `ReRefactoring #execute`
  emits only raw `EpCodeChange` events (no `EpRefactoring`
  wrapper); every event has an invertible counterpart via
  `asRevertedCodeChange applyCodeChange`. Boundary-based inversion
  (capture `log entriesCount` pre-apply, walk head-first on
  rollback) scales to the refactoring's real blast radius without
  pre-enumerating scope — validated with an 83-event method+class
  rename that reverted with zero errors. Manual compiled-method
  snapshot not needed for M5; kept as a contingency if a
  SystemAnnouncer-bypassing change path ever appears. Full
  findings in `plans/04` *Spike S5 findings*.
- [x] **S6. Real-project LSP->Famix dry-run.** (2026-04-24)
  Scripted end-to-end against `/Users/katis/code/juba` (SolidJS
  1.9 + TanStack Start, 141 working `.ts` / `.tsx` files) plus a
  3-file synthetic `lib/fixtures/ts-css-small/` for the CSS-
  Modules bridge. Wall time ~7.8 s single-threaded:
  documentSymbol sweep 1.8 s (p50 13 ms / p95 22 ms / max 40 ms),
  464 `textDocument/definition` calls 5.9 s (p50 12 ms / p95 16
  ms). Zero unresolved imports; `~/*` tsconfig-paths aliases
  resolved cleanly (248/248 src-local imports are aliased — juba
  uses zero relative cross-file imports). 91 JSX components
  detected across 76 TSX files; Cloudflare `cloudflare:workers`
  virtual module resolves to a project-root `.d.ts`. CSS bridge
  on the fixture produced the expected 3 classes + 2 resolved +
  1 unresolved references. **Adjustments that fall out:**
  documentSymbol `Property` (1415 in juba) needs a home —
  recommend 14-class inventory with a new `Field` entity;
  `Variable` (2061) should not produce Famix entities by itself,
  route via tree-sitter to `JSXComponent` only. Widen JSX
  heuristic to include TanStack `createFileRoute(...)({ component
  : () => <JSX/> })` (3 files missed). Tsgo sends
  `client/registerCapability` as a request (id + method) not a
  notification — plan 01's framer must distinguish or the reader
  deadlocks. tsgo emits ~3 `window/logMessage` notifications per
  op; the transport should drop them pre-parse. TSX grammar
  parses `.ts` cleanly (2605 nodes, zero ERROR on an 18 KB
  file); drop separate TS vs TSX parser singletons from plan 02.
  Full findings in `plans/03` *Spike S6 findings*.

---

## Implementation order

Dependencies force a sequential backbone, but smaller tracks can
parallelise once each foundation is green. Each milestone is a
meaningful integration point; per-milestone tasks are detailed in
the matching plan.

### M0 - Foundations (no external deps on other milestones)

- [x] Add `OSSubprocess` to `BaselineOfSmallChat` `dev` group.
  (2026-04-24, S1; exercised end-to-end in S6)
- [x] Add `TreeSitter` (Evref-BL) to `BaselineOfSmallChat` `dev`
  group. `default` / verifier group stays lean. (2026-04-24, S2)
- [x] Vendor arm64 dylibs under `lib/tree-sitter/arm64-darwin/`.
  Add a dylib-presence self-check at startup (loud warning on
  missing). (2026-04-24, S3)
- [x] FamixNG load into `dev` group. (2026-04-24, S4)

### M1 - LSP client

See `plans/01`. Depends on: M0 (OSSubprocess).

- [x] Stdio transport + `Content-Length` framing. (2026-04-24)
- [x] JSON-RPC correlation + notifications. (2026-04-24)
- [x] Document sync (`didOpen`/`didChange`/`didClose`). (2026-04-24)
- [x] Capability value object. (2026-04-24)
- [x] Reader process hardening + logging. (2026-04-24)
- [x] Stub transport for tests. (2026-04-24)

### M2 - Tree-sitter adapter + Famix metamodel

See `plans/02`, `plans/03`. Depends on: M0.

- [x] `SmallChatTSParser` + TSX / CSS grammar singletons.
  (2026-04-25; JS deferred per S6 -- TSX grammar parses .ts cleanly,
  so the JS wrapper waits until something actually needs it.)
- [x] Range helpers (byte <-> UTF-16 LSP position). (2026-04-25;
  ASCII / BMP non-ASCII / astral covered, LSP-shaped position-range
  emit and inverse round-trip both implemented.)
- [x] Named-child walker helpers. (2026-04-25;
  topLevelDeclarations, importStatements, jsxAttributeValues,
  memberExpressionsFor:objectName:inSource:, classSelectors --
  exercise lib/fixtures/{ts-small,ts-css-small}/.)
- [x] Minimal Famix-X metamodel (14 classes), STON round-trip
  tested. (2026-04-25; grew to 14 per S6 -- added `Field` for
  documentSymbol Property kinds. Project / Module / Class /
  Interface / Function / Method / Parameter / Field / TypeAlias /
  Import / JSXComponent / CSSModuleFile / CSSClass /
  CSSClassReference, all rooted on SmallChatFamixEntity with
  `name` and `sourceAnchor` accessors.)

### M3 - Famix population pipeline

See `plans/03`. Depends on: M1, M2.

- [x] `documentSymbol`-backed per-file importer. (2026-04-25;
  importTsFileUri:text: emits Module + Project + symbol entities
  via documentSymbol, then walks tree-sitter for imports +
  JSXComponents (function decl, const-arrow, TanStack pair-arrow)
  and links CSS references.)
- [x] Tree-sitter + LSP-definition imports resolution. (2026-04-25;
  each Import carries resolvedUri + classification, bucketed as
  #srcLocal / #nodeModules / #virtualModule / #unresolved.)
- [x] CSS-module importer. (2026-04-25; importCssFileUri:text:
  emits CSSModuleFile + deduped CSSClass per selector.)
- [x] CSS-module bridge (TS `styles.X` refs). (2026-04-25;
  linkCssReferencesInTsUri:text: emits CSSClassReference per
  member-expression, resolved or unresolved-flagged.)
- [x] Regeneration API keyed on changed URIs. (2026-04-25;
  reimportUris: drops + re-imports per URI; relinkCssReferencesForUris:
  refreshes references after CSS-only changes.)

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

- [x] Unit test: calling `SmallChatLSPClient #request:` from
  `UIManager default uiProcess` raises. Regression guard against
  future accidental wiring. (2026-04-24)
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
