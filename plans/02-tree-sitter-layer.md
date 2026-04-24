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

**TS vs TSX.** Upstream `tree-sitter-typescript` exports two
grammar symbols from one dylib: `tree_sitter_typescript` and
`tree_sitter_tsx`. Whether the Pharo binding's current
`TreeSitter-Typescript` wrapper exposes both is **not documented
and must be verified** against the v1.1.1 source. If only one is
bound, adding the other is a one-line FFI binding.

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

## Dependencies

- External: `Evref-BL/Pharo-Tree-Sitter` v1.1.x via Metacello.
- External: tree-sitter dylibs built for arm64-darwin. Building is
  offline; shipping them via git-LFS or a `lib/tree-sitter/`
  check-in is a cross-cutting decision (see TODO).
- Internal: Plan 03 (Famix) consumes ranges. Plan 04 (refactoring)
  composes tree-sitter edits with LSP edits for CSS and the
  CSS-module bridge.

## Open questions

- Does the upstream binding already expose both `typescript` and
  `tsx` grammars, or just one? Open the `TreeSitter-Typescript`
  package on disk and read it — cheap. Fold the answer back here.
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
