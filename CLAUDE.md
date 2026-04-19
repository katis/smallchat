# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project goal

smallchat is a self-modifying agent that lives inside a Pharo 13 Smalltalk
image. It connects to a local LM Studio server (target model:
`qwen3.6-35b-a3b`) and exposes Smalltalk-native tool calling so the agent
can inspect and rewrite classes/methods in the same image it is running
in. The UI, agent loop, and model client are all in-image; `src/` is just
the on-disk source of truth.

## Development methodology: Red-Green TDD

All behaviour changes in this repo follow strict Red-Green-Refactor TDD.
No production code is written without a failing test that demands it.

1. **Red** — write exactly one failing test in the matching
   `SmallChat-Tests` package that describes the next slice of behaviour.
   Run `just test` and confirm it fails for the *right* reason (missing
   method / wrong result, not a syntax error or missing class you forgot
   to create). Do not write more of the test than is needed to fail.
2. **Green** — write the smallest amount of production code in the
   `SmallChat` package (or a sibling) that makes the failing test pass.
   "Smallest" means smallest, even if it looks silly (return a constant,
   hard-code the expected value). Run `just test` and confirm the suite
   is green before touching anything else.
3. **Refactor** — with the suite green, clean up duplication, rename,
   extract, or restructure. Run `just test` after each refactor step.
   Never mix refactor edits with behaviour changes; if a refactor
   requires a new test, stop and go back to Red.

Rules that follow from this:

- One failing test at a time. Never leave the suite with more than one
  red test.
- Never commit on Red. Commits — and therefore any Iceberg
  "Commit…" action — happen only when `just test` is green.
- `just lint` must also be clean before committing; treat Critiques
  findings like compile errors.
- When a bug is reported, reproduce it as a failing test *first*, then
  fix it. The regression test is the deliverable, not the patch.
- If you are tempted to write production code "to see if it works",
  that's a signal the next test hasn't been written yet. Write the test.

## Commands

All common tasks go through `just` (see `justfile`):

```sh
just install    # first-time bootstrap (./install.sh)
just rebuild    # wipe pharo/Pharo.image and reload the baseline from src/
just run        # open the GUI
just test       # headless SUnit over every SmallChat-* package
just lint       # headless Critiques (ReCriticEngine) over every SmallChat-* package
just clean      # drop the working image, keep VM + seed
just build      # unimplemented on purpose — Pharo has no separate build step
```

Test runner uses Pharo's built-in `test` CLI handler with
`--fail-on-failure --fail-on-error`, so any red test fails the recipe.
Lint runs `lib/lint.st`, which iterates every `SmallChat*` package
through `ReCriticEngine critiquesOf:` and calls `Smalltalk exitFailure`
(exit 1) if anything is flagged.

Both recipes execute against the already-materialised image, so if you
add a new package to the baseline you must `just rebuild` before `just
test` / `just lint` will see it.

## How the repo maps to the image

The source of truth is the **Tonel tree under `src/`**, not the image.
`pharo/` is gitignored and per-clone.

1. `install.sh` downloads the VM into `pharo/vm/`, copies the seed image
   into `pharo/seed/`, materialises a working `pharo/Pharo.image`, then
   runs `lib/load-packages.st` headlessly with `SMALLCHAT_REPO` set to
   the repo root.
2. `lib/load-packages.st` (a) registers the clone as an Iceberg
   repository with `subdirectory: 'src'`, (b) Metacello-loads
   `BaselineOfSmallChat` from `tonel://<repo>/src`, (c) closes the
   Welcome window so the first GUI click doesn't beachball.
3. Thereafter, you edit classes **in-image** via the Pharo tools. Iceberg
   tracks the `SmallChat-*` packages against this repo; commits and
   pushes happen through the Iceberg UI, which rewrites the Tonel files
   under `src/`.

Consequence: do not hand-edit `.class.st` / `.package.st` files under
`src/` unless you know what you're doing. Make changes in the image and
let Iceberg serialise them. If the image diverges badly, delete
`pharo/Pharo.image` + `pharo/Pharo.changes` and re-run `./install.sh`;
the VM and seed are preserved.

## Baseline layout

- `BaselineOfSmallChat` — declares the packages the image loads and the
  `default` / `core` / `tests` groups. Add new packages here, not in
  `load-packages.st`.
- `SmallChat` package — application code. `SmallChatApp` is currently a
  placeholder with only a `version` class-side method; the agent loop,
  LM Studio client, and chat UI will hang off it.
- `SmallChat-Tests` package — SUnit test cases. `just test` matches
  packages against the regex `SmallChat.*`, so any new test package
  whose name starts with `SmallChat-` will be picked up automatically.

## Pharo/Iceberg gotchas

- `install.sh` is idempotent. The VM and seed are only downloaded if
  missing; the working image is only rebuilt if absent or `--rebuild` is
  passed.
- The Iceberg registration in `load-packages.st` is wrapped in `on:do:`
  because scripting selectors vary across Iceberg versions — a failure
  there is non-fatal and the Metacello load still runs; register the
  clone manually via "Import from existing clone" if it does fail.
- Headless loads must use `--save` (as in `install.sh`); otherwise the
  loaded baseline is discarded when the VM exits.
