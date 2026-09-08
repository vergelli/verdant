# Verdant proofs

Lean 4 formalisation of the maths behind Verdant's measurements. The Lua code is checked
against these definitions by the SimLab oracle (`test/simlab`); this directory proves the
properties of the definitions themselves.

## What is proven

`Verdant/Estimator.lean`

- `abs_quant_sub_le`: rounding a value to the nearest `1/k` moves it by at most `1/(2k)`.
- `contrib_quant_err`: the CONTRIB estimate (shares × per-tick amounts, summed over the
  window) changes by at most `1/(2k)` of the window total when every share is rounded to
  `1/k`, for any non-negative amounts.
- `contrib_library_err`: with the library's `scale = 1000`, that is one part in two
  thousand of the window total.

## Building

Nothing here was compiled on the machine that wrote it. The first job is to build it:

1. Install elan: https://github.com/leanprover/elan (it installs the toolchain named in
   `lean-toolchain` on first use).
2. In this directory: `lake exe cache get` (downloads the prebuilt Mathlib, several GB
   the first time), then `lake build`.
3. A clean build with no `sorry` in the output is the guarantee. The Robot suite in
   `qa/robot` runs exactly that as the test "Estimator Bounds Are Proven".

If a proof fails to elaborate, the statement is still the contract; fix the proof, not the
statement. Every theorem is written with named Mathlib lemmas so the failing line is
readable.

## Next candidates

- Rates packed with `scale = 10`: add the second rounding to `contrib_quant_err` and show
  the combined bound.
- `TemporalBuffer.summary`: integrating the sampled rate over the window equals the sum of
  events up to the first and last sample edges.
- Triage episode classifier: an episode is classified exactly once.
