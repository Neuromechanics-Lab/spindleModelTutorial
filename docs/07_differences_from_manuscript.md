# How this tutorial differs from the manuscript

The tutorial calls the **same model functions** the manuscript does — they are
vendored verbatim in `vendor/`, and `setupTutorialPaths` prefers your live
checkouts over them. Nothing in the biophysics is reimplemented.

The *workflow around* those functions does differ, because a self-contained
teaching demo cannot do everything a production fit does. This page lists every
difference we know of. If you find one that is not here, it is a bug in this
page — please add it.

Manuscript reference: `hybridOptimizationGammaDrive_Bspline_5cp_grid.m`,
`objFuncWithFixedTiming_Bspline_5cp_normSmooth.m`, `getSimulationConfig.m`.

## Identical

| | value |
|---|---|
| Cross-bridge / spindle model | `sarcSimDriverIntrafusal20250627`, `sarc2spindle_20240310`, `musTenDriver20250627` — vendored, unmodified |
| γ-static parameterization | `getIntrafusal_pCa_Bspline_5cp` — periodic B-spline, 5 control points + phase |
| Simulation call | `runSpindleSimForOpt_Bspline_5cp` |
| Spike generator | `integrateAndFire_v2` |
| Transduction gains | `kFc = 0.6`, `kFb = 1.1`, `kYb = 0.1`, occlusion off, threshold 0 |
| Time step | `dt = 1 ms` |
| Gait cycle | 0.64 s |
| pCa bounds | 4.5 – 9.0 |
| Bag baseline | `initial_pCa = 9` |
| Cost | mean-normalized RMSE (each trace ÷ its own mean) |

## Different

### 1. The target is simulated, not recorded
**Manuscript:** real Taylor Ia firing (`getTaylorDataWithEMGActivation`), sampled
on gait-cycle phase.
**Tutorial:** the model generates its own target, so the true answer is known and
recovery can be scored. This is the whole point of the demo, but it means the
demo never faces measurement noise, trial-to-trial variability, or model
mismatch.

### 2. The length/α input is synthetic
**Manuscript:** *measured* MTU length and EMG-derived α activation from the
walking data.
**Tutorial:** an idealized sinusoid (8% amplitude, α modulated at the same
frequency). Real gait length profiles are not sinusoidal, and the yank content —
which the bag fiber responds to — differs.

### 3. What is compared
**Manuscript:** the model's **firing rate**, transformed to gait-cycle phase,
restricted to phase ∈ (0, 1.5), sampled at spike phases (`smoothWin = 0` in the
driver; the function also offers a 300-point uniform phase grid with Gaussian
smoothing).
**Tutorial:** the model's **receptor potential**, on the time grid, every sample,
no phase transform and no smoothing. The Your-data tab offers a firing-rate mode
(`fitTarget = 'firing'`) but still on the time grid.

### 4. Burst timing is fixed, with no outer grid
**Manuscript:** an outer grid over the γ-dynamic on/off times — 7×7 coarse then
5×5 refine, spanning 2–98% of the cycle, with a `patternsearch` fit of the 7
inner parameters at *every node* (245 fits, run in parallel).
**Tutorial:** timing is fixed at 10%/60% and only the inner 7 parameters are fit
— **one** fit. This is the single biggest difference in optimization effort, and
the main reason the tutorial's recovery is weaker and more erratic.

### 5. Solver settings
Both now use `patternsearch` (the tutorial exposes `opts.solver` and defaults to
it; `'fmincon'` is available for comparison). The settings differ:

| | manuscript | tutorial |
|---|---|---|
| MaxFunctionEvaluations | 400 | 2000 |
| MaxIterations | 200 | 25 (the app's spinner) |
| MeshTolerance / StepTolerance | 1e-4 / 1e-8 | defaults |
| PollMethod | `GPSPositiveBasis2N` | default |
| Parameter scaling | phase × 10 (`scaleVec_inner`) | none |
| Initial guess | midpoint of the bounds | bag 7.0, cp 6.5, phase 0 |

The phase scaling matters: phase spans ±0.32 s while the pCa parameters span 4.5
units, so an unscaled search takes effectively tiny steps in phase.

### 6. Horizon
**Manuscript:** simulates 4.5 s, then trims the *cost window* to
`sineStart + 2.7` cycles for speed.
**Tutorial:** 1.6–1.9 s total (≈2–3 cycles), chosen to keep an interactive fit to
a few minutes. The cost windows are comparable; the settling before it is not.

## What it costs in run time

The Learn window is unaffected — a playground re-run is ~1.6 s, and moving a
gamma slider ~1.3 s. The two fits in the Analysis Toolkit are slower than they
were, because `patternsearch` polls 2N points per iteration and the budget rose
from 12 to 25 iterations to compensate:

| | before | now |
|---|---|---|
| Gamma optimization | 78 s (fmincon, 12 iter, serial) | **88 s** (patternsearch, 25, **parallel** — on by default) |
| — same, serial | | 228 s |
| Your data, optimize | 64 s (firing, fmincon) | **134 s** (receptor, fmincon — the new default) |

Parallel is worth 2.6× on the gamma fit, because patternsearch's 2N poll points
are independent; the first run pays a one-off ~45 s pool startup. Both fits are
still far below the manuscript's own budget (200 iterations / 400 evaluations per
node, at 245 nodes).

The two tabs default to *different* solvers, deliberately. The gamma demo uses
patternsearch (the manuscript's, and it reaches a ~4× lower cost here than
fmincon); the Your-data tab uses fmincon, which converges better on its compact
four-parameter fit. Both are switchable — `opts.solver`, or the **Solver**
dropdown.

## What this costs you

The tutorial's gamma-optimization demo recovers the **bag burst magnitude**
reliably (~99% of its initial error). The **γ-static control points recover
erratically** — sometimes several close 60–100%, sometimes none move, and
individual points often move *away* from truth. Contributing factors, roughly in
order:

1. **No outer timing grid** (§4) — one fit instead of 245.
2. **Weak leverage.** The bag dominates the combined trace: `rms(r_d)` ≈ 5×
   `rms(r_s)`, and perturbing the bag by 0.2 pCa costs ~12× what perturbing one
   control point by 0.2 does. Flattening the *entire* γ-static waveform costs
   less than a 0.2 pCa bag error.
3. **Neighbouring control points trade off against each other** — adjacent points
   move in opposite directions, the signature of overlapping B-spline bases.

This is not a chain-vs-bag degeneracy: making the chain stronger does *not*
compensate for a wrong bag (a compensating perturbation costs slightly **more**
than moving the bag alone). It is simply that the chain contributes little to the
combined signal. When the bag is made weak (pCa 7.5) and the chain strong, the
chain does become partly identifiable — so the imbalance is drive-dependent, not
fundamental.

An earlier version of this demo scored `r_s` and `r_d` **separately** and
recovered all seven parameters to 95–100%. That is only possible with a simulated
target, which can be decomposed into its static and dynamic parts; a real
recording is one signal. It was removed for giving the demo information no
experiment has.
