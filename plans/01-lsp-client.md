# Plan 01 - LSP client

## Purpose and scope

Build a thin, general-purpose LSP client package inside the Pharo
image that smallchat uses to talk to tsgo (primary) and any
future language server (`typescript-language-server` fallback,
vscode-css-language-server if CSS diagnostics become useful).
Nothing in this package is tsgo-specific; tsgo-specific glue lives
one layer up.

The client manages: subprocess lifecycle, stdio `Content-Length`
framing, JSON-RPC 2.0 request/response correlation, notification
handling, capability negotiation, document-sync bookkeeping
(`didOpen`/`didChange`/`didClose`), partial-result and progress
tokens, and graceful shutdown.

Package name: `SmallChat-LSP` (to mirror the existing
`SmallChat-MCP` naming).

## Spike findings

**Nothing usable off the shelf in the Pharo ecosystem.** Two
adjacent projects exist but neither fits:

- `badetitou/Pharo-LanguageServer` is an LSP *server* for Pharo
  code (v5.2.0, 2026-04-13). Wrong direction. Its JSON-RPC framing
  code may be worth cribbing, but the package is entangled with
  its server role.
- `juliendelplanque/JRPC` is a generic JSON-RPC 2.0 library
  (HTTP + TCP transports only). No stdio, no `Content-Length`
  framing, no subprocess lifecycle. Maintenance quiet; Pharo-13
  compatibility unstated.

**tsgo LSP readiness (April 2026).** Viable as the primary
backend for navigation, rename, symbols, diagnostics, hover,
completion, signature help, and call hierarchy. Invocation:
`npx tsgo --lsp --stdio` (only stdio transport exported; `-pipe`
and `-socket` flags are defined but commented out in
`cmd/tsgo/lsp.go`). Known weak spot: `codeAction` `refactor.*`
kinds are narrower than `typescript-language-server`'s catalogue
today and moving weekly. Rename-file / update-imports on file move
is tracked but not landed (issue #2244, open).

**Implication.** The client must not hard-code tsgo's current
capability set. Capability discovery happens at `initialize`
handshake time, and the command-object layer above decides whether
to route a request to LSP or compose an edit from tree-sitter.

**In-image infrastructure.** `OSSubprocess` is **not** currently
loaded in the dev image (confirmed; only SDL2's `OSS*` prefixes
are present). `LibC` is loaded. We will need to add `OSSubprocess`
to the baseline (via Metacello) as a hard dependency of
`SmallChat-LSP`. `STONJSON` is loaded and usable for framing;
`NeoJSON` is not loaded and need not be.

## Key design decisions

**Subprocess lifecycle through OSSubprocess.** One subprocess per
language server per workspace root; we don't multiplex multiple
workspaces through one server process. tsgo is cheap to launch;
the warm-keeping benefit comes from keeping files open and project
state primed, not from amortising launch cost.

**Framing layer is transport-free.** A `SmallChatLSPStdioTransport`
reads and writes `Content-Length: N\r\n\r\n<bytes>` frames over the
subprocess pipes. A future `SmallChatLSPSocketTransport` (for
running servers out-of-process on another machine, or for tests
that stub the server) can slot in via the same interface. The
request-correlation class knows nothing about the transport.

**Request/response correlation.** Monotonic numeric ids; pending
requests stored in a `Dictionary id -> SmallChatLSPPendingRequest`;
`SmallChatLSPPendingRequest` wraps a `Semaphore` so the caller can
block on `#result` (or `#resultTimeout:`). Notifications dispatch
through a registered handler table. Use `on: Error do:` around the
reader loop; reader crashes must not leak and must notify pending
requests with a structured error.

**Document sync.** An `SmallChatLSPDocumentCache` keeps a
`uri -> version -> text` mapping; the client enforces that every
request that touches a document has seen a `didOpen` first. Edit
application (plan 04) invalidates and re-sends `didChange`.

**Capability negotiation.** The `initialize` response is parsed
into a `SmallChatLSPServerCapabilities` value object. The
command-object layer asks this object ("does the server support
rename?", "which codeAction kinds?") and routes accordingly.

**Reader on a dedicated Pharo process.** The reader forks like
`SmallChatMCPServer` already does for stdin. Notifications are
dispatched on the reader process; long-running tool code does its
work on the caller's process, blocking on the
`SmallChatLSPPendingRequest` semaphore. This mirrors the existing
MCP reader pattern, so the deadlock discipline carries over (never
open Morphic from the reader; wrap notifications with
`on: Notification do: [:n | n resume]`).

**Logging to file, not stdout.** Borrow `SmallChatMCPServer
logToFile:` style. The MCP reader cohabits stdout with MCP framing;
the LSP client must never corrupt stdout either.

## Dependencies

- **OSSubprocess** — added to the `dev` group in
  `BaselineOfSmallChat`. Keep `default` (verifier) LSP-free for
  now; LSP-dependent tests use a stub transport.
- **STONJSON** — already in base Pharo 13.
- **Plan 05 (capability registry)** — LSP pass-through capabilities
  (hover, diagnostics, definition) sit on top of this client.
- **Plan 03 (Famix model)** — population pipeline calls the LSP.
- **Plan 04 (refactoring API)** — command objects call the LSP.

## Open questions

- How do we bring up tsgo reliably as a subprocess on macOS? The
  smallchat MCP launcher already documents the `open -n` / BSD `nc`
  dance for the MCP image; tsgo is a normal `npx` child process,
  so OSSubprocess *should* be straightforward, but we should spike
  stdin/stdout EOF behaviour explicitly (tsgo writing large JSON
  payloads, backpressure, zombie child cleanup on image quit).
- Pharo 13 `OSSubprocess` stability. The library historically had
  zombie-reaping issues on macOS; need to verify current state and
  whether we need a periodic waitpid loop.
- Does tsgo honour `workspace/didChangeConfiguration` or require a
  restart when `tsconfig.json` changes? Test before relying.
- How do we surface tsgo stderr? Log it, but also bubble up fatal
  startup errors (missing `npx`, missing node_modules) as
  actionable errors to the agent, not as raw stderr dumps.
- Multi-workspace handling: for the self-hosting case (editing
  smallchat's own Pharo code alongside an external TS project), we
  might have zero or one TS server running — no real multi-server
  problem. But the long-term shape (agent working across several
  TS projects) needs a decision about workspace scoping; defer to
  plan 06.
- Do we want a per-request timeout default or per-request override?
  tsgo's `references` across a big codebase can be slow.

## Milestones

1. Subprocess transport + framing. Round-trip a hand-built
   `initialize` request against tsgo, read back the capabilities
   dictionary, return clean on shutdown.
2. Request correlation + notification dispatch. Able to call
   `textDocument/definition` on a fixture TS file and get a
   response.
3. Document sync (`didOpen`/`didChange`/`didClose`) with version
   bookkeeping, mediated by `SmallChatLSPDocumentCache`.
4. Capability discovery value object. Command objects can query
   "does server X support refactor.extract.function?".
5. Reader process hardening (graceful shutdown, crash recovery,
   stderr logging).
6. Stub transport for tests that want a fake server.

## Non-goals

- No LSP server implementation (that's `badetitou/Pharo-Language
  Server`'s job, separate project, not our problem).
- No transport multiplexing (one server process per workspace).
- No generic editor integration; the client exists to serve the
  refactoring API and capability registry, not to back a Pharo
  text editor.
- No LSP 3.18 streaming/work-done-progress UI surfacing in this
  phase — the client must parse these messages without crashing,
  but we don't expose progress events to agents yet.
