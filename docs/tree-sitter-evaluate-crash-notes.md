# Tree-sitter `evaluate` crash notes

Two consecutive VM crashes during M3 Phase 2 work, both reproducible
from interactive `mcp__smallchat__evaluate` probes against tree-sitter
nodes. The same parsing happens in committed tests under `just test`
without crashing, so the issue is specific to the interactive path
(or to a particular shape of node walk we accidentally hit).

Documenting in case the pattern resurfaces.

## What crashed

Both probes had the same shape:

1. Parse a TS source containing a single import statement:
   `SmallChatTSParser new parseTsxString: 'import React from ''react'';'`.
2. Bind the parsed `tree`, `root`, and a child `imp` to evaluate-local
   temps.
3. Open `String streamContents: [ :s | ... ]` and inside the block,
   make multiple TSNode accessor calls in tight succession.

Concretely, probe #2 (the cleaner of the two) called per-child
`type` / `startByte` / `endByte` / `textFromSourceText:` and then
recursed one level via `c namedChildren doWithIndex:` to do the same
on grandchildren.

Both times the MCP transport dropped with
`MCP error -32000: Connection closed` and `ps aux | grep -i pharo`
returned no processes. **No entry was added to
`pharo/PharoDebug.log`** for either crash — only old unrelated
exceptions. Silent VM death is consistent with an FFI-side SEGV in
the tree-sitter dylib (or in the binding's TSNode lifetime
management) rather than a raised Smalltalk exception.

## What does not crash

`SmallChat-TreeSitter-Tests` parse the same input without trouble
under `just test` (verified before reproducing the second crash):

- `SmallChatTSNodeWalkerTest >> testImportStatementsOnButtonTsxReturnsOneImport`
  parses `lib/fixtures/ts-small/Button.tsx` (which contains
  `import React from 'react';`) and walks the import_statement.
- `SmallChatTSNodeWalkerTest >> testMemberExpressionsForStylesOnCssBridgeTsxReturnsTwo`
  parses a TSX fixture and calls
  `node namedChildren first textFromSourceText: source` -- the same
  `textFromSourceText:` primitive my probe used.

The test path runs inside SUnit which holds the `tree` reference for
the duration of one method and tears down between tests; the
evaluate path runs inside `SmallChatDebugEvaluator>>evaluateBlock:`
on a fork, with the result `printString` taken at the end.

## Plausible causes (uncertain — not bisected)

Plan 02 *Spike S2 findings* already noted:

> Binding quirk: `TSNode>>namedChildAt:` primitive-failed on a deep
> node in the walk (inside `TFSameThreadRunner
> >>primitivePerformWorkerCall:withArguments:`). Walking with
> `node namedChildren do: [:c | ...]` works. Looks like a struct-
> lifetime issue on the cursor path; use the collection accessor
> until M2 isolates it.

`namedChildren` "works" in the sense that it returns the right
collection, but it may still have lifetime hazards under specific
allocation patterns. Candidate triggers in the crashed probes:

1. **Two-level recursive walk inside one streamContents.**
   `imp namedChildren do: [ :c | ... c namedChildren do: ... ]`
   produces TSNode references to grandchildren whose backing memory
   is the same parsed tree. The streamContents block intersperses
   string concatenations between accesses; if any intermediate
   allocation triggers GC, a TSNode held in a temp could become
   invalid.
2. **Temps held across statements in one evaluate, re-accessed inside
   a streamContents block.** SUnit tests don't expose this shape
   because each test method's locals are short-lived inside one
   stack frame; evaluate's `tree` / `root` / `imp` temps live across
   several statements and into the block.
3. **The interactive evaluate fork uses a different priority
   (`SmallChatDebugEvaluator>>evaluateBlock:`) than the SUnit runner.**
   If the binding is sensitive to fork timing or to UFFI handle
   pinning across processes, the eval fork might be the differentiating
   factor.

We did not bisect. The next session should NOT re-probe interactively
until someone has time to instrument it carefully.

## Recovery steps

1. Confirm VM is gone: `ps aux | grep -i pharo | grep -v grep`
   returns 0 lines.
2. Check `pharo/PharoDebug.log` -- if the crash didn't write an
   entry, it was an FFI SEGV (expected for these crashes).
3. Tell the user to run `! just mcp` (relaunch the dev image from
   `src/`). The image rebuilds from disk, so any uncommitted
   in-image work is lost. Per CLAUDE.md "Never commit on Red", the
   uncommitted in-image state is always a Red test or in-progress
   compile -- the loss is bounded.
4. After reconnect, recompile the lost in-image work via
   `evaluate` and resume.

## Hard rule going forward

**Do not interactively probe TSNode structure via `evaluate` during
M3 work.** Specifically:

- No multi-level `namedChildren` walks inside `String streamContents:`.
- No re-accessing a TSNode across multiple evaluate statements after
  any `String streamContents:` allocation.
- No `TSNode selectors select: ...` introspection of the binding
  surface inside the same evaluate that holds parsed TSNodes.

If you need to know the AST shape of a particular construct, do one
of:

- Read the upstream grammar JSON
  (`/Users/katis/Documents/tree-sitter-libraries/tree-sitter-typescript/tsx/src/grammar.json`
  or the corresponding tree-sitter repo) directly with `grep`.
- Write a one-shot SUnit test that prints the tree to Transcript
  (or returns a shape descriptor) and run it via
  `run_tests` -- the SUnit harness has not been observed to crash
  on the same walks.
- Look at how existing committed walker code uses the API
  (`SmallChat-TreeSitter/SmallChatTSNodeWalker.class.st`) and
  follow the same idioms (single-level `namedChildren select:`,
  `select:` over `allNodesOfType:under:` collected lists, etc.).

The crash window cost roughly two evaluates plus a relaunch each
time; cheaper to read the grammar than to probe the binding.

## Sessions affected

- 2026-04-25 M3 Phase 2 work. Two crashes during attempted probes of
  import_statement structure to figure out where the source-string
  literal lives in the AST. The actual answer (shape):
  `import_statement -> {import_clause, string -> {string_fragment}}`
  -- derivable from the upstream grammar, no probe needed.
