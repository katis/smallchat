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
   refactoring's `#execute`; rollback uses Epicea or an in-image
   snapshot (needs spike, see open questions).

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

- Rollback for Smalltalk refactorings: Epicea is the obvious
  path; does Epicea's event log survive across `evaluate` calls
  reliably? If not, snapshot the compiled methods manually.
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
   Rollback via Epicea or snapshot.
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
