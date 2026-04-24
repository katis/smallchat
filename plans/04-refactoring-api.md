# Plan 04 - Refactoring API

## Purpose and scope

The command-object layer that agents drive. One class per
refactoring, each a Smalltalk value object that knows its inputs,
can describe itself, preview its change, apply it, verify
diagnostics delta, and roll back on failure or demand. This is
the *only* layer agents touch for code modification; agents never
see LSP JSON or tree-sitter nodes directly.

Package name: `SmallChat-Refactoring`.

## Spike findings

**WorkspaceEdit shape (LSP 3.17/3.18).** Three top-level forms:

- `changes`: `{ [uri]: TextEdit[] }` — legacy, version-less.
- `documentChanges`: array of `TextDocumentEdit` (positions are
  versioned) and `CreateFile`/`RenameFile`/`DeleteFile`
  resource operations, ordered semantically.
- `changeAnnotations`: optional provenance / user-facing labels.

tsgo (per spike 1) uses `documentChanges` when it supports
resource operations, plain `changes` otherwise. The applier must
handle both.

**Edit-application edge cases** (from spec + accumulated LSP
client experience):

- Overlapping edits within a single document are **undefined**
  in the spec. Treat as error; do not try to merge.
- Edits within one document are applied in reverse order by range
  start to keep offsets stable.
- `CreateFile` must precede edits to that file; `DeleteFile`
  must follow. For same-operation moves, `RenameFile` comes
  between old-file edits and new-file edits.
- Line-ending normalisation is out of LSP's scope. The server
  emits edits in whatever line-ending the client reported on
  `didOpen`; we must read files in binary, not apply any
  transcoding, and write back bytes unchanged outside the edited
  ranges.
- Text encoding: LSP positions are UTF-16 code units by default
  (Position Encoding negotiated in `initialize`). tree-sitter is
  bytes. The LSP client converts; the applier works in bytes.
- Atomicity and rollback: capture pre-edit file content (bytes)
  for every touched URI before any write. On any failure, restore
  all touched files from the snapshot. This is plain Pharo
  `FileSystem` I/O; no fancy transaction layer.

**In-image state.** `FileSystem` is loaded (confirmed). `LibC`
is loaded. `RBParser` and `RBProgramNode` exist — useful for
Smalltalk-side refactorings. 437 `RB*` classes plus the newer
`Re*Refactoring` family under `ReAbstractTransformation ->
ReRefactoring`. `RBExtractMethodRefactoring superclass superclass
= ReRefactoring` — the two hierarchies are merged.

**Pharo's refactoring family** exposes `#execute` and `#preview`
style selectors. The class names map cleanly to command names
(e.g. `ReRenameMethodRefactoring` -> agent-visible
`rename-smalltalk-method`).

## Key design decisions

**One command class per refactoring kind.** Each command:

- Holds all its inputs as named instance variables (not a
  parameter bag).
- `#preview` -> `SmallChatRefactoringPreview` with per-file
  before/after hunks, summary of resource operations, a free-text
  description, and a `verifies` field (diagnostics delta, if
  cheap).
- `#apply` -> `SmallChatRefactoringOutcome` with `isSuccess`,
  a list of touched files, and a rollback token.
- `#rollback:` takes a token and restores. Tokens are opaque but
  durable for the lifetime of a session; expire with the session.
- `#verify` -> `SmallChatRefactoringVerification`: diagnostics
  delta (count by severity + per-file list), optionally test
  results delta if the caller opts in.

**Transaction semantics: preview -> apply -> verify -> commit or
rollback.** The apply step writes to disk and updates LSP
document state (didChange). The verify step re-fetches
diagnostics from LSP and reports the delta. The caller (agent)
decides: call `#commit` to release the rollback token, or
`#rollback:` to undo. If neither happens within the session
timeout, rollback is triggered automatically on session end.

**Commands are transport-agnostic.** The capability registry
(plan 05) exposes each command class as a capability. The
capability's `run:` unpacks the JSON argument into the command's
named instance variables, runs the transaction, returns a
serialisable result. Agents never see Smalltalk objects, but
inside the image, commands are first-class.

**Three refactoring kinds, unified vocabulary:**

1. **LSP-backed** (TS/JS, single language). Command composes an
   LSP request (`rename`, `codeAction`), receives a
   `WorkspaceEdit`, applies via the applier.
2. **Tree-sitter-backed** (CSS, when LSP is absent or
   insufficient). Command computes edits via tree-sitter
   node walks, assembles a `WorkspaceEdit`-equivalent, applies
   via the same applier.
3. **Pharo-native** (Smalltalk refactorings). Command wraps a
   `RBRefactoring` / `ReRefactoring` subclass; apply runs the
   refactoring's `#execute`; rollback inverts Epicea events since
   a boundary captured pre-apply (see Spike S5 findings below).

**Cross-language refactorings (the CSS-module bridge).** A
`RenameCSSClass` command takes a `SmallChatFamixCSSClass` and
a new name; it builds:

- Tree-sitter edits for the `.module.css` file (replace
  `class_selector` occurrences).
- Tree-sitter edits for each TS/JS file with a
  `SmallChatFamixCSSClassReference` to that class (replace
  `styles.oldName` with `styles.newName`).

These are combined into a single `WorkspaceEdit` and applied
atomically. The applier doesn't care that two languages are
involved.

**Atomic applier.** One `SmallChatWorkspaceEditApplier` class,
used by every command:

- Validates no overlapping edits per URI.
- Snapshots pre-edit content for every touched URI.
- Applies in order: resource creates, text edits (reverse sorted
  per file), resource renames, resource deletes.
- On any failure, rollback from snapshots and return failure.
- On success, return a `SmallChatApplyResult` carrying a
  rollback token (the snapshots) and a file manifest.
- Update LSP `didChange` for every TS/JS/CSS file touched.

**Refactoring registry is shared with the capability registry.**
Plan 05. Commands are discovered via `SmallChatRefactoring
allSubclasses` reflectively, same pattern as the existing
`SmallChatTool` registry.

## Dependencies

- Plan 01 (LSP client).
- Plan 02 (tree-sitter).
- Plan 03 (Famix model) — commands take Famix entities as inputs.
- Plan 05 (capability registry) — exposes commands to agents.
- Pharo `RBRefactoring` / `ReRefactoring` families for
  Smalltalk-side commands.

## Open questions

- Do we expose fine-grained command primitives (rename symbol,
  extract function, move to file) or higher-level task commands
  (generate React component, split file)? Start low; add
  compositions only when agents ask.
- Diagnostics delta calculation. LSP push-diagnostics arrive
  asynchronously; we need to wait-for-diagnostics-to-settle with
  a reasonable timeout (1-2 seconds) after apply. tsgo's push
  cadence needs to be measured.
- Preview fidelity. "Show me what this refactoring would do"
  needs per-file unified-diff output — build it off the
  snapshot + planned edits. Straightforward, but adds latency.
  Make preview optional.
- Multi-root workspaces. A single refactoring should probably not
  cross workspace boundaries; plan 06 defines workspace scoping.
- Test-before-verify. An agent might want `#apply` to run the
  test suite before accepting. That's composition at the agent
  layer, not a command-level concern.
- What happens when apply lands but diagnostics get worse? Do we
  auto-rollback, or return the delta and let the agent decide?
  Lean toward the latter; the agent should see and choose.

## Milestones

1. `SmallChatWorkspaceEditApplier` with snapshot/rollback, tested
   against fixture files (including create/rename/delete).
2. `SmallChatRefactoringCommand` abstract class + preview /
   outcome / verification value types. Registry pattern mirroring
   `SmallChatTool`.
3. First LSP-backed command: `RenameSymbol` (TS/JS). End-to-end:
   resolve Famix entity to position, LSP rename, apply, verify.
4. First Smalltalk-side command: `ReRenameMethod` wrapped.
   Rollback via Epicea event inversion (boundary captured before
   `#execute`, inverses applied head-first on failure).
5. First tree-sitter-backed command: `RenameCSSClass`
   (single-file, CSS only).
6. First cross-language command: `RenameCSSClass` with TS/JS
   consumer updates.
7. `ExtractFunction`, `MoveToFile` (TS/JS via LSP codeAction,
   fallback to tree-sitter composition if tsgo doesn't yet
   support the codeAction kind — see plan 01 fallback section).
8. Diagnostics-delta verification wired through for all commands.

## Non-goals

- No novel refactorings invented up front. Start with what LSP
  and `ReRefactoring` give us.
- No IDE-style refactoring preview UI. Previews return structured
  data; agents consume it.
- No auto-approve on verify. The agent decides.
- No cross-workspace refactorings.
- No commit-on-apply. Commits are a separate capability (the
  existing MCP `commit` tool, extended).

## Spike S5 findings (2026-04-24)

**Recommendation.** Use Epicea event inversion as the rollback
primitive for Smalltalk-native refactorings. Manual compiled-method
snapshot is not required; keep it as a contingency for change paths
that bypass `SystemAnnouncer` (none identified in-scope for M5).

**Surface confirmed present.** Pharo 13's dev image loads 109 `Ep*`
classes. `EpMonitor current isEnabled -> true`; `log` is a singleton
`EpLog` shared across `evaluate` calls (log count is monotonic within
the session and entries from earlier calls remain readable from later
calls). Key primitives:

- `EpCodeChange` abstract (subclasses include `EpMethodAddition`,
  `EpMethodModification`, `EpMethodRemoval`, `EpProtocolAddition`,
  `EpProtocolRemoval`, `EpClassAddition`, `EpClassModification`,
  `EpClassRemoval`, `EpBehaviorNameChange`,
  `EpBehaviorCommentChange`, `EpBehaviorRepackagedChange`,
  `EpPackageAddition`, `EpPackageRemoval`, `EpPackageRename`,
  `EpPackageTagAddition`, `EpPackageTagRemoval`, `EpPackageTagRename`,
  `EpTraitAddition`, `EpTraitModification`, `EpTraitRemoval`).
- `EpCodeChange>>asRevertedCodeChange` (accept `EpInverseVisitor`
  new) returns a new code-change whose `#applyCodeChange` undoes
  the original.
- `EpCodeChange>>applyCodeChange` (accept `EpApplyVisitor` new)
  applies a change via the compiler and package organiser.
- Canonical recipe is in `EpLogBrowserOperationFactory>>
  revertCodeChanges`: `entries reverseDo: [ :each | each content
  asRevertedCodeChange applyCodeChange ]`. The factory's
  `logBrowserModel` / `newRevertEvent` wrappers are optional — we
  can skip them for headless use.

**`EpRefactoring` events are orthogonal, not required for rollback.**
The `EpRefactoring` hierarchy (`EpRenameMethodRefactoring`,
`EpRenameClassRefactoring`, `EpCompositeRefactoring`, ...) is a
*higher-level* marker distinct from `EpCodeChange`. Experimentally,
`ReRenameMethodRefactoring #execute` and `ReRenameClassRefactoring
#execute` emit **only raw `EpCodeChange` events** — no refactoring
wrapper. That's exactly what we want: the agent-visible refactoring
executes, raw code changes are logged, and inversion works on the
raw events. (The `EpRefactoring` wrappers are emitted elsewhere —
from Pharo's refactoring UI when `RefactoringManager`-style
transactions are used — and their `asRBRefactoring` produces a
replayable RB command, not an inverse. Not relevant here.)

**Method rename** (`ReRenameMethodRefactoring` on a unary selector)
emitted `EpMethodAddition(Cls>>newSel)` + `EpMethodRemoval(Cls>>
oldSel)`. Reverting both via `asRevertedCodeChange applyCodeChange`
restored the selector set exactly.

**Class rename** (`ReRenameClassRefactoring rename: #Old to: #New`)
emitted a single `EpBehaviorNameChange(oldName: #Old newName: #New
behavior: <cls>)`. Inverting swaps `oldName`/`newName` and applies
via `Behavior>>rename:`; `Smalltalk globals at: #Old` returned the
class afterwards.

**Scope-aware inversion.** A real-world rename can have large blast
radius: renaming `#alpha` on a scratch class cascaded through the
image and emitted 82 events (`Color>>alpha`, `AlphaBlendingCanvas>>
alpha`, a `Form>>dimmed:` modification that referenced `alpha`, etc.)
plus a subsequent class rename yielded 83 total events. Inverting
all 83 in head-first order returned zero errors and restored every
touched method. **The rollback primitive scales to whatever the
refactoring actually did, without pre-enumerating the scope.**

**Failure-mid-refactor is well-behaved.** When
`ReRenameMethodRefactoring` fails during `generateChanges` (e.g. the
early experiment with `permutation: nil` raised
`MessageNotUnderstood` inside `modifyImplementorParseTree:in:`), no
system mutations had occurred yet, so the log saw zero new
entries. `#execute` splits cleanly between `generateChanges`
(in-memory RB change objects, may throw before touching the system)
and `performChanges` (applies changes and emits `EpCodeChange`s).
If `performChanges` fails mid-way — not reproduced in this spike but
structurally possible — partial events land in the log; the
boundary-based inversion still undoes whatever was applied.

**Headless viability.** The Pharo-standard revert path
(`EpLogBrowserOperationFactory`) carries a `logBrowserModel`
(`EpLogBrowserPresenter`, a Spec2 presenter) for UI integration, but
its `handleErrorDuring:` currently just evaluates the block (the
`on: Error do:` is commented out) and `trigger:with:` only adds an
`EpUndo` audit marker. For the refactoring command we use the
primitives directly:

```
boundary := EpMonitor current log entriesCount.
[ refactoring execute ] on: Error do: [ :err |
    "rollback" self revertSinceBoundary: boundary. err pass ].
"...commit-or-rollback decision point..."

revertSinceBoundary: aCount
    | entries |
    entries := OrderedCollection new.
    EpMonitor current log priorEntriesFromHeadDo: [ :e |
        entries size < (EpMonitor current log entriesCount - aCount)
            ifTrue: [ entries add: e ] ].
    entries do: [ :entry |
        entry content asRevertedCodeChange applyCodeChange ]
```

Notes for M5 implementation: (a) wrap with a per-entry `on: Error do:`
collector so one broken inverse doesn't abort the rest of the
rollback — the agent decides what to do with the residual; (b)
capture the boundary via `log entriesCount` (the canonical stable
reference) — don't hold the `OmReference` directly across
intermediate log writes; (c) filter entries to `EpCodeChange`
kind before inverting, to skip any `EpRefactoring` /
`EpExpressionEvaluation` / session markers that may end up
interleaved; (d) the rollback itself emits inverse `EpCodeChange`s
(so the log remains a faithful trace) — callers asking "how far did
we rewind?" should consult the boundary, not the current log head.

**Manual snapshot fallback (not required, documented for
completeness).** If a future refactoring path proves to bypass
`SystemAnnouncer` (e.g. direct `CompiledMethod` hacks, or a macro
that touches reflective state without going through the compiler),
the manual fallback is: before `#execute`, walk the target class
closure and capture `{ className, definitionString,
classComment, packageName, instanceSide: { sel -> { source,
protocol } }, classSide: { sel -> { source, protocol } } }`;
restore by redefining each class and recompiling each method,
plus removing any selectors not in the snapshot. Not implemented
in the spike because Epicea covers every `ReRefactoring`
path observed.

**Log-size hygiene note.** `EpMonitor current log` is monotonic and
image-wide. A long-running dev image accumulates events (our
scratch run alone landed 192). No impact on correctness; for
inversion performance, bound the scan via `priorEntriesFromHeadDo:`
with a counter (as in the snippet above) so we only read back as
far as our boundary.
