# Plan 05 - Agent tool surface

## Purpose and scope

One Smalltalk capability registry that both the MCP server and the
native in-image harness consume. A capability is a transport-free
description of something an agent can do: name, description,
input schema, Smalltalk handler. Transports adapt capabilities to
their wire format (MCP `tools/call` payload, OpenAI-compatible
function-call JSON).

Goal: add a capability once, both agent transports see it.
Refactoring commands, LSP queries, Famix queries, existing tools
(evaluate, run_tests, lint, status, commit, debug family) all
flow through one registry.

Package name: `SmallChat-Capability` (new). The existing
`SmallChat-MCP` and `SmallChat-LM` packages become transport
adapters on top.

## Spike findings (current state of the two surfaces)

**MCP side (SmallChat-MCP):**
- `SmallChatToolRegistry` discovers tools reflectively via
  `SmallChatTool allSubclasses reject: [:c | c isAbstract]`.
  No explicit registration; compile a new subclass and it
  appears.
- `SmallChatTool` subclasses implement four class methods:
  `toolName`, `description`, `inputSchema` (Pharo Dictionary
  that serialises to JSON Schema), and `run: aDictionary`.
- Dispatch path: `SmallChatMCPServer.handleLine:` ->
  `SmallChatMCPProtocol.handleMessage:` ->
  `SmallChatToolRegistry.default run:with:` -> tool subclass.
- 16 tools registered today. Cross-cutting behaviours at the
  registry: Notification suppression (resume), uncaught-
  exception capture into error reply, stray-debugger-window
  warning prefix.
- Tool results are either plain strings or
  `SmallChatToolResult` (text / image / debugSession variants).

**Native harness (SmallChat-LM):**
- `SmallChatLMSession` drives the chat loop. Tool dispatch via
  `toolFor:` (line 158-163) — **hardcoded** to route `'evaluate'`
  to `SmallChatLMEvaluateTool` and return nil otherwise.
- `SmallChatLMEvaluateTool` is a standalone class, not a
  `SmallChatTool` subclass. It parses OpenAI-shaped JSON args and
  compiles/evaluates via OpalCompiler. No exception capture.
- Tool schemas are emitted in OpenAI function-call shape (class-
  side `toolSchema` on `SmallChatLMEvaluateTool`).
- Streaming loop accumulates tool-call deltas from the model's
  response (line 26-45 in `SmallChatLMChatClient`).
- No shared abstraction with the MCP side. The two registries are
  structurally incompatible today.

**Shared infrastructure (thin):**
- `SmallChatConfig` — LM endpoint config, used by both.
- `SmallChat-LM` depends on `SmallChat-MCP` in the baseline.
- No common capability / result / schema type.

## Key design decisions

**Capability as the central abstraction.**
`SmallChatCapability` is an abstract class. Subclasses declare:

- `#name` — agent-visible identifier (string).
- `#description` — human-readable summary.
- `#schema` — a `SmallChatCapabilitySchema` value object with
  named, typed, optional-or-required fields. Serialises to
  JSON Schema (MCP) or OpenAI function-call schema (LM native).
- `#run: aCapabilityCall` — receives a
  `SmallChatCapabilityCall` (typed arguments, session handle)
  and returns a `SmallChatCapabilityResult`.

One schema definition, two serialisations. The schema class owns
the translations so individual capabilities never see transport
specifics.

**`SmallChatCapabilityResult`** is a discriminated-union-style
value object: text, JSON object, image (for screenshots),
debug-session reference, or error. Transports pick the fields
they can render. This generalises today's `SmallChatToolResult`;
the MCP transport keeps emitting the MCP-compliant shape but does
so *from* a capability result, not *as* one.

**Reflective discovery, same as today.**
`SmallChatCapabilityRegistry default allCapabilities` =
`SmallChatCapability allSubclasses reject: [:c | c isAbstract]`.
Compile a capability class, it's live. (We use the class, not an
instance, to keep capabilities stateless — matches the existing
`SmallChatTool` pattern.)

**Existing MCP tools migrate class-by-class.** `SmallChatTool`
becomes a deprecated alias / adapter: new capabilities extend
`SmallChatCapability`; `SmallChatToolRegistry` is rewritten to
wrap `SmallChatCapabilityRegistry` and expose the MCP surface.
Migration is Red-Green-Refactor per tool, one tool per commit
(matching CLAUDE.md methodology).

**Native harness becomes a second transport binding, not a
re-implementation.**
`SmallChatLMSession.toolFor:` is replaced by a call into
`SmallChatCapabilityRegistry`. Tool-call JSON from the model is
unpacked through the same schema layer that MCP uses. The
`SmallChatLMEvaluateTool` hardcoding goes away; every capability
is callable.

**Cross-cutting concerns stay on the registry.** Notification
suppression, stray-debugger warning, uncaught-exception formatting
— these wrap every capability invocation, regardless of
transport. Transport-specific concerns (MCP framing, OpenAI
tool-call envelope parsing) stay in the transport adapters.

**Capability invocation never runs on the UI process.** This is
a hard rule that complements plan 01's LSP UI-isolation
assertion: even for non-LSP capabilities (evaluate, run_tests,
status, a Smalltalk refactoring), the registry's `#run:with:`
entry point asserts it is not running on Morphic and fails loudly
if it is. Rationale: any capability may indirectly call the LSP
client (a Famix query that misses the cache, a refactoring that
verifies diagnostics), and once UI isolation is transport-level
we get one consistent contract rather than per-capability care.

- **MCP transport:** already satisfies this for free — the MCP
  reader runs on a forked process, so capability dispatch is off
  the UI process by construction. No change from today.
- **LM native transport:** the chat window lives on Morphic.
  `SmallChatLMSession`'s tool-call loop must dispatch each
  capability on a fresh worker process (`[...] fork`). The
  current `toolFor:` code is called inline from the chat loop
  (which may itself run on Morphic for the non-streaming path
  and on a network process for the streaming path) — migration
  must relocate dispatch to a worker and post the result back
  via `UIManager default defer:` to update the conversation
  view. One worker per in-flight tool call; held in the session
  so it can be cancelled if the user closes the window.
- **Cancellation propagation:** when the session holds a worker
  for an in-flight capability, cancelling the worker propagates
  through to any LSP pending request via the cancel mechanism
  in plan 01. Closing the chat window cancels every in-flight
  capability for that session.

**Capability kinds and naming conventions.** To keep a large
registry navigable, capabilities are grouped by prefix in their
`#name`:

- `eval.*` — evaluate, run_tests, lint.
- `vcs.*` — status, commit, commit_files.
- `debug.*` — debug_sessions, debug_stack, debug_frame, etc.
- `smalltalk.*` — Smalltalk-side refactorings
  (`smalltalk.rename-method`, `smalltalk.extract-method`).
- `ts.*` — TypeScript/JavaScript refactorings and queries
  (`ts.rename-symbol`, `ts.references`, `ts.definition`).
- `css.*` — CSS-module refactorings and queries
  (`css.rename-class`).
- `famix.*` — project queries (`famix.list-modules`,
  `famix.references-of`).

Existing tool names (`evaluate`, `run_tests`, etc.) are **kept
as aliases** on the MCP transport for backwards compatibility
during migration. Deprecation horizon: once the native harness is
primary, retire the bare names.

**Smalltalk-side RBRefactoring exposure.** Via a thin
`SmallChatSmalltalkRefactoringCapability` adapter: each
`ReRefactoring` / `RBRefactoring` subclass exposed becomes one
capability, same preview-apply-verify-rollback lifecycle as the
TS refactorings (plan 04). This gives agents a unified vocabulary
across the two domains (TS/JS/CSS and Smalltalk) in the smallchat
repo.

## Dependencies

- Plan 04 (refactoring API) produces commands exposed via
  capabilities.
- Plan 01 (LSP client) produces pass-through capabilities.
- Plan 03 (Famix) produces query capabilities.
- Existing `SmallChat-MCP` and `SmallChat-LM` packages become
  consumers.

## Open questions

- Schema language. JSON Schema (MCP) and OpenAI tool-call schema
  overlap but diverge on edge cases (array `items`, `enum`,
  string format constraints). Do we target the intersection, or
  express both independently? Lean toward a Smalltalk DSL that
  emits either; keep the DSL minimal (scalar types, arrays,
  enums, required/optional).
- Session state. MCP calls are per-tool; the chat harness has a
  conversation. Should capabilities have access to session
  state (conversation id, last debug session, current workspace)?
  A `SmallChatCapabilityCall` could carry a session handle;
  capabilities that don't need it ignore it.
- Streaming results. The LM harness supports streaming reasoning;
  capabilities don't stream today. If an agent wants partial
  progress from a long refactoring, we need a streaming result
  type. Defer; start with unary.
- Capability versioning. When a schema changes, do we bump a
  version field? For now, agents are our own and we control both
  sides; add versioning only when we break compat externally.
- Tool description autogeneration from source. The `description`
  class method is a free-text string today; should we allow
  markdown? Multi-line? Keep as free text; formatting is the
  transport's business.
- Where does the current MCP-specific stray-debugger warning
  prefix live after migration? Stays as a registry-level wrapper.
  The MCP transport already formats the warning identically to
  today; nothing visible changes to existing agents.

## Milestones

1. `SmallChatCapability`, `SmallChatCapabilityCall`,
   `SmallChatCapabilityResult`, `SmallChatCapabilitySchema`,
   `SmallChatCapabilityRegistry` — core types, unit-tested
   without any transport.
2. Schema emitters for JSON Schema and OpenAI function-call.
3. MCP transport adapter: rewrite `SmallChatToolRegistry` to
   delegate to `SmallChatCapabilityRegistry`. Green on existing
   MCP tests.
4. Migrate one tool (pick `status`) to `SmallChatCapability`.
   Everything else still flows through the legacy adapter. Green.
5. Migrate remaining 15 existing tools, one commit each.
6. LM native transport adapter. Replace `toolFor:` dispatch with
   capability registry lookup. Expose all capabilities in the
   chat loop.
7. First new capability: a refactoring (depends on plan 04).
8. Deprecate `SmallChatTool` class; collapse into
   `SmallChatCapability`.

## Non-goals

- No retirement of the MCP transport in this phase. The point is
  unification.
- No cross-transport session sharing (same agent talking via MCP
  and LM native simultaneously). Sessions are per-transport.
- No capability-level auth / permissions. Trust boundary is the
  process boundary; capability discovery is all-or-nothing.
- No capability marketplace / remote load. Capabilities live in
  the image.
