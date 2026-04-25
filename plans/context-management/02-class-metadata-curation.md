# Phase 2 - Class metadata curation

## Purpose and scope

Phase 1 reads metadata. Phase 2 makes that metadata worth reading.
`SmallChatNav describeClass:` is only as good as the class comments,
protocol structure, and example methods it surfaces. Today many
`SmallChat-Famix` entities have empty `<generated>` comments,
protocols use ad-hoc names (`accessing`, `accessing - metadata`,
`as yet unclassified`), and there is no `examples` convention.

Phase 2 imposes a small, sustainable curation discipline on the hot
classes the agent will hit most. It does not try to curate all 127
classes; it covers the ~15 the agent reaches first when it follows the
wayfinding procedure (Phase 4).

## Key design decisions

**Curate by hit-rate, not by package.** The agent will hit
`SmallChatLMSession`, `SmallChatLSPClient`, `SmallChatTSParser`,
`SmallChatToolRegistry`, `SmallChatNav` itself first. Curate those
fully. Famix entities are reached via Famix queries, not directly,
and their auto-generated stubs get class comments only when an agent
ends up describing them.

**`public-api` protocol convention.** A protocol named exactly
`public-api` (lowercase, hyphenated) holds the methods Phase 1's
`describeClass:` shows by default. Anything in `private`,
`private - <subdomain>`, or `accessing - metadata` is hidden by
default; agents drill in by calling `findMethods:` with the broader
pattern. Document the convention in `CLAUDE.md`.

**`examples` protocol convention.** A protocol named `examples` holds
class-side methods whose body is a worked example (a snippet that
runs and shows real results). Phase 1's `examplesFor:` renders each
as a fenced Smalltalk block with its selector as a heading. The body
becomes the agent's "here's a working snippet, change this path"
input.

**Keep comments short.** 1-3 sentences. Lead with "when to use this;
what it isn't for" - the same shape as the existing high-quality
comments (`SmallChatToolRegistry`, `SmallChatLMClient`). Do not
auto-generate; auto-generated comments are noise.

## Curation targets (initial pass)

Hot classes (~5) get full treatment - improved class comment,
`public-api` protocol, 1-2 `examples` methods:

- `SmallChatLMSession`
- `SmallChatLSPClient`
- `SmallChatTSParser`
- `SmallChatToolRegistry`
- `SmallChatNav` (its own comment - the entry point for everything)

Secondary classes (~10) get class-comment improvements only:

- Famix entities with non-trivial behaviour
  (`SmallChatFamixModule`, `SmallChatFamixClass`, etc.)
- `SmallChatTSTree`, `SmallChatTSNode`
- `SmallChatLSPDocumentSync`
- `SmallChatLMConversation`, `SmallChatLMChatClient`

Skip classes whose role is fully captured by their name and one-line
existing comment (`SmallChatConfig`, simple value objects).

## Deliverables

1. Improved class comments on the 5 hot + ~10 secondary classes.
2. `public-api` protocol populated on the 5 hot classes; existing
   methods recategorised.
3. `examples` protocol with 1-2 worked examples on each hot class.
4. `CLAUDE.md` updated with a short "Curation conventions" section
   documenting `public-api` / `private` / `examples`.

## Implementation procedure

Comments and protocols don't have a SUnit test seam. Verification is
by reading: call `SmallChatNav describeClass:` / `examplesFor:` on
each curated class and eyeball the output. If the output is what the
agent should see when it lands here, ship it.

Move methods between protocols via:

```smalltalk
SmallChatLMSession >> #sendUserInput: protocol: 'public-api'
```

(Pharo 13 selector for protocol moves is `Method >> protocol:` or
`Class >> classify:under:`. Confirm the working selector in-image
before rolling out.)

Each commit covers one class's curation: comment + protocol moves +
examples. Micro-commits ("nav: curate SmallChatLMSession", etc.) keep
the change history scannable.

## Critical files

- 5 hot class `.class.st` files under `src/SmallChat-LM/`,
  `src/SmallChat-LSP/`, `src/SmallChat-TreeSitter/`,
  `src/SmallChat-MCP/`, `src/SmallChat-Nav/`.
- `CLAUDE.md` - add the "Curation conventions" section.

## Verification

- Eyeball `SmallChatNav describeClass:` on each curated class.
- `just test` and `just lint` clean from fresh rebuild after the
  commit batch.
- Update Phase 1's "Open questions" with the resolved
  `describeClass:` filtering rule.

## Open questions

- Does the `public-api` discipline apply to class-side methods too,
  or only instance-side? Likely both, with separate protocols on each
  side. Decide after curating the first class.
- How does Phase 1 surface "private but interesting" methods like
  `SmallChatLMSession >> dispatchToolCall:`? `findMethods:` already
  shows everything; `describeClass:` hides them by design. The
  agent's escape hatch is `findMethods: '*' in: ...` for the full
  list.

## Non-goals

- No comments on Famix entities that have no behaviour beyond their
  generated slots. The metamodel's structure is the documentation
  there.
- No bulk auto-classification of existing `accessing` methods into
  `public-api`. Curate by hand on hot classes; let the rest of the
  image stay as it is.
- No new test infrastructure for "all hot classes have comments".
  Comments are content, not behaviour; lint can flag empty ones if
  it doesn't already.
