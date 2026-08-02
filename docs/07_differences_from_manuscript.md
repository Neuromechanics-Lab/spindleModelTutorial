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
frequency).

### 3. What is compared
**Manuscript:** the model's **firing rate**, transformed to gait-cycle phase,
restricted to phase ∈ (0, 1.5), sampled at spike phases (`smoothWin = 0` in the
driver; the function also offers a 300-point uniform phase grid with Gaussian
smoothing).
**Tutorial:** the model's **receptor potential**, on the time grid, every sample,
no phase transform and no smoothing. The Your-data tab offers a firing-rate mode
(`fitTarget = 'firing'`) but still on the time grid.

The mean-normalized cost makes `r` and firing rate interchangeable *in principle*
— below the ceiling they are proportional, and normalization cancels the factor — and the manuscript never made
this substitution (its objective always runs `integrateAndFire_v2`). On the
built-in example, whose truth is known, fitting `r` recovers the bag burst
(pCa 7.54, 0.36–1.21 s vs a truth of 7.68, 0.35–1.15 s) at cost 0.064, while
fitting firing collapses the burst to zero width at cost 0.225. The firing
objective is about half as sensitive to bag pCa, because the model's firing
saturates at the 250 spikes/s ceiling where the bag acts. So this difference
favours the tutorial's default — but it is a real difference, not a wash.

### 4. Burst timing is fixed, with no outer grid
**Manuscript:** an outer grid over the γ-dynamic on/off times — 7×7 coarse then
5×5 refine, spanning 2–98% of the cycle, with a `patternsearch` fit of the 7
inner parameters at *every node* (245 fits, run in parallel).
**Tutorial:** timing is fixed at 10%/60% and only the inner 7 parameters are fit
— **one** fit. This is the single biggest difference in optimization effort. It
also means the fit is handed the true burst timing, since the same fixed values
build the target — so this demo cannot be used to ask which parameters are
identifiable.

### 4b. The Your-data tab fits a different γ parameterization

The gamma-optimization demo uses the manuscript's periodic B-spline. The
**Your-data** tab has to cope with arbitrary user protocols, so it defaults to a
**non-periodic** 5-control-point spline (`gammaStatic = 'bspline-free'`), and
offers the manuscript's periodic variant (`'bspline-periodic'`, which needs a
stated cycle period) plus a single-level `'constant'` mode.

It also fits burst on/off in **seconds** rather than as a percentage of the gait
cycle, and does not fit a phase term — in a free spline the phase is redundant
with the control points, and in the periodic variant the cycle is anchored at the
start of the data.

### 5. Solver settings
The gamma-optimization demo uses `patternsearch`, as the manuscript does (the
Your-data tab defaults to `fmincon` instead — see below). The settings differ:

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
**Tutorial:** 1.6 s for the gamma demo, 1.8 s for the Your-data example (≈2–3
cycles), chosen to keep an interactive fit to a few minutes. The cost windows are
comparable; the settling before it is not.

## What it costs in run time

The Learn window is unaffected — a playground re-run is ~1.6 s, and moving a
gamma slider ~1.3 s. The two fits in the Analysis Toolkit are slower than they
were, because `patternsearch` polls 2N points per iteration and the budget rose
from 12 to 25 iterations to compensate:

| | before | now |
|---|---|---|
| Gamma optimization | 78 s (fmincon, 12 iter, serial) | **88 s** (patternsearch, 25, **parallel** — on by default) |
| — same, serial | | 228 s |
| Your data, optimize | 64 s (firing, fmincon, 4 parameters) | **~125 s** (receptor, fmincon, 8 parameters — the new default) |

Parallel is worth 2.6× on the gamma fit, because patternsearch's 2N poll points
are independent; the first run pays a one-off ~45 s pool startup. Both fits are
still far below the manuscript's own budget (200 iterations / 400 evaluations per
node, at 245 nodes).

The two tabs default to *different* solvers. The gamma demo uses patternsearch
(the manuscript's, and it reaches a ~4× lower cost here than fmincon). The
Your-data tab defaults to fmincon, where on the built-in 8-parameter fit the two
land close together — 0.064 vs 0.071 on the same 20-iteration budget — with
fmincon slightly ahead and slightly quicker. Neither dominates there; both are
switchable via `opts.solver` or the **Solver** dropdown.

## What this costs you

The demo runs ONE fit with burst timing fixed, where the manuscript runs 245 with
timing searched. Because that fixed timing is also the timing used to build the
target, the fit starts with information it would not have on real data — so the
per-parameter recovery numbers this demo reports are **not** evidence about which
parameters are identifiable, and should not be read that way. They show the
workflow running, nothing more.

If you want to ask an identifiability question with this code, the timing has to
be searched too, as the manuscript does.
