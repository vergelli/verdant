# Verdant quality guarantees

Everything a release claims about its numbers, executed and reported. The Robot Framework
suite in `qa/robot` runs the offline ESO harness, the SimLab oracle, the layout audit, the
trace replays and the live-versus-library comparison, and produces the human-readable
report (`log.html`, `report.html`) a release can link to. `test/gate.sh` stays the fast
pre-merge gate; Robot wraps the same checks.

A Lean layer for the mathematical model was tried in September 2026 and dropped: the
guarantee users care about, that the numbers match what the game did, can only be tested
against the game's own events, never proven from a model.

## Running the report

One command from the repo root, Windows or bash:

```
qa\gate.bat --open      (Windows; --open launches report.html when done)
bash qa/gate.sh          (Git Bash / Linux / macOS)
```

By hand:

```
python -m pip install -r qa/robot/requirements.txt
python -m robot --outputdir qa/robot/output qa/robot/gate.robot
```

Nothing under `qa/` ships: the release workflow copies an allowlist of runtime directories
and `qa/` is not in it.
