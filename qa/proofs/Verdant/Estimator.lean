import Mathlib

/-!
# Verdant estimator guarantees

Verdant samples the healer's output at a fixed rate. Every sample carries the effective
rate over the rolling window (`eHPS`, `MPS`) and, per ability, its share of that tick.
The CONTRIB view estimates what each ability contributed over the window as

    Σ_i  share_i · rate_i · dt_i

The session library stores shares rounded to thousandths and rates rounded to tenths.
This file proves the error that rounding can introduce in the estimate, so that "a library
session renders exactly what was live" is a statement about the code and the numbers behind
it, not a hope.
-/

namespace Verdant

open Finset BigOperators

/-- Rounding to the nearest multiple of `1/k`, the way the session store packs a value
with `scale = k`: multiply, round half up, divide. -/
noncomputable def quant (k : ℕ) (x : ℝ) : ℝ := (⌊x * k + 1 / 2⌋ : ℝ) / k

/-- Rounding half up to an integer moves a real by at most one half. -/
theorem abs_round_half_up_sub_le (y : ℝ) : |(⌊y + 1 / 2⌋ : ℝ) - y| ≤ 1 / 2 := by
  have h1 : (⌊y + 1 / 2⌋ : ℝ) ≤ y + 1 / 2 := Int.floor_le _
  have h2 : y + 1 / 2 < (⌊y + 1 / 2⌋ : ℝ) + 1 := Int.lt_floor_add_one _
  rw [abs_le]
  constructor <;> linarith

/-- Quantizing to `1/k` moves a value by at most `1/(2k)`. -/
theorem abs_quant_sub_le (k : ℕ) (hk : 0 < k) (x : ℝ) :
    |quant k x - x| ≤ 1 / (2 * k) := by
  have hkR : (0 : ℝ) < k := by exact_mod_cast hk
  unfold quant
  have h := abs_round_half_up_sub_le (x * k)
  have : (⌊x * k + 1 / 2⌋ : ℝ) / k - x = ((⌊x * k + 1 / 2⌋ : ℝ) - x * k) / k := by
    field_simp
  rw [this, abs_div, abs_of_pos hkR]
  rw [div_le_div_iff₀ hkR (by positivity)]
  nlinarith [h]

/-- The contribution estimate: shares times per-tick amounts, summed over the window. -/
def contrib {n : ℕ} (share amount : Fin n → ℝ) : ℝ := ∑ i, share i * amount i

/-- Rounding every share to `1/k` changes the estimate by at most `1/(2k)` of the window
total, as long as every per-tick amount is non-negative (rates and time deltas are). -/
theorem contrib_quant_err {n : ℕ} (k : ℕ) (hk : 0 < k)
    (share amount : Fin n → ℝ) (hpos : ∀ i, 0 ≤ amount i) :
    |contrib (fun i => quant k (share i)) amount - contrib share amount|
      ≤ (1 / (2 * k)) * ∑ i, amount i := by
  unfold contrib
  have hdiff : ∑ i, quant k (share i) * amount i - ∑ i, share i * amount i
      = ∑ i, (quant k (share i) - share i) * amount i := by
    rw [← Finset.sum_sub_distrib]
    congr 1
    ext i
    ring
  rw [hdiff]
  calc |∑ i, (quant k (share i) - share i) * amount i|
      ≤ ∑ i, |(quant k (share i) - share i) * amount i| := Finset.abs_sum_le_sum_abs _ _
    _ = ∑ i, |quant k (share i) - share i| * amount i := by
        congr 1
        ext i
        rw [abs_mul, abs_of_nonneg (hpos i)]
    _ ≤ ∑ i, (1 / (2 * k)) * amount i := by
        apply Finset.sum_le_sum
        intro i _
        exact mul_le_mul_of_nonneg_right (abs_quant_sub_le k hk (share i)) (hpos i)
    _ = (1 / (2 * k)) * ∑ i, amount i := by rw [Finset.mul_sum]

/-- The concrete bound Verdant ships with: shares packed to thousandths cost at most one
part in two thousand of the window total. -/
theorem contrib_library_err {n : ℕ} (share amount : Fin n → ℝ) (hpos : ∀ i, 0 ≤ amount i) :
    |contrib (fun i => quant 1000 (share i)) amount - contrib share amount|
      ≤ (1 / 2000) * ∑ i, amount i := by
  have h := contrib_quant_err 1000 (by norm_num) share amount hpos
  norm_num at h ⊢
  exact h

end Verdant
