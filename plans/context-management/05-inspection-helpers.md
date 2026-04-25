# Phase 5 - Live inspection helpers

## Purpose and scope

Smalltalk's superpower for agents is *halt-driven exploration*: stop
the program at a point of interest, inspect a live object, decide what
to do next. A live inspect returns more useful information per token
than any class description because the data is *grounded* - real
values from the running system.

The captured-debug-session machinery (`SmallChatDebugEvaluator`,
`debug_*` tools) already exists. What's missing is *structured*
inspection output. `printString`-style summaries (`a SmallChatLMSession`)
are useless to a smaller model. Per-instance-variable key:value lines
the model can reason about are not.

Phase 5 adds two helpers and one playbook recipe so halt-driven
exploration is a first-class workflow.

## Key design decisions

**Structured key:value over `printString`.** `SmallChatNav inspect:
anObject` returns markdown with one `key: value` line per instance
variable, keyed by `instVarNames`. Values are rendered with a length
cap (`anObject printString` truncated to 120 chars). For collections,
also render size and the first 3 items.

**Consistent with discovery primitive shape.** Output is markdown
under the same Phase 1 budget. An agent that reads
`SmallChatNav describeClass:` output reads `inspect:` output the
same way.

**Stack summaries get the same treatment.** `SmallChatNav
stackSummaryFor: sessionId` wraps `debug_stack` output in markdown
matching the discovery primitives. The existing JSON output stays
(MCP `debug_stack` is unchanged); the markdown helper is a parallel
path optimised for in-prompt reading.

**Halt-driven exploration recipe in Phase 3 idiom.** A `SmallChatPlaybook
haltDrivenExploration` recipe documents the workflow: insert
`self halt`, run, list sessions, inspect frame 0, evaluate
expressions in the frame, decide, resume. Phase 5 ships the recipe
alongside the helpers because they are useful together.

## Deliverables

1. `SmallChatNav class >> inspect: anObject` - markdown rendering of
   instance variables and select metadata. Handles:
   - `Object` general case: instVarNames + `printString`-truncated values.
   - `Collection`: size, first 3 items, plus the general case.
   - `Dictionary`: keys (or first 3 key/value pairs).
   - `BlockClosure`: source if available.
2. `SmallChatNav class >> stackSummaryFor: sessionId` - markdown stack
   summary. Reuses `SmallChatDebugSessionRegistry default at:` to
   reach the session, then walks the stack with the same per-frame
   detail as `debug_frame` (receiver class, selector, args) but
   markdown-shaped.
3. MCP wrappers `inspect_object` (arg: any expression evaluated in
   image scope) and `inspect_stack` (arg: `sessionId`).
4. `SmallChatPlaybook haltDrivenExploration` recipe (Phase 3 file
   gets a new recipe).
5. SUnit on `inspect:` output for fixture classes with known instance
   vars (assert the expected key:value lines appear).

## Implementation procedure

TDD per helper. The fixture-class trick:

```smalltalk
| inspector subject |
subject := Point x: 3 y: 4.
inspector := SmallChatNav inspect: subject.
self assert: (inspector includesSubstring: 'x: 3').
self assert: (inspector includesSubstring: 'y: 4').
```

For `stackSummaryFor:`, capture a known exception via
`SmallChatDebugEvaluator` in the test, then assert the helper's
output mentions the expected selector at frame 0.

## Critical files

- `src/SmallChat-MCP/SmallChatDebugSessionRegistry.class.st` - the
  registry the helpers query.
- `src/SmallChat-MCP/SmallChatDebugStackTool.class.st` - structural
  precedent for stack walking.

## Verification

- `evaluate 'SmallChatNav inspect: SmallChatLMSession new'` returns
  a markdown block with `conversation:` and `client:` lines.
- During a debug session: `evaluate 'SmallChatNav stackSummaryFor:
  ''<sessionId>'''` returns a readable stack.
- `haltDrivenExploration` recipe walks an agent through inserting
  `self halt`, hitting it, inspecting, and resuming.
- `just test` and `just lint` clean.

## Open questions

- Recursion depth for nested objects. Render top-level instance vars
  with truncated `printString`; do not recurse by default. Add a
  `SmallChatNav inspect: anObject depth: n` variant only if needed.
- Image vs text rendering for objects whose printString is dominated
  by graphical state (Forms, Morphs)? Punt: render `printString`
  truncated; agents that need pixels use `World imageForm`
  separately.
- Should `inspect_object` evaluate the expression in image scope or
  in a debug-session frame's scope? Likely both: separate tool args
  (`expression`, optional `sessionId`+`frameIndex`). Phase-5 ships
  image-scope first; frame-scope follows when the workflow demands
  it.

## Non-goals

- No replacement of the existing `debug_*` MCP tools. They stay; the
  helpers are markdown-shaped parallel views.
- No persistent inspection state across calls. Each call builds the
  rendering from the current image state.
- No object-graph visualization. Tabular text only.
