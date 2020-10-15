/-
Copyright (c) 2020 Xi Wang. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Xi Wang.
-/

import arithcc

namespace arithcc

section test

open instruction

/-- The example in the paper for compiling (x + 3) + (x + (y + 2)). -/
example (x y t : register) :
  let map := λ v, if v = "x" then x else if v = "y" then y else 0,
      p   := expr.sum (expr.sum (expr.var "x") (expr.const 3))
                      (expr.sum (expr.var "x") (expr.sum (expr.var "y") (expr.const 2))) in
  compile map p t =
  [ load x,
    sto  t,
    li   3,
    add  t,
    sto  t,
    load x,
    sto  (t + 1),
    load y,
    sto  (t + 2),
    li   2,
    add  (t + 2),
    add  (t + 1),
    add  t ] :=
rfl

end test

end arithcc
