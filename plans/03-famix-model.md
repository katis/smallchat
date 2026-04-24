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

## Spike S4 findings (2026-04-24)

Pinned `moosetechnology/Famix` v1.2.0 (commit
`e841ebfd10bb59a6b94e0d31e759486bf3cea911`, dated 2026-02-19) in
`BaselineOfSmallChat`'s `dev` group, loading only the `Basic`
baseline group. `just rebuild-mcp` against this pin completes
cleanly in ~48 s on Pharo 13 and delivers a working
`FamixMetamodelGenerator` DSL.

- **Repo choice: Famix, not full Moose.** `moosetechnology/Famix`
  carries the FamixNG generator DSL (`Famix-MetamodelGeneration`,
  `Famix-MetamodelBuilder-Core`, `Moose-Core-Generator`,
  `Famix-BasicInfrastructure`) without the visualisation stack
  (Roassal / Mondrian). The `moosetechnology/Moose` superproject
  pulls everything Famix does plus visualisation — rejected
  because plan 03 §Non-goals already excludes dashboards. We can
  always add the heavier baseline later if a refactoring ever
  wants to render a model.
- **Load group: `Basic`.** Baseline groups in `BaselineOfFamix`
  (v1.2.0): `Core`, `Minimal`, `Basic`, `BasicTraits`,
  `EntitiesJava`, `ModelJava`, `EntitiesSmalltalk`,
  `ModelSmalltalk`, `Importers`, `TestModels`, `Tests`,
  `TestsResources`. `Basic` is the narrowest group that contains
  `Famix-MetamodelGeneration` and its builder — exactly what M2
  needs. `BasicTraits` adds `Famix-Traits` (which carries
  `FamixTFileAnchor` / `FamixTNamedEntity`); not loaded by
  `Basic`, but our metamodel will likely need it — defer to M2
  and widen the `loads:` then.
- **Transitive deps that landed.** `Fame@development`
  (`1c6ac4929707...`), `DeepTraverser v1.0.2`, `CollectionExtensions
  v1.0.1`, `SingularizePluralize v1.1`, plus the Fame test chain
  (Hashtable, StateSpecs, Ghost, Mocketry, Iterators, TreeQuery).
  No version conflict with our existing `NeoJSON@master` or
  `PharoBackwardCompatibility v1.14.0` (both already pulled by
  TreeSitter). 44 `Famix*`/`Moose*` classes in the image after
  rebuild.
- **Generator DSL confirmed working.** Subclass
  `FamixMetamodelGenerator`, declare entity-name iVars via
  `addInstVarNamed:`, override class-side `packageName` and
  `prefix` (prefix must be a valid Pharo identifier — using the
  dashed package name breaks helper-class creation with
  `InvalidGlobalName`). `defineClasses` uses
  `builder newClassNamed: #EntityName`; `defineHierarchy` uses
  `<iVar> --|> #TTraitName` (the trait must be resolvable in the
  current metamodel or a loaded submetamodel — referring to
  `#TNamedEntity` without the `Famix-Traits` submetamodel loaded
  raises `FamixMetamodelGeneratorUnknownTrait`). A minimal
  generator with one `newClassNamed: #DemoModule` emitted four
  artifacts: the entity class, a metamodel-specific `Entity`
  root (subclass of `MooseEntity`), a `Model` root (subclass of
  `MooseModel` + `TEntityCreator` trait), and the trait itself.
  `MooseEntity` / `MooseModel` globals are present.
- **Known upstream rough edges noted for M2.**
  - `TSFASTBuilder>>createMetamodelGeneratorClass` in TreeSitter-
    FAST-Utils raises a `NewUndeclaredWarning` at load because
    TreeSitter loads before Famix. `FamixMetamodelGenerator` is
    present at runtime, so the late-binding path should work; if
    it bites, recompile the method after Famix loads.
  - `MooseModel>>detectEncodingOfAllFileAnchors` references
    `FamixTFileAnchor` which isn't in the `Basic` load. Our
    importer never walks that path; if it does later, widen to
    `loads: #('Basic' 'BasicTraits')`.
- **Pharo 13 ergonomics.** `'SmallChat-Scratch' asPackage` raises
  `NotFound` in Pharo 13 when the package is absent; use
  `PackageOrganizer default ensurePackage: 'X'` first. The
  4-keyword `Object subclass:instanceVariableNames:...:package:`
  is already known-gone per CLAUDE.md; use `addInstVarNamed:`
  after `subclass:`.

## Spike S6 findings (2026-04-24)

Drove an end-to-end LSP -> Famix-shape dry-run against
`/Users/katis/code/juba` (SolidJS 1.9 + TanStack Start + Tailwind
v4, no CSS Modules). The CSS-Modules bridge ran separately against
a 3-file synthetic fixture at `lib/fixtures/ts-css-small/`. Probe
was scripted entirely via `evaluate` in a throwaway
`SmallChat-Scratch-S6` package (torn down after the run — M2 ships
the real `SmallChat-TreeSitter` / `SmallChat-LSP` surface).
Feasibility confirmed; seven concrete adjustments fall out.

- **Working set.** 141 files after filtering (`61 .ts` +
  `80 .tsx`) from 169 total; skipped 2 `.d.ts`, 1 `.gen.ts`, 14
  `.test.ts`, 11 `.test.tsx`. Roughly 3x the S6 spec's "~50 files"
  target — doubled as a population stress test.
- **tsgo handshake.** 22 ms from `initialize` send to response on
  a warm juba project (tsgo already indexed). Direct binary path
  `node_modules/.pnpm/@typescript+native-preview-darwin-arm64@.../
  lib/tsgo` per S1 guidance; `npx` wrapper still breaks stdin.
- **Reader must answer server-initiated requests, not just
  notifications.** tsgo sends `client/registerCapability` as a
  JSON-RPC request (has `id` *and* `method`) during startup and
  **blocks all further server work** until the client responds. A
  naive "anything with `method` is a notification" classifier
  deadlocks everything — our first 5 `textDocument/documentSymbol`
  calls all timed out at 15 s for this reason. **Plan 01
  adjustment:** the framing/correlation layer must distinguish
  (id + method) = server request, (method, no id) = notification,
  (id, no method) = response. Auto-reply to unknown server
  requests with an empty success `{ result: null }` so the reader
  never wedges. Applies to `workspace/configuration`,
  `window/workDoneProgress/create`, and `window/showMessageRequest`
  as well.
- **tsgo log volume is extreme.** 465 `window/logMessage`
  notifications across the 605 LSP ops we issued (~3 per op).
  Nothing else (no `publishDiagnostics` after the first batch, no
  `$/progress`). **Plan 01 adjustment:** drop `window/logMessage`
  at the transport layer unless a debug flag is set — do not
  STONJSON-parse them, do not cons a Dictionary. A 1-line
  substring match (`"method":"window/logMessage"`) before parse
  saves 465 allocations per project open.
- **documentSymbol latency and shape.** 141 files in 1.8 s total;
  p50 13 ms, p95 22 ms, p99 37 ms, max 40 ms. Zero failed files.
  Hierarchical `SymbolKind` distribution across the project:

    Variable 2061 | Property 1415 | Function 754 | Method 141
    Class 82     | Interface 45  | Constructor 6 | Namespace 1

  The 13-class inventory maps 6 of these 8 kinds cleanly
  (`Class` / `Interface` / `Function` / `Method` + `Constructor`
  -> a method-with-flag, `Namespace` -> deferred / rare). **Two
  gaps to decide in M2:**
  - `Property` (1415). Fires on class fields, interface members,
    object-literal keys, type-literal members. Fold into a new
    `SmallChatFamixField` entity (or attach as trait on
    `Class` / `Interface`). 14-class inventory, not 13.
  - `Variable` (2061). `documentSymbol` lumps top-level
    `const X = 5`, `const X = (...) => <jsx/>`, `let state`, and
    every `for (const x of ...)` binding under one kind. Need a
    tree-sitter post-filter on each Variable to split
    `JSXComponent` from `ModuleConstant` from
    `non-interesting-scoped-binding` — the Famix entity count
    for Variables is **not** 2061 once filtered; the 37 const-
    arrow components we detected independently are the real
    signal (see JSX row). **Recommendation:** don't create Famix
    entities from `SymbolKind=Variable`; use tree-sitter's top-
    level `variable_declarator` walk as the authoritative source
    for JSXComponent + a new (optional) `ModuleConstant` entity.
- **Import resolution via `textDocument/definition`.** 464 imports
  across 125 files resolved in 5.9 s; p50 12 ms, p95 16 ms, p99
  18 ms, max 49 ms. Classification:
  - `src/`-local: 248 (53%) — **100% of these used the `~/*`
    tsconfig-paths alias; juba has zero relative `./…` imports
    between src files.** tsgo resolves aliases via tsconfig
    transparently; plan 03 assumption holds.
  - `node_modules/`: 193 (42%).
  - Other: 23 (5%) — all `cloudflare:workers` virtual-module
    specifiers, resolved to `worker-configuration.d.ts` at the
    project root (outside `src/`). Legitimate; importer should
    add a fourth classification bucket `virtual-module` and not
    treat project-root resolutions as errors.
  - Unresolved: 0.
- **`.ts` parses cleanly under the TSX grammar.** Confirmed on an
  18 KB `.ts` file (`ChatRoom.ts`): 2605 nodes, zero ERROR nodes.
  **Plan 02 resolution:** close the open question "use TSX for
  `.jsx`?" — the TSX grammar is a strict superset of plain TS in
  practice, so `.ts` / `.tsx` can share one parser instance. One
  fewer grammar singleton to wire up in M2.
- **JSX-component detection (Solid).** 91 components across 76 of
  80 TSX files (95%), split 54 function declarations / 37 const-
  arrow `variable_declarator`s / 0 method-returns-jsx. The
  "function or const-arrow returning `jsx_element` /
  `jsx_self_closing_element` / `jsx_fragment`" heuristic works
  for plain Solid as-is — Solid's `<For>` / `<Show>` / `<Dynamic>`
  tags parse as ordinary JSX elements, no framework-specific
  AST. **Gap: TanStack Start route files** (3 files in juba)
  declare components nested in a call argument:

    export const Route = createFileRoute("/_authed")({
      component: () => <Outlet />,  // missed
    });

  The arrow lives under `call_expression > arguments > object >
  pair > arrow_function`, not at the top level. Widen M3's
  component heuristic to also walk `pair` / `property` values
  whose key is `component` and whose value is an arrow returning
  JSX. One more file (`router.tsx`) has no JSX at all and is
  correctly skipped — the factory `getRouter()` returns a router
  config, not an element.
- **CSS-Modules bridge (fixture).** 3 `CSSClass` from
  `Button.module.css` (`primary`, `secondary`, `disabled`); 2
  resolved `CSSClassReference` from `Button.tsx` and 1
  unresolved-with-flag from `Bad.tsx`. Exact expected outcome.
  Implementation walks `class_selector > class_name` nodes in
  tree-sitter-css, matches the default-import binding name
  (`styles`) against tree-sitter-tsx `member_expression` nodes
  with `object` = binding name. Works for typo detection
  (`styles.doesNotExist`) by design.
- **Entity totals** (on the 14-class inventory, Property + the
  13 above): Project 1, Module 141, Class 82, Interface 45,
  Function 754, Method 147, Property 1415, Import 464,
  JSXComponent 91, CSSModuleFile 1, CSSClass 3,
  CSSClassReference 3 — **5148 entities** across 141 files +
  fixture. Average ~36 entities/file. Pharo VM RSS during the
  probe: 289 MB. tsgo RSS: 260 MB (independent).
- **End-to-end wall time (single-threaded, cold juba project).**
  ~7.8 s total: handshake 0.02 s + documentSymbol sweep 1.8 s +
  definition sweep 5.9 s + tree-sitter JSX walk ~0.05 s + CSS
  fixture ~0.01 s. Dominant cost is definition-per-import. Two
  tunable levers for M3:
  - Pipeline definitions: fan out N requests concurrently
    against one tsgo process (LSP supports concurrent
    outstanding requests by id). A 4-way pipeline should cut
    the 5.9 s definition phase to ~1.5–2 s.
  - Cache Import entities across regenerations — only re-
    resolve on file change, not on every model refresh.
- **Pre-implementation-spike decisions unlocked.**
  - Feasibility confirmed (plan 03 §Feasibility spike status):
    `documentSymbol` + `textDocument/definition` + tree-sitter
    walk is sufficient for the v1 model.
  - §Open questions: workspace/symbol-based initial fill is
    **not** needed for ~150-file projects — per-file
    `documentSymbol` is fast enough. Revisit only if wall-time
    becomes an issue on larger codebases.
  - §Open questions: `Namespace` is real (1 occurrence in juba)
    but rare; skip in M2, add a `SmallChatFamixNamespace` entity
    only when a refactoring asks for it.
  - §Entity inventory: grow to 14 classes (add `Property` /
    `Field`). `Variable` stays un-entitied except for the JSX-
    returning subset routed to `JSXComponent`.
  - Plan 02 one-parser simplification: drop separate TS vs TSX
    grammar bindings in `SmallChat-TreeSitter`; ship only TSX +
    CSS + (later) JavaScript.
