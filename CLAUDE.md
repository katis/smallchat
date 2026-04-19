# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project goal

smallchat is a self-modifying agent that lives inside a Pharo 13 Smalltalk
image. It connects to a local LM Studio server (target model:
`qwen3.6-35b-a3b`) and exposes Smalltalk-native tool calling so the agent
can inspect and rewrite classes/methods in the same image it is running
in. The UI, agent loop, and model client are all in-image; `src/` is the
on-disk source of truth.

## Dev vs runtime image

Two distinct contexts, which must not be conflated:

- **Development image** (this workflow): a disposable Pharo image used
  only for running tests and the linter. Rebuilt from `src/` via
  Metacello on every `just test` / `just lint`. Claude edits Tonel files
  directly on disk and commits via Git. **Iceberg is not configured in
  the dev image.** Nothing you do inside the dev image survives the next
  test run.
- **Distributable image** (end-user artifact, not yet built): the
  shipped Pharo image has Iceberg configured and ready, because
  in-image browsing, diffing, and managing agent-generated code is a
  product feature of smallchat. That setup lives in a build step that
  does not exist yet — it will take the `just build` slot when it
  arrives.

Consequence for Claude: everything below about the development loop is
about the dev image. Iceberg and the distributable image are out of
scope unless a task explicitly asks for them.

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
- Never commit on Red. `git commit` happens only when `just test` is
  green.
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
just build      # reserved for the future distributable-image recipe (not implemented)
```

Test runner uses Pharo's built-in `test` CLI handler with
`--fail-on-failure --fail-on-error`, so any red test fails the recipe.
Lint runs `lib/lint.st`, which iterates every `SmallChat*` package
through `ReCriticEngine critiquesOf:` and calls `Smalltalk exitFailure`
(exit 1) if anything is flagged.

Both `just test` and `just lint` depend on `rebuild`, so the image
always reflects the current `src/` tree — there is no separate "remember
to rebuild" step. The dev image is wiped and re-materialised from the
seed before every test or lint run.

## How the repo maps to the image

The source of truth is the **Tonel tree under `src/`**. The dev image
under `pharo/` is a disposable build artifact and is gitignored.

1. Edit Tonel files directly under `src/`. This includes `.class.st`,
   `.package.st`, and baseline files — hand-edits are the primary
   workflow.
2. Run `just test`. The recipe first runs `rebuild`, which invokes
   `install.sh --rebuild`: wipe `pharo/Pharo.image`, copy the seed into
   place, then run `lib/load-packages.st` headlessly. That loader
   Metacello-loads `BaselineOfSmallChat` from `tonel://<repo>/src` and
   closes the Welcome window. Once the load is saved, the SUnit runner
   executes against the fresh image.
3. Commit via plain `git add` / `git commit`. There is no Iceberg step
   in the dev loop.

Consequence: **never edit inside the dev image and expect it to
persist.** Every `just test` replaces the image wholesale. If you need
to inspect something interactively via `just run`, treat that session as
read-only — any change that matters must go back into `src/`.

If the VM or seed ever gets corrupted, delete `pharo/` entirely and
re-run `./install.sh`; the download step repopulates both.

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

## Pharo gotchas

- `install.sh` is idempotent. The VM and seed are only downloaded if
  missing; the working image is only rebuilt if absent or `--rebuild` is
  passed. `just test` and `just lint` both trigger `--rebuild`.
- Headless loads must use `--save` (as in `install.sh`); otherwise the
  loaded baseline is discarded when the VM exits.
- The dev image is disposable. Nothing inside it survives the next
  `just test` run — if a change must persist, it belongs in `src/`.
