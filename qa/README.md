# Verdant quality guarantees

Everything a release claims about its numbers, executed and reported. Two layers, one
repository:

| Directory | Layer | Tool | Answers |
|---|---|---|---|
| `qa/robot` | Execution | Robot Framework over the offline ESO harness, SimLab oracle, layout audit, trace replays | "Does the shipped code compute what the model says, on synthetic fights and on real traces?" |
| `qa/proofs` | Model | Lean 4 + Mathlib | "Is the model itself right? What error can the library's rounding introduce?" |

`test/gate.sh` stays the fast pre-merge gate. The Robot suite runs the same checks and
produces the human-readable report (`log.html`, `report.html`) that a release can link to.

## Running the report

```
python -m pip install -r qa/robot/requirements.txt
python -m robot --outputdir qa/robot/output qa/robot/gate.robot
```

Open `qa/robot/output/report.html`. The proofs test is skipped until `lake` is installed
(see `qa/proofs/README.md`); the rest runs with Lua alone.

Nothing under `qa/` ships: the release workflow copies an allowlist of runtime directories
and `qa/` is not in it.
