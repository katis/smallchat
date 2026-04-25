# Context management

This directory holds the plan for keeping the smallchat agent's context
manageable as the in-image surface grows.

## The pressure

The smallchat image already exposes ~127 classes across 9 packages
(LM client, LSP client, tree-sitter, Famix metamodel, MCP server, the
yet-to-land refactoring API). Two audiences hit this surface today:

- **In-image LM agent** (`SmallChatLMSession` driving Qwen3.6-35B-A3B
  via OpenAI-compat). Only `evaluate` is wired as an agent tool; the
  model is expected to drive Smalltalk reflection from inside that one
  entry point.
- **Claude Code via MCP** (`SmallChatToolRegistry`, 16 tools today).
  Same pressure: discovery happens by `evaluate` plus blind reads.

Both fail badly as the class count grows. The antidote is *not*
"describe everything in the system prompt" but a small, fixed set of
discovery primitives operating over the unbounded image, plus
playbooks that carry working snippets, plus a wayfinding prompt that
teaches the *search procedure*.

## Relationship to plan 05

`plans/05-agent-tool-surface.md` (M4) unifies the MCP and LM tool
surfaces into one `SmallChatCapability` registry. That is a transport
unification — it does not, by itself, solve the context-bloat problem.

This directory's plans are **independent of M4**. The in-image core
(`SmallChatNav`, `SmallChatPlaybook`) is transport-free Smalltalk; the
MCP wrappers shipped here use the existing `SmallChatTool` pattern.
When M4 lands, the wrappers migrate to `SmallChatCapability` (a thin
mechanical change). The valuable code — the discovery and playbook
infrastructure — survives unchanged.

## Phase table

| # | Phase | Depends on | Why |
|---|---|---|---|
| 1 | [Discovery primitives](01-discovery-primitives.md) | - | The minimum that makes drilling cheap. Ship first, exercise immediately. |
| 2 | [Class metadata curation](02-class-metadata-curation.md) | 1 | Phase 1 reads metadata; Phase 2 makes that metadata worth reading. |
| 3 | [Playbooks](03-playbooks.md) | - | Recipes carry working snippets; smaller models compose poorly but modify well. |
| 4 | [Wayfinding system prompt](04-wayfinding-prompt.md) | 1, 3 | The prompt-side counterpart: teaches *how* to use 1 + 3, not *what* exists. |
| 5 | [Live inspection helpers](05-inspection-helpers.md) | 1 | Halt-driven exploration is Smalltalk's superpower; structure inspection so smaller models can lean on it. |

## Reading order

Read `01-discovery-primitives.md` first — it carries the full
implementation detail and grounds the rest. The other phases reference
its primitives and conventions; their files are outlines at the level
of the existing top-level plans (`plans/0N-...md`).

## Implementation cadence

User intent is to implement one phase, then *use* it during the next
M3 Famix-importer development cycle to feel the difference. Phases 2-5
land as the value of Phase 1 makes them obvious. Each phase is
self-contained and shippable.
