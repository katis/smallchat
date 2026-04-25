# M3 Phase 2 -- blocked by tree-sitter binding crashes

Status as of 2026-04-25 evening session.

## What landed

Phase 0 + Phase 1 of plan
`/Users/katis/.claude/plans/plan-how-to-implement-swift-falcon.md`
shipped clean across six git commits:

1. `8ec2775` baseline: declare SmallChat-Famix-Importer packages
2. `e51c8e3` famix-importer: Phase 0 plumbing
3. `95ab55a` famix-importer: top-level Class symbol -> Famix entity
4. `2b3efff` famix-importer: cover Function / Interface symbol kinds
5. `99f6dcd` famix-importer: cover Method / Constructor / Property; pin unknown-kind skip
6. `0451098` famix-importer: importTsFileUri:text: orchestration via LSP

`SmallChat-Famix-Importer` package and `SmallChatFamixImporter`
class exist with:

- `populateFromDocumentSymbols:intoUri:text:` walking hierarchical
  `documentSymbol` responses, mapping LSP SymbolKinds (Class,
  Interface, Function, Method, Constructor, Property/Field) to the
  matching `SmallChatFamixModel` entity, recursing into children
  with `owningClass` set on Methods nested under Classes.
- `importTsFileUri:aUri text:aText` orchestrating: opens the URI on
  the LSP client, fetches `documentSymbol`, populates from it.
- 8 passing tests in `SmallChat-Famix-Importer-Tests` covering each
  SymbolKind plus one fork-based orchestration test against a stub
  LSP transport.

Containment slots added to existing Famix entities (Phase 0):
`SmallChatFamixModule >> project`, `SmallChatFamixMethod >>
owningClass`, `SmallChatFamixCSSClass >> file`,
`SmallChatFamixCSSClassReference >> referent / unresolved`.

`SmallChatFamixImport >> targetUri / unresolved` slots added during
Phase 2 attempt and committed via the Phase 0 plumbing rationale --
trivial accessors, not yet exercised by any committed test. Leaving
them is fine; they cost nothing and the next attempt will use them.

## What blocks Phase 2

Phase 2 needs tree-sitter to walk `import_statement` nodes so that
the importer can ask the LSP `textDocument/definition` for each
specifier. Four reproducible Pharo VM crashes during this work:

1. Interactive `evaluate` probe: parsed
   `import React from 'react';` then walked `namedChildren`
   recursively inside a `String streamContents:` block. Silent SEGV
   (no PharoDebug.log entry, MCP socket dropped). Documented in
   `docs/tree-sitter-evaluate-crash-notes.md` (commit `46aca4b`).
2. Same shape, fresh image. Same silent SEGV.
3. SUnit run of an orchestration test where the importer fork held
   a `specifierNodes` collection (TSNodes) across a blocking
   `client request:onDocumentUri:` call for the LSP definition
   response. Silent SEGV. Refined the rule to "no TSNode reference
   survives any process yield", documented in `dae788d`.
4. SUnit run of a pre-materialize unit test with NO LSP, NO fork --
   just `parseTsxString:` then a 2-level `namedChildren` walk
   (`imp namedChildren detect: [c | c type = 'string']` then
   `stringNode namedChildren detect: [c | c type = 'string_fragment']`).
   Silent SEGV. The pre-materialize defence does not fix the
   underlying problem.

All four crashes left the same trace: `ps aux | grep -i pharo`
returns 0, `pharo/PharoDebug.log` unchanged. Consistent with an FFI
SEGV in the tree-sitter dylib (or in the Evref-BL binding's TSNode
lifetime management).

## What we know about the failure mode

- `SmallChatTSNodeWalkerTest` runs cleanly under `just test` and
  exercises `parseTsxString:` against `lib/fixtures/ts-small/Button.tsx`
  (which contains the same `import React from 'react';` line). So
  parsing the fixture is safe in some configurations.
- The walker tests that work do at most 2-level TSNode access:
  `m namedChildren first textFromSourceText: sourceText`
  inside `memberExpressionsFor:objectName:inSource:`. That's
  level-1 TSNode -> property.
- Crash 4's 2-level chain
  (`imp namedChildren detect: [c | c type = 'string']` returning
  a level-2 TSNode, then `level-2 namedChildren detect: ...`
  returning a level-3 TSNode) goes one level deeper than the
  proven-safe walkers do.
- Plan 02's S2 findings already noted: `TSNode>>namedChildAt:`
  primitive-failed on a deep node. Workaround was
  `namedChildren do:`. Our crash 4 evidence suggests
  `namedChildren do:` also fails on deep enough chains.

## Recommended next steps (asking user)

Three options, ranked by my preference:

### A. Bisect the binding crash before continuing M3

Pick a bisection plan:
- Single fresh `just mcp` image, single SUnit test, increasingly
  deep TSNode access (1-level, 2-level, 3-level). Find the depth
  threshold.
- Try alternative APIs the binding may expose (`childByFieldName:`,
  visitor-based traversal, `TSQueryCursor`) to see if one is safe.
- Possibly upgrade or downgrade the TreeSitter binding pin in the
  baseline (currently `Evref-BL/Pharo-Tree-Sitter` SHA
  `e621baf6...`, tag v.1.1.1 from 2026-03-31).

This is real spike work -- 1-3 hours probably. Should be planned
explicitly, not retrofitted into "Phase 2 implementation".

### B. Implement Phases 2 / 3 / 4 / 5 with source-text scanning, defer tree-sitter

For Phase 2 specifically: regex-match `import\s+...?\s*from\s*['"](.+?)['"]`
plus side-effect-import variant. Extract specifier + position. No
tree-sitter call at all. Same orchestration shape, same Famix
entities emitted; the implementation comment documents the
limitation (no template-literal handling, no dynamic import, no
re-export) and references this report.

For Phase 3 (JSX detection) and Phase 5 (CSS bridge), the tree-
sitter dependency is harder to dodge but maybe possible with regex
heuristics. Phase 4 (CSS parsing) may have to wait.

Pros: M3 unblocks today. Cons: code that needs to be replaced when
the binding works; forks the implementation strategy from the plan.

### C. Stop M3 here; pick up after the binding spike lands

Phase 0 + Phase 1 are real value (LSP-driven Class/Function/Method
population works). Hand back, plan the binding spike as a top-level
work item, resume M3 once the tooling works.

This is the most honest option. Phase 2 is the entry point for the
rest of M3 -- if we ship a regex-based version we'll have to undo
it.

## Where to resume

If Option A: I can drive the bisection in a focused session. Need
the user to be available for periodic relaunches and to OK the
binding pin change if that turns out to be the fix.

If Option B: Tell me to proceed; I'll write the regex-based
populateImportsFromText: and continue. The interface and tests stay
the same shape as the plan.

If Option C: Nothing else to do this session. Update TODO.md to mark
M3 partially done, add the binding spike as a top-level task.
