# Plan 02 - Tree-sitter layer

## Purpose and scope

Make tree-sitter available inside the Pharo image for three
grammars — TypeScript, JavaScript, and CSS — plus a tree-sitter
view over TSX. Expose a small query / range-extraction helper API
that the Famix population pipeline and the refactoring layer use
for anything LSP can't cleanly answer: precise source ranges for
extracted entities, CSS class definitions, CSS class references
inside template strings and JSX attributes.

Package name: `SmallChat-TreeSitter` — a thin adapter on top of
the `Evref-BL/Pharo-Tree-Sitter` binding. We do not fork or
modify the binding.

## Spike findings

**Canonical binding:** `Evref-BL/Pharo-Tree-Sitter`, v1.1.1
(2026-03-31). Loaded via Metacello:

```smalltalk
Metacello new
  baseline: 'TreeSitter';
  repository: 'github://Evref-BL/Pharo-Tree-Sitter:main/src';
  load.
```

Packages shipped: `TreeSitter`, `TreeSitter-Libraries`,
`TreeSitter-Typescript`, `TreeSitter-CSS`, `TreeSitter-Python`,
`TreeSitter-C`, `-HTML`, `-XML`, `-Groovy`, `-Mermaid`,
`-Highlighter`, `-Visitor`, `-FAST-Utils`.

**Not shipped as a Pharo package: `TreeSitter-Javascript`.** The
upstream `tree-sitter-javascript` grammar exists and compiles, but
the Pharo binding doesn't ship a wrapper package for it. We need
to add one (or vendor a minimal wrapper in our own package).

**TS vs TSX.** Upstream `tree-sitter-typescript` ships two
grammars from one source tree (`typescript/` and `tsx/`
subdirectories, each producing its own dylib: `libtree-sitter-
typescript.dylib` and `libtree-sitter-tsx.dylib`). The Pharo
binding at v.1.1.1 binds only `tree_sitter_typescript` — see the
Spike S2 findings below for the exact delta we need to add in
`SmallChat-TreeSitter`.

**Prebuilt dylibs.** Only Python and TypeScript have automated
dylib generation in the binding's build automation. Prebuilt
Windows/macOS binaries are on Zenodo
(`10.5281/zenodo.15423234`). For arm64 Macs, we must verify or
locally rebuild the dylibs; `file libtree-sitter-typescript.dylib`
is the check.

**Dylib discovery.** The binding searches Pharo's VM folder, a
cloned-repo path, and `/opt/homebrew/Cellar/tree-sitter/`. If we
ship our own arm64 dylibs, we drop them beside the image and
register a search path.

**In-image state.** Tree-sitter is not loaded in the dev image
today (confirmed: no `TreeSitter*` globals, no `TSParser` etc.).
Adding it is a baseline change, done in plan 03's initial load.

**Queries.** The binding ships `TreeSitter-Highlighter` which uses
queries internally, but `TSQuery` / `TSQueryCursor` are not
prominently documented. For our v1 needs, walking named children
from the root is reliable and well-understood.

## Key design decisions

**Adapter-thin, grammar-agnostic.** `SmallChat-TreeSitter`
exposes: `SmallChatTSParser` (wraps a language pointer and a
parsed tree), `SmallChatTSRange` (start / end byte + line/column),
`SmallChatTSQuery` (optional, lazy; only if we find we need
queries for CSS), and a small set of helper selectors for the
common walks ("all top-level function declarations", "all
`styles.X` member-expressions", "all template strings").

**Four grammar bindings.** One `SmallChatTS<Lang>Grammar`
singleton per language: TypeScript, TSX, JavaScript, CSS. Each
knows the dylib path and the exported `tree_sitter_<lang>` symbol.
Loading is lazy; calling `SmallChatTSTypeScriptGrammar default`
initialises the FFI binding and caches.

**File-extension routing.** `.ts` -> typescript, `.tsx` -> tsx,
`.js` / `.jsx` / `.mjs` -> javascript (use `tsx` grammar for
`.jsx` only if the javascript grammar is unreliable for JSX;
plan to use javascript first). `.css` and `.module.css` ->
css.

**Range API speaks UTF-16 code units for LSP parity.** LSP uses
UTF-16 code-unit offsets in line/character positions by default;
tree-sitter speaks bytes. The adapter converts. This lets the
refactoring layer pass positions between LSP responses and
tree-sitter nodes without translating coordinates every time.

**Arm64 macOS is the primary target.** Ship dylibs built locally
into `lib/tree-sitter/arm64-darwin/` and register that path at
startup. Other platforms come later.

**Parser pool, not per-call allocation.** A small per-thread (per
Pharo process) parser cache per grammar. Parsing a 2KB TS file
shouldn't allocate a fresh parser every time.

## Spike S2 findings (2026-04-24)

Probed Evref-BL v.1.1.1 bringup end-to-end on arm64-darwin.
Answers folded into the sections above; recording here for
posterity.

- **Actual tag is `v.1.1.1` (with a dot after `v`), not `v1.1.1`
  as cited in earlier notes.** Released 2026-03-31, commit
  `e621baf6cf9d33289289098f04e92326d3f6716c`. We pin to the SHA
  in the baseline (same pattern S1 used for OSSubprocess) to
  survive any tag re-pointing.
- **Transitive deps resolve cleanly.** Loading the binding pulls
  `PharoBackwardCompatibility` (`jecisc/PharoBackwardCompatibility
  :v1.x.x`) and `NeoJSON` (`svenvc/NeoJSON/repository`). ~6s
  total to load `default typescript css` groups on a warm dev
  image.
- **The `default` group does not include language packages.**
  Language packages (`TreeSitter-Typescript`, `TreeSitter-CSS`,
  etc.) live in per-language groups (`typescript`, `css`,
  `python`, ...). `default` loads the core + Highlighter /
  Visitor / Spec / Libraries only. Baseline pin loads
  `default typescript css` — adjust when we add more grammars.
- **`TreeSitter-Javascript` is not shipped as a package**
  (confirmed — no `TSJavascriptLibrary`, no `TSLanguage class
  >>javascript` accessor). Consistent with the earlier doc.
- **Binding surface: only `tree_sitter_typescript` is exposed.**
  Package `TreeSitter-Typescript` ships exactly one FFI class
  (`TSTypescriptLibrary`, subclass of `FFILibrary`) with a single
  FFI method `tree_sitter_typescript`. No `tsx` library class, no
  `TSLanguage class>>tsx` accessor. The delta we need to add to
  `SmallChat-TreeSitter` is a parallel `TSTsxLibrary` plus a
  `TSLanguage class>>tsx` extension method:

      FFILibrary subclass: #TSTsxLibrary.
      "package: 'SmallChat-TreeSitter'"
      TSTsxLibrary>>macLibraryName
        ^ FFIMacLibraryFinder findAnyLibrary: #( 'libtree-sitter-tsx.dylib' )
      TSTsxLibrary>>unix64LibraryName
        ^ FFIUnix64LibraryFinder findAnyLibrary: #( 'libtree-sitter-tsx.so' )
      TSTsxLibrary>>win32LibraryName
        ^ FFIWindowsLibraryFinder findAnyLibrary: #( 'libtree-sitter-tsx.dll' )
      TSTsxLibrary>>tree_sitter_tsx
        ^ self ffiCall: 'TSLanguage * tree_sitter_tsx ()'
      TSLanguage class>>tsx
        ^ TSTsxLibrary uniqueInstance tree_sitter_tsx

  Five methods, one class. This was proved in-image against the
  real dylib; M2 can land it verbatim. Mirror `TSCSSLibrary` /
  `TSTypescriptLibrary` for naming.
- **TS grammar cannot substitute for TSX.** On `lib/fixtures/
  ts-small/Button.tsx` the TS grammar reports three `ERROR`
  nodes in the return expression and hallucinates `{label}` as
  a regex binary expression. The TSX grammar parses the same
  file with zero errors and correct `jsx_element` /
  `jsx_opening_element` / `jsx_attribute` / `jsx_expression` /
  `jsx_closing_element` nodes. `.tsx` files must route to the
  TSX grammar — no fallback.
- **`.js` / `.jsx` parsing strategy still open.** We did not
  probe whether the tsx grammar subsumes plain JS / JSX (it
  accepts TypeScript syntax, so a pure-JS file should parse,
  but JSX-in-JS files might). The open question above already
  covers this.
- **Auto-build works, on macOS arm64.** The binding's
  `TSLibrariesTypescript new ensureTypescriptLibraryExists`
  clones `tree-sitter/tree-sitter-typescript` at its latest
  GitHub release tag into `~/Documents/tree-sitter-libraries/
  tree-sitter-typescript`, runs `make` (per
  `TSLibrariesCommandLines>>tsBuildCommandForMacAndLinux:`),
  then copies `libtree-sitter-typescript.dylib` into
  `<vm>/Pharo.app/Contents/MacOS/Plugins/`. Result verified
  arm64 via `file`.
- **tsx dylib is a by-product of the same make, but the binding
  does not move it.** Upstream's `common/common.mak` builds both
  `typescript/libtree-sitter-typescript.dylib` and
  `tsx/libtree-sitter-tsx.dylib`. `moveTypescriptLibraryToPharoVM`
  only copies the typescript one. For S2 we manually copied the
  tsx dylib into the same Plugins directory; for M0 / S3, the
  vendored-dylibs strategy under `lib/tree-sitter/arm64-darwin/`
  eliminates the reliance on the binding's auto-build entirely.
- **`TSTypescriptLibrary>>uniqueInstance` is a shadowed
  instance method** (same selector exists class-side on
  `FFILibrary`). Calling `TSTypescriptLibrary uniqueInstance`
  from class-side does NOT trigger the auto-build hook — only
  `TSLibrariesTypescript new ensureTypescriptLibraryExists`
  does. Probably a binding bug, not ours to fix. If we trigger
  auto-build from `SmallChat-TreeSitter`, call the instance
  method explicitly.
- **Binding quirk: `TSNode>>namedChildAt:` primitive-failed**
  on a deep node in the walk (inside `TFSameThreadRunner
  >>primitivePerformWorkerCall:withArguments:`). Walking with
  `node namedChildren do: [:c | ...]` works. Looks like a
  struct-lifetime issue on the cursor path; use the collection
  accessor until M2 isolates it.
- **Node selector set on `TSNode`:** `isErrorNode`, `hasError`
  is NOT a selector — the API spells it `isErrorNode`. `type`
  returns a Pharo `String`; `startByte` / `endByte` are ints.
  Relevant for the M2 range helpers.
- **Pharo 13 quirk reconfirmed.** `FFILibrary subclass: #Foo
  instanceVariableNames: '' classVariableNames: '' package:
  'Pkg'` does not exist in Pharo 13 (DNU, same as CLAUDE.md
  notes). Use `FFILibrary subclass: #Foo` + `'Pkg' asPackage
  addClass: cls`. Relevant for M2 wiring.

## Dependencies

- External: `Evref-BL/Pharo-Tree-Sitter` pinned at commit
  `e621baf6...` (tag `v.1.1.1`) via Metacello.
- External: tree-sitter dylibs built for arm64-darwin. Building is
  offline; shipping them via git-LFS or a `lib/tree-sitter/`
  check-in is a cross-cutting decision (see TODO).
- Internal: Plan 03 (Famix) consumes ranges. Plan 04 (refactoring)
  composes tree-sitter edits with LSP edits for CSS and the
  CSS-module bridge.

## Open questions

- Do we need `TSQuery` for CSS class-name extraction, or does a
  walk-all-named-children-of-type-`class_selector` pass suffice?
  Spike while building the CSS side of plan 03.
- Dylib distribution. Build on the dev machine, vendor into
  `lib/tree-sitter/`, document how to rebuild. Or: build as part
  of `just install` by detecting missing dylibs and invoking
  tree-sitter CLI. The second is nicer but assumes `tree-sitter`
  CLI is on PATH, which not every machine will have. Defer until
  we feel the pain.
- Tree-sitter-javascript wrapper. Upstream `typescript` grammar
  covers most of what we'd want from `javascript`, and TS-in-JS
  files is a common pattern (JSDoc typed). We can probably start
  by parsing all `.js` files with the TS grammar; if that breaks
  on real code (e.g. JSX in `.jsx` files), add the javascript
  grammar wrapper.
- Performance. Parsing a large TS project on every Famix
  regeneration is wasteful. Tree-sitter supports incremental
  re-parse by passing the old tree; wire that through once the
  naive path is green.

## Milestones

1. Load the Evref-BL binding into the dev image via Metacello.
   Confirm `TSParser` class appears; parse a trivial TS snippet
   and print the root node.
2. Build or verify arm64-darwin dylibs for `typescript`, `tsx`,
   `javascript`, `css`. Land them in `lib/tree-sitter/`.
3. `SmallChatTSParser` + grammar singletons. Able to parse a file
   from disk and return a root `TSNode` in Pharo.
4. Range helpers: byte range <-> UTF-16 LSP position, line/column.
5. Named-child walker helpers for the common queries the Famix
   pipeline will need (top-level declarations, imports, template
   strings, JSX attribute values, CSS class selectors).
6. Incremental re-parse, parser pool. Optimisation, do last.

## Non-goals

- No in-Pharo tree-sitter grammar compilation. We ship dylibs.
- No high-level DSL on top of queries. The adapter is thin; the
  consumer packages know what they want.
- No syntax highlighting surface. `TreeSitter-Highlighter` is the
  binding's own play-area; we don't reuse or compete with it.
- No tree-sitter as primary semantic source for TS/JS. It
  provides ranges and syntactic structure; semantics go through
  LSP.
