# Tree-sitter VM crash notes

Three consecutive VM crashes during M3 Phase 2 work. The first two
were interactive `mcp__smallchat__evaluate` probes against tree-sitter
nodes; the third was a SUnit test running through `mcp__smallchat__run_tests`,
which had been the assumed-safe alternative. None left a Smalltalk
stack trace -- silent FFI SEGV in the tree-sitter dylib (or in the
binding's TSNode lifetime management).

The third crash refines the hypothesis: the unsafe pattern is not
"interactive evaluate" specifically, it is **holding TSNode references
across any operation that yields the process** (LSP block, Semaphore
wait, Delay, GC trigger). The first two crashes hit it via
`String streamContents:` allocations between accesses; the third hit
it via the importer fork blocking on `client request:onDocumentUri:`
with a `specifierNodes` collection of TSNodes still on the stack.

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

**Never hold TSNode references across an operation that yields the
current process.** The window starts at `parser parseTsxString:` /
`parseCssString:` and ends when the last TSNode reference goes out
of scope. Inside that window:

- **Pre-materialize.** Walk to the nodes you need, copy out
  `startByte` / `endByte` / `type` / `(node textFromSourceText: src)`
  into pure Smalltalk values (Strings, Integers, Dictionaries) in
  one tight loop, then drop every TSNode reference (let the locals
  go out of scope) **before** any blocking call.
- **Never block while holding TSNodes.** No `client request:` (LSP),
  no `Semaphore wait`, no `Delay forMilliseconds: ... wait`, no
  `pending result`. The importer fork issuing LSP definition requests
  per-import must build its specifier table from pre-materialized
  Strings and Integers, never from a `specifierNodes do: [:n | ...
  client request: ... ]` loop.
- **Single-level `namedChildren` only.** The committed walker code
  in `SmallChatTSNodeWalker` uses one-level `namedChildren select:`
  / `detect:` / `collect:` patterns. Don't recurse via TSNode-of-
  TSNode in materialization code; if you need descendants, use the
  flat `allNodesOfType:under:` walker.

And from the original interactive-evaluate rule:

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

- 2026-04-25 M3 Phase 2 work. Three crashes:
  1. Interactive evaluate probe of `import React from 'react';` shape
     (multi-level namedChildren walk inside streamContents).
  2. Same shape, same probe -- VM had been relaunched between.
  3. SUnit run of `SmallChatFamixImporterOrchestrationTest >>
     testImportTsFileUriEmitsImportEntityResolvedViaDefinition`.
     The importer fork held `specifierNodes` (a collection of TSNodes)
     while blocking on `client request: ... onDocumentUri:` for the
     LSP definition response; SEGV when execution resumed and
     iterated. Conclusion: SUnit isn't a safer harness on its own --
     what matters is whether TSNodes survive a yield. The fix
     (pre-materialize before any LSP block) lands in M3 Phase 2's
     production code; the test then does not need a fork-based
     dance at all if the importer can be exercised through a
     non-blocking surface.

  AST shape, derivable from upstream grammar without probing:
  `import_statement -> {import_clause, string -> {string_fragment}}`.
