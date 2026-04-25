# Phase 4 - Wayfinding system prompt

## Purpose and scope

Phases 1-3 produce the in-image scaffolding (discovery primitives,
curated metadata, playbooks). Phase 4 is the prompt-side counterpart:
teach the agent the *search procedure*, not the *search space*.

The current `SmallChatConfig class >> defaultSystemPrompt` is one
flat paragraph that mentions `evaluate(code)` and ~5 Pharo
conventions. It scales to the next 5 classes; it does not scale to
the next 50. Phase 4 restructures the prompt into segments with
explicit cache-friendly ordering and adds a wayfinding section that
points the agent at Phase 1 / 3 entry points.

Scope is the LM agent's system prompt. The MCP transport (Claude
Code's view) does not consume this prompt - Claude Code has its own
system prompt and reads tool descriptions from `tools/list`. Phase 1
already populates good MCP tool descriptions; Claude Code is covered
by them.

## Key design decisions

**Teach the procedure, not the topology.** ~300-500 tokens of prompt
text describing a 3-step procedure: "to do X, start with
`SmallChatNav findClasses:` or `SmallChatPlaybook listAll`; then
`describeClass:` on candidates; then `examplesFor:` before evaluating".
Pseudo-code the loop. Do not enumerate domains, package names, or
class lists - those grow; the procedure stays.

**Segment for cache layout.** The prompt is assembled from named
segments:

- `headerWayfinding` (invariant) - the procedure pseudo-code.
- `bodyConventions` (invariant) - existing Pharo / TDD / ASCII
  guidance.
- `tailSession` (varies) - workspace path, current task, debugger
  state if any, recent file edits.

Anthropic-style prompt caching reuses the longest invariant prefix.
Putting the wayfinding at the *top* (before conventions) keeps the
cacheable portion stable across sessions even when conventions shift.

**Restructure, don't append.** Today's `defaultSystemPrompt` is one
hand-built `String streamContents:` with embedded quote escapes.
Phase 4 splits it into the three segments above. Each is its own
class-side method (`headerWayfinding`, `bodyConventions`,
`tailSessionFor: aSession`); `defaultSystemPrompt` composes them.
Tests can assert each segment independently.

**Single source of truth for tool descriptions.** Tool descriptions
live on the `SmallChatTool` subclasses (as today). The wayfinding
text references the *names* of the discovery primitives - it does not
duplicate their descriptions. If a primitive's description changes,
the wayfinding text does not need editing.

## Deliverables

1. Refactored `SmallChatConfig class >> defaultSystemPrompt` into
   three segment methods.
2. New `headerWayfinding` content - the 3-step procedure pseudo-code,
   referencing `SmallChatNav` and `SmallChatPlaybook` by name.
3. `tailSessionFor: aSession` returning per-session context (initially
   empty; future phases populate). Document the cache-boundary
   contract in `SmallChatConfig`'s class comment.
4. SUnit tests on each segment method - non-empty, contains expected
   anchor strings (`'SmallChatNav'`, `'SmallChatPlaybook'`,
   `'evaluate'`).
5. Smoke-run a chat session with the target small model
   (Qwen3.6-35B-A3B-nvfp4) and observe whether it reaches for the
   primitives instead of guessing.

## Implementation procedure

TDD on segment methods first (each returns a string anchored on
expected content), then on `defaultSystemPrompt` (assert it contains
each segment).

The smoke run is a manual qualitative check, not a SUnit test. Open
the chat window, ask a discovery-flavored question ("what does
`SmallChatLMChatClient` do?"), and watch whether the model calls
`evaluate 'SmallChatNav describeClass: ...'` or tries to guess.

## Critical files

- `src/SmallChat-LM/SmallChatConfig.class.st` - the prompt source.
- `src/SmallChat-Tests/` (new test class for segment assertions).

## Verification

- `evaluate 'SmallChatConfig defaultSystemPrompt'` shows the
  segmented composition with the wayfinding section first.
- A chat session with a small model exercises the primitives in
  response to a natural discovery question. Capture a transcript
  before / after.
- `just test` and `just lint` clean.

## Open questions

- How long should the wayfinding section be? Start at 300-500 tokens;
  trim if the model ignores it (extra prompt that doesn't change
  behaviour is wasted budget).
- Should the prompt list every discovery primitive by name, or just
  point at `SmallChatNav listPrimitives` (a Phase 4 helper that
  returns the list)? Pointer is more durable as the set grows; trade-
  off is one extra round-trip on first use. Lean toward listing
  initially - five names is small enough.
- Do we need a per-session prompt fragment for "currently open
  debugger sessions"? Useful but cache-hostile. Defer until needed.

## Non-goals

- No prompt-engineering of the LM's reasoning style (thinking blocks,
  self-critique, etc.). Out of scope; orthogonal axis.
- No per-task prompt variants. One default prompt; recipes carry
  task-specific context.
- No edits to Claude Code's MCP tool descriptions; those are governed
  by Phase 1's tool classes.
