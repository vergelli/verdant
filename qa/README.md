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

## Feeding the oracle with real fights

The only data that validates the measurement is a trace: the game's raw events, captured
in game and replayed offline through the real pipeline. Capturing one is a side effect of
recording once auto-trace is on (debug build only):

```
/verdant trace auto      once; every Record now captures, every Stop stages the trace
... play ...
/verdant flush           writes SavedVariables to disk (it reloads the UI)
qa\ingest.bat --open     on the PC: pulls the staged traces into the corpus, runs the suite
```

The addon keeps the last three staged traces in SavedVariables. `qa/ingest.py` extracts
each one into `../VerdantWorkingdir/traces/<date>_<zone>_<world>_<events>_sv.lua`, skips
the ones already there, then runs the Robot suite, whose "Real Traces Replay Clean" test
replays every file in that directory. `/verdant trace` shows how many are staged;
`/verdant trace clear` empties the ring once they are ingested.

Nothing under `qa/` ships: the release workflow copies an allowlist of runtime directories
and `qa/` is not in it.
