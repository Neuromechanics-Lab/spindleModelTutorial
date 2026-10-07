# How this tutorial differs from the manuscript

The tutorial calls the **same model functions** the manuscript does — they are
vendored verbatim in `vendor/`, and `setupTutorialPaths` prefers your live
checkouts over them. Nothing in the biophysics is reimplemented.

The *workflow around* those functions does differ, because a self-contained
teaching demo cannot do everything a production fit does. This page lists every
difference we know of. If you find one that is not here, it is a bug in this
page — please add it.

Manuscript reference: the Figure 1 receptor-potential fits —
`hybridOptimizationGammaDrive_Bspline_5cp_grid_rPotential.m` (γ-dynamic burst),
`hybridOptimizationGammaDrive_gDynBspline_grid_rPotential.m` (γ-dynamic B-spline,
Figure 1D), `objFuncWithFixedTiming_Bspline_5cp_rPotential.m` — and
`getSimulationConfig.m`, at `gammaDriveOptimization` commit 1107951.

## Identical

| | value |
|---|---|
| Cross-bridge / spindle model | `sarcSimDriverIntrafusal20250627`, `sarc2spindle_20240310`, `musTenDriver20250627` — vendored, unmodified |
| γ-static parameterization | `getIntrafusal_pCa_Bspline_5cp` — periodic B-spline, 5 control points + phase |
| γ-dynamic parameterization | on/off burst, or (`gammaDynamic = 'bspline'`) the Figure 1D periodic B-spline, 5 control points — `getIntrafusal_pCa_Bspline_5cp_gDynBspline` |
| Simulation call | `runSpindleSimForOpt_Bspline_5cp` / `runSpindleSimForOpt_Bspline_5cp_gDynBspline` — vendored, unmodified |
| Intrafusal start length | fibers start at the fascicle length (`syncIntrafusalStartLength`) |
| Activation curve | `ActCurveSim120260814.mat` (`ActCurveDate = 20260814`). The earlier `20240819` file's bag column predated the bag detachment change (g 7 → 40) and drove the bag up to ~0.7 pCa harder for the same % activation; chain and extrafusal are unchanged |
| Transduction gains | `kFc = 0.6`, `kFb = 1.1`, `kYb = 0.1`, occlusion off, threshold 0 |
| Time step | `dt = 1 ms` |
| Gait cycle | 0.64 s |
| pCa bounds | 4.5 – 9.0 |
| Bag baseline | `initial_pCa = 9` |
| Cost | receptor potential above its no-drive baseline `mean(r(1:10))`, floored at 0, then mean-normalized RMSE (each trace ÷ its own mean) — `rPotentialCost`. The manuscript also divides by 100; cost values here are 100× its printed ones |
| Solver (gamma demo) | `patternsearch` — the manuscript uses it throughout, with no `fmincon` stage |

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
Both now fit the model's **receptor potential**. Since 2026-08-14 the
manuscript's Figure 1 fits score `r` above its no-drive baseline, floored at 0,
against the recorded Ia firing, over gait phase ∈ (0, 1.5) after one start-up
cycle, on the native 1 ms grid (`smoothWin = 0`). The spike generator appears
only in its run-results and plotting scripts, never in an objective.

**Gamma demo:** the same cost and the same phase window (`result.scoreWindow`,
drawn as dotted lines). The self-generated target is `r` from the true drive,
given the same baseline subtraction and floor, so it has a true zero like the
firing rate it stands in for.
**Your-data tab:** the same baseline-subtracted, floored `r`, but scored over the
**whole trial** (an arbitrary protocol has no gait phase), and both traces are
smoothed with a ~50 ms moving mean first. It also offers a firing-rate mode
(`fitTarget = 'firing'`), which the manuscript no longer uses.

The tutorial's firing mode is the one place it still differs in kind. On the
built-in example, whose truth is known (bag pCa 8.39, 0.35–1.15 s), fitting `r`
gets the bag level about right (pCa 8.63) at cost 0.043, while fitting firing
overdrives the bag by about 2 pCa (6.28) at cost 0.189; neither recovers the
burst timing on a 20-iteration budget. The firing objective is about half as
sensitive to bag pCa. So the default — the manuscript's choice too — is the
better one here.

### 4. Burst timing (or B-spline phase) is fixed, with no outer grid
**Manuscript:** an outer grid over the γ-dynamic on/off times — 7×7 coarse then
5×5 refine, spanning 2–98% of the cycle, with a `patternsearch` fit of the 7
inner parameters at *every node*, then an 8-start polish at the best timing —
82 fits in all, run in parallel. For the B-spline γ-dynamic (Figure 1D) the grid
is 1-D, over the γ-dynamic phase within one control-point interval (8 coarse +
8 refine nodes), with an 11-parameter inner fit and a 16-start polish.
**Tutorial:** burst timing is fixed at 10%/60% (or the B-spline phase at 0) and
only the inner 7 (or 11) parameters are fit — **one** fit. This is the single
biggest difference in optimization effort. It also means the fit is handed the
true timing, since the same fixed values build the target — so this demo cannot
be used to ask which parameters are identifiable.

### 4b. The Your-data tab fits a different γ parameterization

The gamma-optimization demo uses the manuscript's periodic B-spline. The
**Your-data** tab has to cope with arbitrary user protocols, so it defaults to a
**non-periodic** 5-control-point spline (`gammaStatic = 'bspline-free'`), and
offers the manuscript's periodic variant (`'bspline-periodic'`, which needs a
stated cycle period) plus a single-level `'constant'` mode. γ-dynamic defaults
to the on/off burst (`gammaDynamic = 'pulse'`); `'bspline-free'` and
`'bspline-periodic'` give it the same 5-control-point splines, the Figure 1D
form.

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

The manuscript's grid fits use the settings above; its final polish runs a longer
budget (1000 evaluations, 300 iterations, mesh 1e-5, step 1e-9).

The phase scaling matters: phase spans ±0.32 s while the pCa parameters span 4.5
units, so an unscaled search takes effectively tiny steps in phase.

### 6. Horizon
**Manuscript:** simulates 4.5 s, trimmed to `sineStart + 2.7` cycles for speed;
the cost is scored over gait-cycle phase 0–1.5.
**Tutorial:** 1.9 s for the gamma demo (the app's default; the stretch starts at
0.3 s, so that is `sineStart + 2.5` cycles — exactly enough to hold the same
phase 0–1.5 window after one start-up cycle), 1.8 s for the Your-data example,
chosen to keep an interactive fit to a few minutes. A shorter demo horizon
truncates the scored window.

## What it costs in run time

The Learn window is interactive — a playground re-run is ~1.6 s, and moving a
gamma slider ~1.3 s. The two fits in the Analysis Toolkit take minutes:

| Fit | Time | Configuration |
|---|---|---|
| Gamma optimization | **57 s** | patternsearch, 25 iterations, parallel (on by default), burst γ-dynamic |
| — same, serial | 86 s | without the Parallel Computing Toolbox |
| — B-spline γ-dynamic | 59 s parallel, 134 s serial | 11 parameters |
| Your data, optimize | **~62 s** | fmincon, 8 parameters, fitting the receptor potential |

Parallel is worth 1.5× on the burst fit and 2.3× on the B-spline fit, because
patternsearch's 2N poll points are independent; the first run pays a one-off
~35 s pool startup (8 workers). Both fits are far below the manuscript's own
budget (200 iterations / 400 evaluations per node, at 74 grid nodes plus an
8-start polish).

The two tabs default to *different* solvers. The gamma demo uses patternsearch
because the manuscript does — but with the receptor-potential cost, `fmincon`
does better on the demo's budget: cost 0.022 in 46 s (serial) against
patternsearch's 0.115 in 86 s. The Your-data tab defaults to fmincon; on the
built-in 8-parameter fit it reaches 0.043 against patternsearch's 0.084 on the
same 20-iteration budget, and is slightly quicker. Both are switchable via
`opts.solver` or the **Solver** dropdown.

## What this costs you

The demo runs ONE fit with burst timing fixed, where the manuscript runs 82 with
timing searched. Because that fixed timing is also the timing used to build the
target, the fit starts with information it would not have on real data — so the
per-parameter recovery numbers this demo reports are **not** evidence about which
parameters are identifiable, and should not be read that way. They show the
workflow running, nothing more.

If you want to ask an identifiability question with this code, the timing has to
be searched too, as the manuscript does.
