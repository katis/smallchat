# Tree-sitter binding NULL-handle bug — post-mortem

Status as of 2026-04-25: **resolved** in commits `a857c58` (binding
fix) and `efd6303` (verifier baseline fix). M3 Phase 2 unblocked.

## TL;DR

`SmallChatTSGrammar` cached the resolved `TSLanguage` FFI handle as
part of its class-side singleton. Pharo's image save/restart nils
all FFI handles but leaves wrapper objects intact, so the cached
`TSLanguage` retained a NULL `ExternalAddress` on every dev-image
launch. `TSParser>>parseString:` accepted NULL silently and produced
a malformed tree; `tree rootNode` then segfaulted (silent VM SEGV,
no `pharo/PharoDebug.log` entry, MCP socket dropped).

Diagnostic that found it:

```smalltalk
SmallChatTSGrammar tsx language printString.   "'a TSLanguage(@ 16r00000000)'"
TSTsxLibrary uniqueInstance tree_sitter_tsx printString.   "'a TSLanguage(@ 16r115CDC018)'"
```

The cached one was NULL; the fresh one was valid. The fix re-fetches
on every access by storing `libraryClass` + `entryPointSelector`
instead of the resolved handle. C entry-points return a static dylib
address so each call is cheap.

## Why it took four crashes to find

The investigation chased false leads because the symptom was
"namedChildren walk crashes" rather than "language handle is NULL":

1. **Crash 1 / 2** (interactive evaluate, multi-level walk inside
   `String streamContents:`) suggested depth-of-walk + allocation
   pressure. Wrong — the cached singleton was already null; *any*
   node access would have segfaulted.
2. **Crash 3** (SUnit run holding `specifierNodes` across an LSP
   block) suggested "no TSNode references across yields." Wrong —
   the LSP block was incidental; the segfault was at first node
   access regardless.
3. **Crash 4** (no LSP, no fork, plain 2-level `namedChildren` walk
   under SUnit) tightened the rule to "depth-2 unsafe." Still wrong
   — depth-1 also crashed; the test class just happened to use
   2-level access.

The breakthrough was running the upstream
`TSParserTypescriptTest>>testParseTypescriptClass` via `run_tests`
and watching it pass: the binding works under SUnit when invoked
through `TSParser new + TSTypescriptLibrary uniqueInstance
tree_sitter_typescript`, but our `SmallChatTSParser>>parseTsxString:`
crashed because it routed through the singleton's stale handle.

## Hard rules going forward

- **Never cache FFI handles across image save/restart.** Pharo nils
  every `ExternalAddress` on resume but leaves the wrapper objects
  intact — `myCache language isNil` returns `false` even when
  `myCache language getHandle isNull` is `true`. Cache the
  *resolution recipe* (library class + entry-point selector) and
  re-fetch on every access; the dylib entry-point returns a static
  address so re-fetching is essentially free.
- **`isNil` checks on FFI wrappers don't catch null handles.** Health
  checks must compare `getHandle isNull`. The previous
  `SmallChatTreeSitterHealth>>checkGrammars` reported `#tsx -> #ok`
  the entire time the binding was crashing — it only checked
  `language isNil`, not the underlying address.
- **`isAvailable`-guarded tests skip silently when the binding
  doesn't load.** The verifier `default` group used to omit the
  TreeSitter Metacello baseline, so 22 tree-sitter tests "passed" in
  8 ms because `isAvailable` returned false. `efd6303` adds the
  binding to default; the same suite now takes ~100 ms doing real
  work. Watch for similar patterns when adding bindings: a binding
  that's not in the verifier baseline gets *zero* CI coverage.
- **Diff cached vs fresh handle when an FFI binding misbehaves.**
  Inspect `printString` of both — a `@ 16r00000000` is the smoking
  gun. The whole investigation could have been ten minutes if I had
  done this first.

## Files touched by the fix

- `src/SmallChat-TreeSitter/SmallChatTSGrammar.class.st` — drop
  `language` ivar; add `libraryClass` + `entryPointSelector`; rewrite
  `language` to re-fetch from the live dylib.
- `src/SmallChat-TreeSitter-Tests/SmallChatTSGrammarTest.class.st` —
  `testTsxLanguageIsResolvedFromDylibOnEachAccess` (regression).
- `src/BaselineOfSmallChat/BaselineOfSmallChat.class.st` — add
  `'TreeSitter'` to the `default` group so `just test` exercises the
  binding for real.
