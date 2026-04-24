# Architecture overview

smallchat is an in-image Pharo 13 agent tool. Agents address code
entities semantically (by name and kind) through a Smalltalk
refactoring API, not by byte offsets in files. The same API drives
two transports today (MCP server and a native in-image chat
harness) and will reduce to one when the native surface matures.

The central architectural bet: **tsgo LSP is the semantic truth
source, a minimal Famix model is the structural aggregation layer,
and a Smalltalk command API composes the two.** Agents see
commands, not edits.

## Layers

```
  agent transports   MCP server           native chat harness
                         \                 /
                          v               v
  capability surface     SmallChat capability registry
                                 |
                                 v
  refactoring API     command objects (RenameSymbol,
                       ExtractFunction, MoveToFile,
                       RenameCSSClass, ReRenameClass, ...)
                                 |
                      +----------+----------+
                      v                     v
  structural model   Famix-X              Pharo Smalltalk
                     (TS/JS + CSS-M)      (RBModel, system)
                      |     |
                      |     +-- CSS module bridge (tree-sitter only)
                      v
  semantic backends  tsgo LSP             tree-sitter
                     (definition,          (ranges, CSS, TSX,
                      references, rename,   fallback parsing)
                      codeAction, ...)
                      |
                      v
                     external subprocess
```

### Parsing and semantics (external, wrapped)

tsgo handles TypeScript and JavaScript semantics: definitions,
references, rename, document and workspace symbols, diagnostics,
and a growing set of `codeAction` refactorings. We keep tsgo at
arm's length behind a Pharo LSP client we build; the subprocess is
launched per workspace and kept warm.

Tree-sitter, via the existing `Evref-BL/Pharo-Tree-Sitter` binding,
handles everything LSP can't or shouldn't: syntactic ranges that
LSP's symbol APIs don't expose cleanly, CSS parsing for `.module.css`
files, and a fallback when the LSP subprocess is down or lagging.

### Famix model (derived, minimal)

A small Famix-X metamodel (~10-14 entity classes): module, class,
interface, function, method, parameter, import, type alias, JSX
component, CSS module file, CSS module class, CSS class reference
from TS/JS, source range, project. Entities are populated from LSP
responses plus tree-sitter ranges; the model is regenerated per-file
after a `WorkspaceEdit` lands, never mutated in place.

Famix does not try to own types, generics, or cross-file symbol
resolution. Those live in the LSP and are queried on demand. The
model's job is structural aggregation: "what modules exist", "what
top-level names does this file export", "which CSS classes in this
`.module.css` are referenced from which TS files".

### Refactoring API (the interesting layer)

Smalltalk command objects per refactoring: `RenameSymbol`,
`ExtractFunction`, `MoveToFile`, `RenameCSSClass`, and so on. Each
exposes `#preview` (describe the change), `#apply` (execute),
`#rollback` (undo a failed apply), `#verify` (diagnostics delta).

Commands resolve Famix entity references to file positions and
route to LSP for single-language refactorings; for cross-language
refactorings (CSS class renamed across `.module.css` and its
TS consumers), commands compose LSP edits with tree-sitter-derived
edits into a single `WorkspaceEdit` that applies atomically.

Pharo's own `RBRefactoring` / `ReRefactoring` family is exposed
through the same command vocabulary so that Smalltalk and TS/JS
refactorings look identical to agents.

### Agent tool surface (unified)

One capability registry, two transport bindings. A capability
declares name, description, schema, and handler — transport-free.
The MCP binding adapts capabilities to the `tools/call` surface;
the native harness binding adapts them to OpenAI-compatible
function-call payloads. New capabilities are added once and appear
on both transports.

Capabilities span: Smalltalk refactorings, TS/JS/CSS refactorings,
Famix project queries, LSP pass-through (hover, diagnostics,
definition), SUnit tests, linting, commits, and the existing
debug-session family.

## Non-goals for this architecture

- No novel refactorings invented up front. Expose what LSP gives
  us; invent later if gaps appear.
- No type modelling in Famix. Ask LSP at query time.
- No Smalltalk-side TS/JS parser. Use tsgo or tree-sitter.
- No GUI; the transport is the UI.
- No MCP retirement in this phase. Unify surfaces; retire the MCP
  binding later when the native harness subsumes its use case.
