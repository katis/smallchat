# smallchat

A Pharo-based agentic tool that runs against a local model. smallchat runs
as a standalone Pharo image with its own UI; the agent loop is driven
from inside the image.

The development environment is itself an in-image MCP server: Claude
Code talks to a long-lived Pharo image, compiles code via `evaluate`,
runs SUnit via `run_tests`, and commits via Iceberg's API. The on-disk
Tonel tree under `src/` is the source of truth; Iceberg writes it back
on every commit.

## Layout

```
smallchat/
├── .mcp.json                project-scoped MCP registration for Claude Code
├── bin/
│   ├── smallchat            GUI launcher (verifier / read-only inspection)
│   └── smallchat-mcp        MCP launcher (Claude Code -> long-lived dev image)
├── install.sh               one-time bootstrap (downloads VM, materialises image)
├── justfile                 task runner; see `just --list`
├── lib/
│   ├── load-packages.st     headless loader; honours SMALLCHAT_MCP_MODE
│   ├── iceberg-setup.st     dev-image only: registers smallchat repo with Iceberg
│   └── lint.st              headless ReCriticEngine runner used by `just lint`
├── pharo/                   VM + working image live here (gitignored)
└── src/                     Tonel source tree (source of truth)
    ├── BaselineOfSmallChat/
    ├── SmallChat/
    ├── SmallChat-Tests/
    └── SmallChat-MCP/       MCP server (loaded only in the dev image)
```

## First-time setup

```sh
git clone git@github.com:katis/smallchat.git
cd smallchat
./install.sh                    # verifier image (just test / just lint)
./install.sh --mcp --rebuild    # dev image (Claude Code via MCP)
```

The verifier image is what `just test` and `just lint` rebuild on every
run. It loads only `SmallChat` + `SmallChat-Tests`, no MCP, no Iceberg.

The dev image additionally loads `SmallChat-MCP` and registers the
working tree with Iceberg. It's the long-lived image Claude Code talks
to.

## Daily use

```sh
just mcp                 # launch the dev image; Claude Code attaches via .mcp.json
just test                # CI-equivalent: rebuild verifier image, run SUnit headlessly
just lint                # CI-equivalent: rebuild verifier image, run Critiques headlessly
just rebuild-mcp         # wipe and re-materialise the dev image
just rebuild             # wipe and re-materialise the verifier image
```

Inside Claude Code, use the `smallchat` MCP server's tools — `evaluate`,
`run_tests`, `lint`, `status`, `commit` — to compose changes against
the live dev image. Every commit goes through Iceberg and writes Tonel
files back to `src/` before creating the git commit. Run `just test`
from a shell before committing to confirm the change also passes a
fresh rebuild.

See `CLAUDE.md` for the development methodology (Red-Green TDD), the
MCP tool surface, hard constraints inherited from akkuna, and Iceberg
gotchas under Pharo 13.

## Rebuilding from scratch

If the image gets into a bad state, blow it away:

```sh
just clean
./install.sh --mcp --rebuild   # or `./install.sh` for the verifier image
```

If the VM itself is corrupted, delete `pharo/` entirely and re-run
`./install.sh` — the download step repopulates it.

## Status

Skeletal. `SmallChatApp` has a `version` and a `tagline` accessor so
the baseline has something non-empty to load. The agent loop,
local-model client, and chat UI will hang off it as they're built.
