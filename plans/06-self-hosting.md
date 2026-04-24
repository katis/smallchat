# Plan 06 - Self-hosting and workspace scoping

## Purpose and scope

smallchat edits two kinds of code:

1. **Itself** — the Pharo Smalltalk code in `/Users/katis/code/
   smallchat/src/`, compiled into the live dev image, managed by
   Iceberg, flushed to Tonel on commit.
2. **External TypeScript / JavaScript / CSS Modules projects**
   — on-disk working copies under arbitrary paths, edited via
   LSP + tree-sitter + the refactoring API, committed via normal
   git.

Both domains share the capability registry (plan 05), but the
underlying refactoring and code-access mechanisms are different.
This plan is about clean separation of the two and about
workspace scoping: how an agent addresses "the current project"
when it could be either.

## Key design decisions

**Two project kinds, one abstraction.** `SmallChatWorkspace`
(abstract) with two concretions:

- `SmallChatPharoWorkspace` — wraps the live Pharo image. Root
  package names (`SmallChat-*`), the Iceberg repo, the compiled
  methods in the image. Edits go through the Pharo compiler and
  Iceberg. Code-access uses Smalltalk reflection and `RBModel`
  / `SystemNavigation`.
- `SmallChatTsWorkspace` — wraps an on-disk folder. A tsgo LSP
  client is attached, tree-sitter parses files on demand, the
  Famix model describes the structure. Edits go through the LSP
  and the WorkspaceEdit applier. Commits go through a shell
  `git` (since Iceberg doesn't manage TS projects).

A capability receives the workspace it should act on. Defaults:
if the caller doesn't specify, use the current session's
workspace.

**The dev image always has the Pharo workspace mounted.**
Self-hosting is the primary use case during smallchat's own
development. The capability registry's first workspace entry is
always `SmallChatPharoWorkspace default`.

**Ts workspaces are opt-in and named.** Agents call a
`workspace.attach-ts` capability with a folder path; the session
holds an `OrderedCollection` of attached workspaces. Attach is
idempotent by path. Detach cleans up the LSP subprocess.

**Capability applicability.** Each capability declares which
workspace kinds it supports via a class-side method
`#supportedWorkspaces` -> one of `#(#pharo)`, `#(#ts)`,
`#(#pharo #ts)`. Agents that send a TS-only capability against a
Pharo workspace get a structured error, not a crash. The
registry does the check at the transport boundary.

**Refactoring vocabulary divergence.** TS and Pharo refactorings
share the same command-pattern shape (plan 04) but not the same
names. Rename is rename in both, but extract differs
(extract-function in TS vs extract-method in Smalltalk). Keep
them distinct in the capability registry; agents already speak
to a specific language in each call. Plan 05's naming convention
(`ts.*` vs `smalltalk.*`) covers this.

**Commits.** `vcs.commit` behaves differently per workspace:

- Pharo workspace -> existing `SmallChatCommitTool` behaviour
  (refresh Tonel, Iceberg commit).
- TS workspace -> shell git add/commit inside the workspace
  root, with path filters. No Iceberg involved.

The capability dispatches on workspace kind; callers see one
capability.

**Workspace-scoped LSP lifecycle.** One LSP client per attached
TS workspace, launched on attach, kept warm until detach or
session end. The dev image may run 0 or 1 LSP subprocesses under
normal solo-agent use; more is possible but not a priority
scenario.

**Self-hosting cycle safety.** When the agent refactors smallchat
itself, it's editing the same image it runs in — a compile error
or a broken `ReRenameMethod` can halt the MCP reader. This isn't
new (today's `evaluate` can do the same), but three safeguards
reduce the blast radius:

- Every capability call goes through the same
  `on: Exception do: ...` wrapper that
  `SmallChatToolRegistry.run:with:` provides today. Capabilities
  can crash without hosing the reader.
- `SmallChatRefactoringCommand` snapshot/rollback extends to
  Smalltalk refactorings — Epicea log or compiled-method snapshot
  — so a botched Smalltalk refactoring can roll back in-image.
- The existing CLAUDE.md red-green-refactor-microcommit discipline
  applies to any self-hosted refactoring. The agent is expected
  to commit between meaningful Greens; if it doesn't and the
  image dies, git is the backstop.

**TS workspaces do not get the `evaluate` capability.** Arbitrary
Smalltalk evaluation only makes sense in a Pharo workspace.
Other capabilities that are Pharo-image-specific (`debug.*`,
`vcs.status` for Iceberg) stay `#(#pharo)`-only. `run_tests` is
currently SUnit-only; a TS workspace would need a separate
capability (e.g. `ts.run-tests` wrapping `npm test` or `vitest`),
deferred.

## Dependencies

- Plan 01 (LSP client) — each TS workspace owns one.
- Plan 03 (Famix model) — one model per TS workspace.
- Plan 04 (refactoring API) — commands are workspace-aware.
- Plan 05 (capability registry) — capabilities declare
  supported workspace kinds.

## Open questions

- Initial workspace discovery. If an agent is launched without a
  TS workspace attached, and asks a TS capability, what happens?
  Structured error telling the agent to attach first is the safe
  answer; an auto-attach based on `cwd` inference is tempting but
  risky (wrong folder, nested repos).
- Multiple attached TS workspaces. Supported in principle, but we
  have zero use cases today. Start with one; grow when needed.
- LSP subprocess crash recovery. If tsgo dies mid-refactor, the
  applier has already snapshotted files, so rollback is fine; the
  agent sees an error. Restart tsgo on next use? Yes, but only on
  the next capability call that needs it (not a background
  watchdog).
- Relative path handling inside a workspace. The Famix model
  uses URIs (absolute `file://` paths) from LSP. Capabilities that
  expose paths to agents should probably relative-ise them to the
  workspace root. Decide when the first capability actually
  returns paths to agents.
- Workspace persistence. Reattaching on image restart? Store the
  list of last-session workspaces in `SmallChatConfig`? Not now.
- Cross-workspace refactorings. Don't. If an agent thinks it
  needs one, it's probably modelling wrong; two refactorings is
  the right answer.
- What about working on smallchat *via* a TS workspace (editing
  `CLAUDE.md`, `justfile`, `lib/*.st`)? These files are on-disk
  in the same folder as the dev image. They are not TS, so the
  TS workspace abstraction doesn't help. Use the existing
  `commit_files` tool; non-goal for this plan.

## Milestones

1. `SmallChatWorkspace` abstract + `SmallChatPharoWorkspace`.
   Default instance. Capability registry acquires a current-
   workspace notion.
2. `workspace.list`, `workspace.current` capabilities. Read-only
   introspection.
3. `SmallChatTsWorkspace` + attach/detach capabilities. LSP
   client lifecycle tied to workspace lifecycle.
4. Capability workspace-kind filtering at the registry boundary.
5. Workspace-dispatched `vcs.commit`.
6. Self-hosting rollback for Smalltalk refactorings (Epicea or
   snapshot). Integration with plan 04's applier.

## Non-goals

- No multi-TS-workspace orchestration in this phase.
- No auto-detection of workspace kind from a folder path.
- No workspace persistence across image restarts.
- No Smalltalk-into-TS or TS-into-Smalltalk interop (e.g.
  "rename this Smalltalk method and also rename the TS binding
  that calls it"). Out of scope; no use case yet.
- No managed-remote tsgo instances. Subprocess-local only.
