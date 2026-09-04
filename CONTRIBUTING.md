# Contributing to Verdant

Verdant is maintained on a best-effort basis. Pull requests are welcome, and so are forks. This page is what you need to know before touching the code.

## Run the checks

You need Lua on your PATH (5.1 or 5.4; CI uses 5.4). Everything runs offline, without the game.

```
bash test/gate.sh
```

That is the merge gate. It parses every file, runs the mock-ESO harness in both DEBUG shapes, the SimLab scenarios, the layout audit and the trace replays. A pull request is expected to pass it.

Useful on their own:

```
lua test/harness/run.lua .        harness with DEBUG on
lua test/harness/run.lua . 0      harness in release shape
lua test/simlab/run.lua . --svg   scenarios plus SVG snapshots of every window
lua test/simlab/audit.lua .       layout audit over the snapshots
```

The harness cannot see everything: text metrics are wider than the game's, and UI scale and the real mouse are out of reach. Anything that touches layout or input still deserves a `/reloadui` in game.

## How the code is laid out

- `zenimax/` is the only place that talks to the game API. Everything else goes through it.
- `pipeline/` turns combat events into numbers, `core/` keeps the state, `ui/` draws it.
- One global, `Verdant`. Every file starts with `Verdant = Verdant or {}`.
- The per-sample path allocates nothing. `zero_alloc` in the harness is the tripwire; keep it green.
- No code comments. The names and the tests carry the explanation.
- `docs/ARCHITECTURE.md` and `docs/SIMLAB.md` go deeper.

When an API question comes up, the ZeniMax UI source at github.com/esoui/esoui is the authority, then the ESOUI wiki.

## Branches and pull requests

Work happens on `develop`. Branch from it, open the pull request against it. Keep the description short: what changed and why, in a few lines. Add a line to `CHANGELOG.md` under `Unreleased`.

## Cutting a release

1. Bump the version in three places, together: `## Version:` and `## AddOnVersion:` (by at least 1) in `Verdant.txt`, and `VERSION` in `core/constants.lua`. Check `## APIVersion:` against `/script d(GetAPIVersion())` in game; two values at most.
2. Rename `## [Unreleased]` in `CHANGELOG.md` to `## [x.y.z] - date`.
3. Gate clean, merge to `develop`.
4. Tag `vx.y.z` and push the tag. The Release workflow builds the zip, checks it, and attaches it to a GitHub Release. Do not zip by hand: the workflow strips hidden files and dev folders and verifies the textures.
5. Upload that zip to ESOUI by hand. The listing keeps the AI-assistance line at the top of the description; the changelog goes in the Change Log tab; inline images are at most 600 px wide and flattened on `#2a2a2a`, served from `docs/assets/esoui/` in this repo.

## When a game patch lands

Usually nothing breaks. Bump `## APIVersion:`, run the gate, load it in game once, release. If an API call changed, `zenimax/api.lua` is where the fix goes.
