# Plan 03 - Famix model

## Purpose and scope

A minimal Famix-X metamodel for TypeScript, JavaScript, and
CSS Modules, populated from LSP responses plus tree-sitter ranges.
The model is the structural / aggregation layer the refactoring
API queries when it needs to say "all modules that import
function F" or "all TS files that reference `styles.active` from
`Button.module.css`".

We derive the model from observation, not parsing: the importer
watches the LSP and tree-sitter, writes Famix, and throws it
away when files change. No types, no generics, no cross-file
symbol resolution — those stay in the LSP and are queried on
demand.

Package names: `SmallChat-Famix` (metamodel) and
`SmallChat-Famix-Importer` (population pipeline).

## Spike findings

**Two candidate existing metamodels:**

- `fuhrmanator/FamixTypeScript` — v2.0.0 (2024-07-30), metamodel;
  paired with `fuhrmanator/FamixTypeScriptImporter` v3.1.0
  (2026-01-27, ts2famix). Actively maintained, targets Moose 11
  (Pharo 12+). Models: classes, interfaces, methods, functions,
  arrow functions, parameters, variables, imports, types with
  generics, decorators, modules/namespaces, JSX/TSX components.
  Does not model CSS or CSS Modules.
- `moosetechnology/FamixTypeScript` — **does not exist.** Zero
  hits under that org. `moosetechnology/Famix` is the core
  FamixNG infrastructure (real, active); not a TS-specific model.
- `VinceDeslo/FamixTypeScriptMoose` and `km229/mseTsGenerator` —
  demo / academic projects. Not candidates.

**Key separability finding.** Fuhrmanator's metamodel and its
importer are separate Metacello baselines. Loading the metamodel
without ts2famix works; populating it ourselves from LSP responses
is a legitimate reuse pattern.

**In-image state.** No Famix classes loaded in the dev image
today (confirmed: zero `Famix*` globals). FamixNG core is not
loaded either. Baseline expansion is a clean slate.

**Recommendation from the spike.** Start with a **minimal new
Famix-X metamodel** (10-14 entity classes) using FamixNG
generator traits. Cross-reference fuhrmanator's `.class.st` files
when naming traits so future interop is cheap. Two reasons to
avoid adopting fuhrmanator's model wholesale:

1. Its shape is optimised for ts2famix JSON population and carries
   entity assumptions (decorator-heavy, JSON-id-keyed) that don't
   match an LSP-derived pipeline.
2. Our novelty is the CSS-module bridge (TS `styles.X` references
   back to `.module.css` class definitions). No existing model
   covers this. We'd be grafting it on anyway.

## Key design decisions

**Entity inventory (first cut):**

Core TS/JS:
- `SmallChatFamixProject` — root container, workspace root.
- `SmallChatFamixModule` — a file.
- `SmallChatFamixClass`, `SmallChatFamixInterface`.
- `SmallChatFamixFunction`, `SmallChatFamixMethod` (same trait
  bundle; method adds `owningClass`).
- `SmallChatFamixParameter`.
- `SmallChatFamixTypeAlias` — type name declared, no structure.
- `SmallChatFamixImport` — resolved via LSP.
- `SmallChatFamixJSXComponent` — function or class with JSX return.

CSS Modules bridge (our novelty):
- `SmallChatFamixCSSModuleFile` — a `.module.css` file.
- `SmallChatFamixCSSClass` — a class selector inside one.
- `SmallChatFamixCSSClassReference` — a `styles.className` access
  in TS/JS, back-pointing to a `SmallChatFamixCSSClass` (resolved
  via the file's default import and class-name match).

Cross-cutting:
- `SmallChatFamixSourceAnchor` — file URI, byte range, LSP
  position range. Lives on every entity.

That's 13 classes. Adjustable as we learn.

**No type modelling.** Types are named (as `TypeAlias`) but not
decomposed. Generics, unions, intersections, conditional types,
template literal types — skipped. If a refactoring needs to
reason about a type's shape, it asks LSP.

**LSP-derived population pipeline.** Per TS/JS file:

1. `didOpen` the file (or make sure it's open).
2. Fetch `textDocument/documentSymbol` (hierarchical). Map each
   returned `DocumentSymbol` to a Famix entity by kind.
3. For imports, walk the AST via tree-sitter (LSP's symbol list
   doesn't enumerate imports as symbols). Resolve each import
   path via `textDocument/definition` on the import specifier.
4. For JSX component detection, inspect the tree-sitter AST for
   a `jsx_element` return from a function / method.

Per `.module.css` file:

5. Parse with tree-sitter-css. Walk `class_selector` nodes; emit
   a `SmallChatFamixCSSClass` per unique class name.

Cross-language link:

6. For each TS/JS file that has `import styles from
   '<something>.module.css'`, record the module-file pairing.
   Scan `styles.<name>` member-expressions via tree-sitter, emit
   `SmallChatFamixCSSClassReference` pointing to the matched
   `SmallChatFamixCSSClass`. Unresolved references (typos,
   dynamic access) are recorded with a nil target and a
   diagnostic-grade flag for later surfacing.

**Regeneration, not mutation.** On any `WorkspaceEdit`
application (plan 04), affected files are re-imported
end-to-end. The model is cheap enough to rebuild per file, and
mutation keeps biting us in similar codebases (state drifts,
references go stale). Regenerate, don't patch.

**Population cost control.** Don't regenerate the full project on
every edit. The importer takes a set of changed URIs and re-imports
only those files plus any `.module.css` file whose class set might
have changed (if a CSS file changed, TS files that import it are
re-linked but not re-imported).

**Persistent index not required.** The model lives in memory.
For large projects this may not scale, but solving it now is
premature — measure first.

## Feasibility spike (#5) status

The spike question was: "can `documentSymbol` + `workspace/symbol`
+ tree-sitter answer `find call sites of function F` and `list
imports of module M`?"

**"Find call sites"** = `textDocument/references` with
`context.includeDeclaration: false`. This is LSP, not
documentSymbol, but it is a first-class LSP query and tsgo
supports it (spike 1). Famix doesn't need to answer it; the
command layer routes to LSP directly given a Famix entity's
position.

**"List imports of M"** = walk the AST via tree-sitter, collect
`import_statement` nodes, resolve each one via
`textDocument/definition` on the specifier. The Famix `Import`
entity is the cache of that resolution, so repeat queries don't
re-call the LSP.

**Feasibility is not in doubt.** The real risk is population
cost for large projects and tsgo's `references` latency. These
are tunable, not architectural. Actual prototyping against a real
TS project (small, ~50 files) remains the first spike of the
implementation pass — not a planning gate.

## Dependencies

- **Plan 01 (LSP client)** — population pipeline calls LSP.
- **Plan 02 (tree-sitter)** — ranges, CSS parsing, JSX detection.
- **FamixNG core / `moosetechnology/Famix`** — generator traits
  for the metamodel. Load into `dev` group of baseline.
- **Plan 04 (refactoring)** — consumes the model.

## Open questions

- Exact FamixNG version and Pharo-13 compatibility. FamixNG moves
  with Moose; we should pin a known-good Moose release and record
  the pin in baseline. Resolve during the "load FamixNG" milestone.
- Do we want a workspace/symbol-based whole-project index up
  front, or lazy file-by-file import? `workspace/symbol` is
  project-wide and fast once tsgo has indexed; use it once for
  initial fill, then per-file `documentSymbol` for refresh.
- JSX component detection heuristics. A function returning JSX is
  the easy case; `forwardRef`, `memo`, and `styled(Button)` are
  the tricky ones. Start with the easy case, collect gaps.
- How to model re-exports (`export { Foo } from './bar'`). An
  `Import` entity that is also exported, or a separate
  `ReExport`? Decide when the first refactoring needs it.
- Dynamic imports, `require()`, `import()` expressions. Tree-
  sitter sees them; LSP resolves them as best-effort. Flag
  unresolved as such; don't pretend certainty.
- Do we persist the model across sessions? Not for now. If
  startup cost becomes annoying, serialize to STON on workspace
  close, reload on open.

## Milestones

1. Pick and pin a FamixNG / Moose version. Load into the `dev`
   baseline. Verify FamixNG generator traits work.
2. Generate a minimal metamodel (the 13 classes above) using
   FamixNG generator DSL. Produce one or two serialisation tests
   (STON round-trip) as sanity.
3. LSP-backed importer: `documentSymbol` -> class/function/method
   entities for a single file. No imports, no CSS yet.
4. Imports: tree-sitter walk + LSP definition resolution. Cache
   hit/miss metrics for observability.
5. CSS-module importer: parse `.module.css`, emit `CSSClass`
   entities.
6. CSS-module bridge: TS `styles.X` references linked back to
   CSS classes.
7. Regeneration API: "these URIs changed, refresh the model".
   Integration with plan 04's WorkspaceEdit apply path.

## Non-goals

- No type modelling, no type resolution.
- No flow / control-flow / call-graph modelling beyond what LSP
  gives us on demand.
- No Moose visualisation plumbing in this phase (the Moose stack
  is welcome to consume the model, but we don't build dashboards).
- No reuse of fuhrmanator's `FamixTypeScriptImporter` /
  ts2famix. Our importer is the LSP.
- No persistence across sessions (yet).
