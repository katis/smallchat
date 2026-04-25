# Phase 1 - Discovery primitives

## Purpose and scope

Five Smalltalk-callable discovery primitives, each capped at a hard
response budget, that let an agent walk from "I don't know what
exists" to "I have a worked example to modify" in 3-4 calls. Both
audiences benefit on day one:

- **In-image LM agent:** calls them via the existing `evaluate` tool
  (`evaluate 'SmallChatNav findClasses: ''LM'''`). No new tool slot
  needed; works through the wired tool the loop already has.
- **Claude Code via MCP:** thin `SmallChatTool` wrappers expose the
  same five primitives as `find_classes`, `describe_class`,
  `find_methods`, `show_method`, `examples_for`.

The primitives are reflection over Pharo's existing facilities
(`SystemNavigation`, `PackageOrganizer`, `Class >> selectorsInProtocol:`,
etc.). They are not new infrastructure; they are bounded views.

Package: `SmallChat-Nav` (new). Tests: `SmallChat-NavTests` (new).

## Key design decisions

**Markdown, not JSON.** Tools return GitHub-flavored Markdown strings.
MCP transports them as text content; in-image inspectors render them
acceptably; humans read them straight. JSON is structurally richer but
costs both audiences token budget on punctuation an agent then has to
strip. Markdown was chosen for both transports — so neither has to
re-format.

**Hard response budget per primitive.** `SmallChatNavBudget default
size` (default 3200 chars, ~800 tokens). When a result would exceed
the budget, truncate and append a one-line tail telling the agent how
to narrow:

    _87 matches; showing first 10. Refine with `package: ...`._

This prevents the runaway-context failure mode where one call dumps
the whole image. Smaller models in particular get derailed by huge
tool responses; the budget is a forcing function for iterative
drilling.

**Stateless class-side API.** `SmallChatNav` exposes only class-side
methods. No instance state, no caching. Image reflection is fast; an
added cache adds invalidation complexity for no measured gain. (If
benchmarking later shows hot paths, add caching then, not now.)

**MCP wrappers stay thin.** Each `SmallChatTool` wrapper is 5-10 lines:
parse args from `argsDictionary`, delegate to `SmallChatNav`, return
the string. All formatting and budgeting live on `SmallChatNav` so
the in-image agent (which doesn't go through `SmallChatTool`) gets the
same shape.

**Pattern matching:** `RxMatcher forString: pattern`. Reuse from
`SmallChatLintTool` — same regex semantics across tools. Case-
insensitive by default (we wrap the pattern in `(?i)` if it doesn't
already specify).

## Deliverables

### `SmallChat-Nav` package

Two classes:

- `SmallChatNav` — class-side API; abstract-leaning (no `new`).
- `SmallChatNavBudget` — value object with class-side `default` and
  `default: aBudget` for tests. One slot: `size` (Integer, character
  cap). Class-side `default size` returns 3200 unless tests set it.

Five class-side methods on `SmallChatNav`:

```
SmallChatNav class >> findClasses: pattern
SmallChatNav class >> findClasses: pattern in: packagePattern
SmallChatNav class >> describeClass: classNameOrSymbol
SmallChatNav class >> findMethods: pattern in: classNameOrPattern
SmallChatNav class >> show: className method: selector
SmallChatNav class >> examplesFor: className
```

### Output shape

Worked examples on the existing image:

**`findClasses: 'LM'`** ->

```markdown
* `SmallChatLMSession` (SmallChat-LM) - Controller for one chat session.
* `SmallChatLMClient` (SmallChat-LM) - Abstract provider seam.
* `SmallChatLMChatClient` (SmallChat-LM) - OpenAI /v1/chat/completions implementation.
* ...

_8 matches._
```

First sentence of the class comment, truncated to ~80 chars. Cap at
30 hits, then suggest narrowing.

**`describeClass: #SmallChatLMSession`** ->

```markdown
## SmallChatLMSession (package: SmallChat-LM, super: Object)

Controller for one chat session: holds the conversation + client and
exposes #sendUserInput: as the one-turn-at-a-time seam the UI drives.

**Instance vars:** conversation, client
**Public protocols:** chat, tool dispatch, accessing
**Key selectors:** sendUserInput:, dispatchToolCall:, conversation
**Examples:** see `SmallChatNav examplesFor: #SmallChatLMSession`
```

"Public protocols" filtering: when Phase 2's `public-api` discipline
exists, list only that protocol's selectors; until then, fall back to
"every protocol whose name does not start with `private`". Document
the convention in the class comment so it's discoverable.

**`findMethods: 'send' in: #SmallChatLMSession`** ->

```markdown
* `SmallChatLMSession>>sendUserInput:` (chat)
* `SmallChatLMSession>>sendUserInput:onDelta:` (chat)
```

Cap at 50; truncation tail when exceeded.

**`show: #SmallChatLMSession method: #sendUserInput:`** ->

````markdown
**SmallChatLMSession>>sendUserInput:** (protocol: chat)

Append the user turn, call the client, then loop as long as the reply
carries tool_calls...

```smalltalk
sendUserInput: aString
    | reply iterations |
    ...
```
````

Method comment first (when present), then the source as a fenced
Smalltalk block.

**`examplesFor: #SmallChatLMSession`** ->

If the class has an `examples` protocol (Phase 2 produces these on
hot classes), each example method's source is rendered as a fenced
block with its selector as a heading. Falls back to:

```markdown
_No examples yet. Try: `SmallChatNav findMethods: 'test' in: SmallChatLMSessionTest`_
```

when a sibling `<ClassName>Test` class exists.

### MCP wrappers

Five new `SmallChatTool` subclasses under `src/SmallChat-MCP/`:

| Class | Tool name | Args |
|---|---|---|
| `SmallChatFindClassesTool` | `find_classes` | `pattern` (string), `package` (optional string) |
| `SmallChatDescribeClassTool` | `describe_class` | `name` (string) |
| `SmallChatFindMethodsTool` | `find_methods` | `pattern` (string), `class` (optional string) |
| `SmallChatShowMethodTool` | `show_method` | `class` (string), `selector` (string) |
| `SmallChatExamplesForTool` | `examples_for` | `class` (string) |

Pattern (mirroring `SmallChatLintTool`): `inputSchema` returns a
Pharo `Dictionary` that serialises to JSON Schema; `run:` parses the
args dictionary and delegates to `SmallChatNav`. Each wrapper is one
short method — most of the body is the schema, not logic.

### Tests

`SmallChat-NavTests` — one test class per primitive:

- A found case (e.g. `findClasses: 'LM'` returns a string mentioning
  `SmallChatLMSession`).
- A not-found case (returns "_no matches_" or equivalent).
- A budget-truncation case: set `SmallChatNavBudget default size: 200`
  in `setUp`, restore in `tearDown`, assert the truncation tail line
  appears in the result.

`SmallChat-Tests` — wrapper tests that go through
`SmallChatToolRegistry default run: 'find_classes' with: ...` (mirrors
`SmallChatToolRegistryDebugTest`'s pattern). One per wrapper.

### Baseline

Edit `BaselineOfSmallChat.class.st` on disk:

- Add `SmallChat-Nav` and `SmallChat-NavTests` packages.
- `SmallChat-Nav` requires nothing.
- `SmallChat-MCP` adds `'SmallChat-Nav'` to its `requires:` (the
  wrappers depend on it).
- Add `SmallChat-Nav` to the `default` group; `SmallChat-NavTests` to
  `tests`.

Hand-edit + `commit_files`, per CLAUDE.md "non-Iceberg files".

## Implementation procedure

Follow CLAUDE.md's strict Red-Green-Refactor-Micro-commit, one method
per commit. The DNU-driven entry pattern fits naturally:

1. Write the SUnit test for `findClasses:` first (Red).
2. Hit DNU on `SmallChatNav` itself (the class doesn't exist yet) ->
   create class via `evaluate` (CLAUDE.md notes the Pharo 13 procedure).
3. Compile `findClasses:` minimum-implementation (Green).
4. Refactor only after Green; never together.
5. `commit`. Move to next primitive.

Order: `findClasses:` -> `describeClass:` -> `findMethods:in:` ->
`show:method:` -> `examplesFor:`. Each lands as its own commit.
MCP wrappers land as a second pass once the in-image core is green.

## Critical files

Existing, to read or extend:

- `src/SmallChat-MCP/SmallChatTool.class.st` - abstract base.
- `src/SmallChat-MCP/SmallChatLintTool.class.st` - structural
  precedent for pattern args + RxMatcher.
- `src/SmallChat-MCP/SmallChatToolRegistry.class.st` - reflective
  registration; nothing to edit here.
- `src/SmallChat-Tests/SmallChatToolRegistryDebugTest.class.st` - test
  pattern through the registry.
- `BaselineOfSmallChat.class.st` - hand-edited for new packages.

## Reusable utilities

No new infrastructure. Everything builds on:

- `RxMatcher forString:` (regex matching).
- `SystemNavigation default allClasses` (class enumeration).
- `Smalltalk globals at: ifAbsent:` (name resolution).
- `Class >> selectors`, `selectorsInProtocol:`, `comment`,
  `instVarNames`, `package`.
- `(Class >> #sel) sourceCode`, `protocol`.
- `String streamContents:` for output assembly.
- `PackageOrganizer default packages` for package filtering.

## Verification

1. **TDD per primitive** - test first, smallest impl, commit.
2. **In-image smoke** - `evaluate 'SmallChatNav findClasses: ''LM'''`
   returns a markdown bullet list under the budget.
3. **MCP path** - from Claude Code, call `find_classes` with
   `{pattern: "LM"}`. Same body, transported via `SmallChatToolRegistry`.
4. **Headless rebuild gate** - `just test` and `just lint` from a
   fresh shell pass after the commit batch (verifies Tonel survives
   verifier rebuild).
5. **Hands-on dogfooding** - use the new tools while doing M3 Famix
   importer work. Qualitative signal: does the user reach for
   `find_classes` / `describe_class` instead of
   `evaluate '... allSubclasses ...'`?

## Open questions

- **`examplesFor:` source.** Proposal: a method protocol called exactly
  `examples` (matches Pharo convention). If empty, fall back to a
  sibling `<ClassName>Test` class's selectors. Decide once we hand-
  write a few examples on `SmallChatLMSession` (Phase 2) and see what
  reads well.
- **`describeClass:` "key selectors".** Start with: every selector in
  the `public-api` protocol (after Phase 2); if none, top ~8 by
  lexicographic order excluding `private*`. Tune once we see results
  on real classes.
- **Budget unit.** Start with characters (3200 default); switch to a
  ~4-chars-per-token estimate only if it matters in practice.
- **Truncation strategy.** First-N items vs sample-uniformly? Start
  with first-N (cheaper, deterministic, lets the agent narrow with
  `package: ...`). Revisit only if it hides relevant matches in
  practice.

## Non-goals

- No `find_senders` / `find_implementors` - defer; the core five
  cover the search-then-describe-then-modify loop.
- No structured (JSON) output - Markdown for both transports.
- No caching of results across calls.
- No system-prompt edits (Phase 4's job).
- No class-comment edits except the new classes' own comments
  (Phase 2's job).
- No migration to `SmallChatCapability`. M4 takes that on.
