/-
Copyright (c) 2020 Xi Wang. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Xi Wang.
-/

import tactic.basic

/-!
# A compiler for arithmetic expressions

A formalization of the correctness of a compiler from arithmetic expressions to assembly code
described by McCarthy and Painter.

## Tags

compiler

## Main results

* `expr`                : the syntax of the source language.
* `value`               : the semantics of the source language.
* `instruction`         : the syntax of the target language.
* `step`                : the semantics of the target language.
* `compile`             : the compiler.
* `compiler_correctness`: the compiler correctness theorem.

## Notation

* `≃[t]/ac`: partial equality of two machine states excluding registers x ≥ t and the accumulator.
* `≃[t]`   : partial equality of two machine states excluding registers x ≥ t.

## References

* John McCarthy and James Painter. Correctness of a compiler for arithmetic expressions.
  In Mathematical Aspects of Computer Science, volume 19 of Proceedings of Symposia in
  Applied Mathematics, 1967. <http://jmc.stanford.edu/articles/mcpain/mcpain.pdf>
-/

namespace arithcc

section types

/-! ### Types -/

/-- Value type shared by both source and target languages.  -/
@[reducible]
def word := ℕ

/-- Variable identifier type in the source language. -/
@[reducible]
def identifier := string

/-- Register name type in the target language. -/
@[reducible]
def register := ℕ

lemma register.lt_succ_self :
  ∀ (r : register), r < r + 1 :=
nat.lt_succ_self

lemma register.le_of_lt_succ {r₁ r₂ : register} :
  r₁ < r₂ + 1 → r₁ ≤ r₂ :=
nat.le_of_succ_le_succ

end types

section source

/-! ### Source language -/

/-- An expression in the source language is formed by constants, variables, and sums. -/
@[derive inhabited]
inductive expr
| const (v : word) : expr
| var (x : identifier) : expr
| sum (s₁ s₂ : expr) : expr

/-- The semantics of the source language (2.1). -/
@[simp]
def value : expr → (identifier → word) → word
| (expr.const v)   _ := v
| (expr.var x)     ξ := ξ x
| (expr.sum s₁ s₂) ξ := (value s₁ ξ) + (value s₂ ξ)

end source

section target

/-! ### Target language -/

/-- Instructions of the target assembly language (3.1--3.7).  -/
@[derive inhabited]
inductive instruction
| li   : word → instruction
| load : register → instruction
| sto  : register → instruction
| add  : register → instruction

/-- Machine state consists of the accumulator ac and a vector of registers.

The paper uses two functions `c` and `a` for accessing both the accumulator and registers.
Instead, we make accessing the accumulator and registers explicit, using `read` and `write`
for accessing registers only.
-/
structure state :=
mk :: (ac : word) (rs : register → word)

instance : inhabited state :=
⟨{ac := 0, rs := λ x, 0}⟩

/-- It's similar to the `c` function (3.8), but accesses registers only.  -/
@[simp]
def read (r : register) (η : state) : word :=
η.rs r

/-- The resulting machine state of updating a register. -/
@[simp]
def write (r : register) (v : word) (η : state) : state :=
{rs := λ x, if x = r then v else η.rs x, ..η}

/-- The semantics of the target language (3.11). -/
def step : instruction → state → state
| (instruction.li   v) η := {ac := v, ..η}
| (instruction.load r) η := {ac := read r η, ..η}
| (instruction.sto  r) η := write r η.ac η
| (instruction.add  r) η := {ac := read r η + η.ac, ..η}

/-- The resulting machine state of running a target program from a given machine state (3.12). -/
@[simp]
def outcome : list instruction → state → state
| []        η := η
| (i :: is) η := outcome is (step i η)

/-- A lemma on the concatenation of two programs (3.13). -/
@[simp]
lemma outcome_append (p₁ p₂ : list instruction) (η : state) :
  outcome (p₁ ++ p₂) η = outcome p₂ (outcome p₁ η) :=
begin
  revert η,
  induction p₁; intros; simp,
  apply p₁_ih
end

end target

section compiler

open instruction

/-! ### Compiler -/

/-- Map a variable in the source expression to a machine register. -/
@[simp]
def loc (ν : identifier) (map : identifier → register) : register :=
map ν

/-- The implementation of the compiler (4.2).

This definition explicitly takes a map from variables to registers.
-/
@[simp]
def compile (map : identifier → register) : expr → register → (list instruction)
| (expr.const v)   _ := [li v]
| (expr.var x)     _ := [load (loc x map)]
| (expr.sum s₁ s₂) t := compile s₁ t ++ [sto t] ++ compile s₂ (t + 1) ++ [add t]

end compiler

section correctness

/-! ### Correctness -/

/-- Machine states ζ₁ and ζ₂ are equal except for the accumulator and registers {x | x ≥ t}. -/
def state_eq_rs (t : register) (ζ₁ ζ₂ : state) : Prop :=
∀ (r : register), r < t → ζ₁.rs r = ζ₂.rs r

notation ζ₁ ` ≃[`:50 t `]/ac ` ζ₂:50 := state_eq_rs t ζ₁ ζ₂

@[refl]
protected lemma state_eq_rs.refl (t : register) (ζ : state) :
  ζ ≃[t]/ac ζ :=
by simp [state_eq_rs]

@[symm]
protected lemma state_eq_rs.symm {t : register} (ζ₁ ζ₂ : state) :
  ζ₁ ≃[t]/ac ζ₂ →
  ζ₂ ≃[t]/ac ζ₁ :=
by finish [state_eq_rs]

@[trans]
protected lemma state_eq_rs.trans {t : register} (ζ₁ ζ₂ ζ₃ : state) :
  ζ₁ ≃[t]/ac ζ₂ →
  ζ₂ ≃[t]/ac ζ₃ →
  ζ₁ ≃[t]/ac ζ₃ :=
by finish [state_eq_rs]

/-- Machine states ζ₁ and ζ₂ are equal except for registers {x | x ≥ t}. -/
def state_eq (t : register) (ζ₁ ζ₂ : state) : Prop :=
ζ₁.ac = ζ₂.ac ∧ state_eq_rs t ζ₁ ζ₂

notation ζ₁ ` ≃[`:50 t `] ` ζ₂:50 := state_eq t ζ₁ ζ₂

@[refl]
protected lemma state_eq.refl (t : register) (ζ : state) :
  ζ ≃[t] ζ :=
by simp [state_eq]

@[symm]
protected lemma state_eq.symm {t : register} (ζ₁ ζ₂ : state) :
  ζ₁ ≃[t] ζ₂ →
  ζ₂ ≃[t] ζ₁ :=
begin
  simp [state_eq], intros,
  split; try { cc },
  symmetry,
  assumption
end

@[trans]
protected lemma state_eq.trans {t : register} (ζ₁ ζ₂ ζ₃ : state) :
  ζ₁ ≃[t] ζ₂ →
  ζ₂ ≃[t] ζ₃ →
  ζ₁ ≃[t] ζ₃ :=
begin
  simp [state_eq], intros,
  split; try { cc },
  transitivity ζ₂; assumption
end

/-- Transitivity of chaining `≃[t]` and `≃[t]/ac`. -/
@[trans]
protected theorem state_eq_state_eq_rs.trans (t : register) (ζ₁ ζ₂ ζ₃ : state) :
  ζ₁ ≃[t] ζ₂ →
  ζ₂ ≃[t]/ac ζ₃ →
  ζ₁ ≃[t]/ac ζ₃ :=
begin
  simp [state_eq], intros,
  transitivity ζ₂; assumption
end

/-- Writing the same value to register `t` gives `≃[t + 1]` from `≃[t]`. -/
lemma state_eq_implies_write_eq {t : register} {ζ₁ ζ₂ : state} (h : ζ₁ ≃[t] ζ₂) (v : word) :
  write t v ζ₁ ≃[t + 1] write t v ζ₂ :=
begin
  simp [state_eq, state_eq_rs] at *,
  split ; try { cc },
  intros _ hr,
  have hr : r ≤ t := register.le_of_lt_succ hr,
  cases lt_or_eq_of_le hr with hr hr,
  { cases h with _ h,
    specialize h r hr,
    cc },
  { cc }
end

/-- Writing the same value to any register preserves `≃[t]/ac`. -/
lemma state_eq_rs_implies_write_eq_rs {t : register} {ζ₁ ζ₂ : state} (h : ζ₁ ≃[t]/ac ζ₂)
                                      (r : register) (v : word) :
  write r v ζ₁ ≃[t]/ac write r v ζ₂ :=
begin
  simp [state_eq_rs] at *,
  intros r' hr',
  specialize h r' hr',
  cc
end

/-- `≃[t + 1]` with writing to register `t` implies `≃[t]`. -/
lemma write_eq_implies_state_eq {t : register} {v : word} {ζ₁ ζ₂ : state}
                                (h : ζ₁ ≃[t + 1] write t v ζ₂) :
  ζ₁ ≃[t] ζ₂ :=
begin
  simp [state_eq, state_eq_rs] at *,
  split; try { cc },
  intros r hr,
  cases h with _ h,
  specialize h r (lt_trans hr (register.lt_succ_self _)),
  rwa if_neg (ne_of_lt hr) at h
end

/-- The main theorem on compiler correctness.

Unlike Theorem 1 in the paper, both `map` and the assumption on `t` are explicit.
-/
theorem compiler_correctness :
  ∀ (map : identifier → register) (e : expr) (ξ : identifier → word) (η : state) (t : register),
    (∀ x, read (loc x map) η = ξ x) →
    (∀ x, loc x map < t) →
    outcome (compile map e t) η ≃[t] {ac := value e ξ, ..η} :=
begin
  intros _ _ _ _ _ hmap ht,
  revert η t,
  induction e; intros,

  -- 5.I
  case expr.const { simp [state_eq, step] },

  -- 5.II
  case expr.var   { finish [hmap, state_eq, step] },

  -- 5.III
  case expr.sum   { simp,
    generalize_hyp dν₁ : value e_s₁ ξ = ν₁ at e_ih_s₁ ⊢,
    generalize_hyp dν₂ : value e_s₂ ξ = ν₂ at e_ih_s₂ ⊢,
    generalize     dν  : ν₁ + ν₂ = ν,

    generalize dζ₁ : outcome (compile _ e_s₁ t) η        = ζ₁,
    generalize dζ₂ : step (instruction.sto t) ζ₁         = ζ₂,
    generalize dζ₃ : outcome (compile _ e_s₂ (t + 1)) ζ₂ = ζ₃,
    generalize dζ₄ : step (instruction.add t) ζ₃         = ζ₄,

    have hζ₁ : ζ₁ ≃[t] {ac := ν₁, ..η},
    calc ζ₁
        = outcome (compile map e_s₁ t) η : by cc
    ... ≃[t] {ac := ν₁, ..η}             : by apply e_ih_s₁; assumption,

    have hζ₁_ν₁ : ζ₁.ac = ν₁,
    { finish [state_eq] },

    have hζ₂ : ζ₂ ≃[t + 1]/ac write t ν₁ η,
    calc ζ₂
        = step (instruction.sto t) ζ₁       : by cc
    ... = write t ζ₁.ac ζ₁                  : by simp [step]
    ... = write t ν₁ ζ₁                     : by cc
    ... ≃[t + 1] write t ν₁ {ac := ν₁, ..η} : by apply state_eq_implies_write_eq hζ₁
    ... ≃[t + 1]/ac write t ν₁ η            : by { apply state_eq_rs_implies_write_eq_rs,
                                                   simp [state_eq_rs] },

    have hζ₂_ν₂ : read t ζ₂ = ν₁,
    { simp [state_eq_rs] at hζ₂ ⊢,
      specialize hζ₂ t (register.lt_succ_self _),
      cc },

    have ht' : ∀ x, loc x map < t + 1,
    { intros,
      apply lt_trans (ht _) (register.lt_succ_self _) },

    have hmap' : ∀ x, read (loc x map) ζ₂ = ξ x,
    { intros,
      calc read (loc x map) ζ₂
          = read (loc x map) (write t ν₁ η) : by { apply hζ₂, apply ht' }
      ... = read (loc x map) η              : by { simp, rw if_neg, apply ne_of_lt (ht _) }
      ... = ξ x                             : by apply hmap
    },

    have hζ₃ : ζ₃ ≃[t + 1] {ac := ν₂, ..(write t ν₁ η)},
    calc ζ₃
        = outcome (compile map e_s₂ (t + 1)) ζ₂ : by cc
    ... ≃[t + 1] {ac := ν₂, ..ζ₂}               : by apply e_ih_s₂; assumption
    ... ≃[t + 1] {ac := ν₂, ..(write t ν₁ η)}   : by { simp [state_eq], apply hζ₂ },

    have hζ₃_ν₂ : ζ₃.ac = ν₂,
    { finish [state_eq] },

    have hζ₃_ν₁ : read t ζ₃ = ν₁,
    { simp [state_eq, state_eq_rs] at hζ₃ ⊢,
      cases hζ₃ with _ hζ₃,
      specialize hζ₃ t (register.lt_succ_self _),
      cc },

    have hζ₄ : ζ₄ ≃[t + 1] {ac := ν, ..write t ν₁ η},
    calc ζ₄
        = step (instruction.add t) ζ₃      : by cc
    ... = {ac := read t ζ₃ + ζ₃.ac, ..ζ₃}  : by simp [step]
    ... = {ac := ν, ..ζ₃}                  : by cc
    ... ≃[t + 1] {ac := ν, ..{ac := ν₂, ..write t ν₁ η}}
                                           : by { simp [state_eq] at hζ₃ ⊢, cases hζ₃, assumption }
    ... ≃[t + 1] {ac := ν, ..write t ν₁ η} : by simp,

    apply write_eq_implies_state_eq; assumption }
end

end correctness

end arithcc
