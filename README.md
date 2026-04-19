# smallchat

A Pharo-based agentic tool that runs against a local model. smallchat runs
as a standalone Pharo image with its own UI, and the agent loop is driven
from inside the image.

## Layout

```
smallchat/
├── bin/smallchat          GUI launcher for the materialised image
├── install.sh             one-time bootstrap (downloads VM, builds image)
├── lib/load-packages.st   headless loader: Iceberg-registers this clone + loads baseline
├── pharo/                 VM + working image live here (gitignored)
└── src/                   Tonel source tree (source of truth, managed by Iceberg)
    ├── BaselineOfSmallChat/
    └── SmallChat/
```

## First-time setup

```sh
git clone git@github.com:katis/smallchat.git
cd smallchat
./install.sh
```

`install.sh` downloads the Pharo 13 VM into `./pharo/vm/`, clones the seed
image into `./pharo/Pharo.image`, and runs `lib/load-packages.st` headlessly
to register the local clone as an Iceberg repository and load the
`BaselineOfSmallChat` baseline.

## Running

```sh
./bin/smallchat
```

Opens the Pharo GUI. Code in `SmallChat-*` packages is tracked by Iceberg
against this repo — edit in-image, commit via the Iceberg tool, push as
normal.

## Rebuilding

If the image gets into a bad state, blow it away and re-materialise:

```sh
rm -rf pharo/Pharo.image pharo/Pharo.changes
./install.sh
```

The downloaded VM is preserved; only the image is rebuilt.

## Status

No features yet — just the bootstrap skeleton. The plan is for the agent
loop, local-model client, and chat UI to live in `src/SmallChat/`.
