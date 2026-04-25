# Phase 3 - Playbooks

## Purpose and scope

Discovery primitives (Phase 1) help an agent *find* a class. Playbooks
help an agent *do* a task. The distinction matters, especially for
smaller models: composing three classes the model just learned about
is hard; modifying a working snippet that does the task is easy.

A playbook is a class-side method whose body returns a markdown recipe:
a working code snippet plus inline notes on what to change for the
caller's situation. The agent's interaction model is

1. `SmallChatPlaybook listAll` - one-line catalog of recipes.
2. `SmallChatPlaybook play: #recipeName` - full markdown body.

The catalog is the wayfinding entry point; bodies load only on demand.

Package: `SmallChat-Playbook` (new). Tests: `SmallChat-PlaybookTests`.

## Key design decisions

**Recipes mirror CLAUDE.md content.** The first batch of recipes is
content the model otherwise has to memorize (or re-derive each turn)
from `CLAUDE.md`. Encoding it as a callable recipe means the agent
only spends context tokens on the recipe it actually uses, when it
uses it.

**One class, recipes as direct selectors.** `SmallChatPlaybook` is
a single concrete class. Each class-side method `<recipeName>` returns
the recipe body. `listAll` enumerates `self class selectors` and
filters out the framework methods (`listAll`, `play:`, anything in
`private`). Adding a recipe is one method; removing one is one
deletion. No subclass hierarchy.

If recipe count grows past ~30 and they cluster naturally, split into
subclasses (`SmallChatTDDPlaybook`, `SmallChatDebugPlaybook`,
`SmallChatTonelPlaybook`) and have `listAll` enumerate across them.
Defer until forced.

**Markdown bodies, hard length cap.** Same budget as Phase 1 (3200
chars / ~800 tokens default). A recipe longer than the budget is a
sign it should be two recipes.

**Recipes are tested for *existence and shape*, not content.**
SUnit asserts: each recipe name is in `listAll`; `play:` returns a
non-empty markdown string; the result fits the budget. Bodies are
content; review by reading.

## Seed recipes

Drawn straight from `CLAUDE.md` - content the model shouldn't have to
re-derive:

- `compileMethodIntoDevImage` - the `Class compile: 'src' classified:
  '...'` recipe and the disk-vs-image gotcha.
- `captureExceptionViaDNU` - the DNU-driven entry-point loop. Restart
  the *caller* frame, not the DNU frame.
- `screenshotTheGUI` - `World imageForm` + `PNGReadWriter`. Read the
  resulting PNG with the harness's Read tool.
- `flushTonelWithoutCommitting` - the working-copy refresh recipe so
  `just test` sees in-image changes without a commit.
- `inspectIcebergStatusFromShell` - the desync recovery procedure
  (`referenceCommit:` + `refreshDirtyPackages` + recompile).
- `runTestsForOneClass` - SUnit narrowing pattern for fast iteration.
- `subprocessFromEvaluate` - the pipe / timeout / teardown checklist.

Add as the agent encounters tasks the recipes don't cover.

## Deliverables

1. `SmallChat-Playbook` package, one class:
   - `SmallChatPlaybook` with class-side `listAll`, `play:`, plus one
     class-side method per recipe.
2. ~7 seed recipes (above).
3. MCP wrappers under `src/SmallChat-MCP/`:
   - `SmallChatPlaybookListTool` (`playbook_list`).
   - `SmallChatPlaybookPlayTool` (`playbook_play`, arg `name`).
4. `SmallChat-PlaybookTests` - shape tests (existence, non-empty,
   under budget).
5. Baseline: add `SmallChat-Playbook`, `SmallChat-PlaybookTests`;
   `SmallChat-MCP` requires `'SmallChat-Playbook'`.

## Implementation procedure

TDD per recipe:

1. Test: `listAll` includes `#recipeName`; `play: #recipeName` returns
   a non-empty string under budget.
2. Implement the framework methods (`listAll`, `play:`) once.
3. Add each recipe as its own commit. The body is content; review by
   reading.

Order: framework methods first (one commit), then each recipe (one
commit each). MCP wrappers last.

## Critical files

- `CLAUDE.md` - the source of recipe content; cross-reference each
  recipe to the section it captures so the two stay aligned.
- `src/SmallChat-MCP/SmallChatLintTool.class.st` - structural
  precedent for MCP wrappers.

## Verification

- `evaluate 'SmallChatPlaybook listAll'` returns a markdown bullet
  list of recipe names.
- `evaluate 'SmallChatPlaybook play: #screenshotTheGUI'` returns a
  body that, when copy-pasted into `evaluate`, actually screenshots
  the GUI.
- MCP `playbook_list` / `playbook_play` round-trip the same content.
- `just test` and `just lint` clean from fresh rebuild.

## Open questions

- Do recipe bodies include argument placeholders (e.g. `<class-name>`)
  that the agent fills in, or just runnable defaults the agent edits?
  Lean toward runnable defaults so an agent can also use a recipe as
  a one-shot invocation. Mark placeholders inline in prose, not in
  the snippet.
- How are recipes versioned when CLAUDE.md changes? Manual sync per
  commit; cross-reference makes drift visible.
- Do we expose `SmallChatPlaybook find: pattern` for fuzzy lookup?
  Defer; `listAll` is short enough to scan.

## Non-goals

- No remote / loadable recipes; recipes live in the image like all
  other code.
- No per-user / per-project recipe layers; one global set.
- No runtime template substitution; recipe bodies are static markdown
  strings.
