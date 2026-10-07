# 6. Bringing your own data

The **Your data** tab (and the compute functions behind it) let you run the
model on inputs *you* supply, in two directions.

## The two modes

- **Forward** — you have the muscle **length** and the fiber **activations**, and
  you want the model's response:
  `length + activations → forces → Ia receptor potential`.
  (Spikes are a separate step - see `examples/spikesFromReceptorPotential.m`.)
- **Optimize** — you have the muscle **length** and a recorded **Ia firing rate**,
  and you want the **gamma (fusimotor) drive** that reproduces it:
  `length + your firing → inferred gamma drive`.

## File format

Save a `.mat` with these variables (or one struct named `data` with these
fields). Every time-series must be the **same length as `t`**.

| Variable | Meaning | Units | Needed for |
|----------|---------|-------|-----------|
| `t` | time, ~1 ms uniform step | s | always |
| `mtuLength` *or* `fascicleLength` | muscle length | nm | always |
| `alphaAct` | extrafusal (α) activation (default 0 — passive muscle) | `0..1` or `0..100` % | optional |
| `chainAct` | chain (γ-static) activation (default 0 — silent) | `0..1` or `0..100` % | forward |
| `bagAct` | bag (γ-dynamic) activation (default 0 — silent) | `0..1` or `0..100` % | forward |
| `targetFiring` | recorded Ia firing rate | spikes/s | optimize |
| `tendonStiffness` | tendon stiffness (scalar, default 5000) | — | optional |

**Length:** give `mtuLength` to have the model run the extrafusal muscle-tendon
unit (with your `alphaAct` + tendon) and compute the fascicle length the spindle
sees; or give `fascicleLength` directly and the intrafusal fibers follow it
as-is.

**Activations** may be fractions (`0..1`) or percent (`0..100`) — values whose
maximum exceeds ~1.5 are treated as percent and divided by 100. Missing
activations default to silent.

### Minimal examples

```matlab
% FORWARD: length + activations -> receptor potential
t          = 0:0.001:2;
mtuLength  = 1250 + 100*max(0, min(1, (t-0.3)/0.8));   % a ramp-and-hold (nm)
alphaAct   = 35 * ones(size(t));                       % 35% tonic alpha
chainAct   = 50 * ones(size(t));                       % 50% gamma-static
bagAct     = 10 * (t>0.3 & t<1.1);                     % gamma-dynamic burst
save('myForward.mat', 't','mtuLength','alphaAct','chainAct','bagAct');

% OPTIMIZE: length + recorded firing -> gamma
t            = 0:0.001:2;
mtuLength    = 1250 + 100*max(0, min(1, (t-0.3)/0.8));
alphaAct     = 35 * ones(size(t));
targetFiring = myRecordedIaRate;                       % spikes/s, same length as t
save('myOptimize.mat', 't','mtuLength','alphaAct','targetFiring');
```

## What the optimize mode fits

Eight parameters by default, by minimizing a **mean-normalized** RMSE against
your recording (see below):

- the **γ-static** drive — 5 B-spline control points (chain pCa),
- the **γ-dynamic** burst magnitude (bag pCa),
- the burst **onset** and **offset** (s).

Burst timing is fitted here. That is the one substantive difference from the
`Gamma optimization` tab, which holds timing fixed and fits only the magnitudes.
The γ-static spline also defaults to a **non-periodic** one, so that arbitrary
protocols work; the manuscript's periodic construction is available — see
[How γ-static is modelled](#how-γ-static-is-modelled) for all three modes and
their parameter counts. γ-dynamic can be a B-spline too — see
[How γ-dynamic is modelled](#how-γ-dynamic-is-modelled).

## Doing it from code

The tab is a thin wrapper over three compute functions you can call directly:

```matlab
setupTutorialPaths();
d   = loadUserData('myForward.mat');   % load + validate + normalize
out = runForwardFromData(d);           % forward: -> out.r, out.IFR, ...

d2  = loadUserData('myOptimize.mat');
res = runOptFromData(d2);              % optimize: -> res.xOpt, res.gammaOpt, ...
```

`exampleUserData()` returns a ready-made dataset in this format (the tab's
**Load built-in example** button), useful as a template.


## What the optimizer actually compares

In the default receptor mode the model's `r` is first taken **above its no-drive
baseline** and floored at 0. Then the cost is **mean-normalized**: each trace is
divided by its own mean before the RMSE, so only *shape* is compared.

```matlab
model = max(r - mean(r(1:10)), 0);       % the first 10 samples have no drive
mN = model / mean(model);   dN = data / mean(data);
cost = sqrt(mean((mN - dN).^2));
```

This is the cost the manuscript minimizes
(`objFuncWithFixedTiming_Bspline_5cp_rPotential.m` in `gammaDriveOptimization`;
here `compute/rPotentialCost.m`), which scales it by 1/100 before returning — a
constant, so the minimum is in the same place, but cost values here are 100× the
ones its scripts print. Unlike the manuscript, which scores gait phase 0–1.5, the
tab scores the whole trial, after smoothing both traces with a ~50 ms moving
mean.

The baseline is there because a mean-normalized comparison only works if both
traces share a zero. Your firing rate has one (silent). `r` does not — with no
drive at all it sits at a passive level — and left in, that pedestal squashes the
model's normalized swing toward the target's and lowers the cost for the wrong
reason. Below baseline the afferent would be silent, hence the floor. In
`'firing'` mode the model's firing already has a true zero, so nothing is
subtracted.

### Why the default fits the receptor potential

Because the cost is shape-only, the model's **receptor potential** `r` can be
fitted directly to your recorded **firing rate**, despite the units differing.
Below the spike generator's ceiling the two are proportional — `rate = r/threshold`
— and a proportional factor is exactly what mean-normalization removes.

Fitting `r` also keeps the spike generator's limits (a 250 spikes/s ceiling at
`dt = 1 ms`, and rate quantization to `1/(k*dt)`) out of the objective entirely.
Where the model's firing is pinned at the ceiling the objective goes flat and the
fit has nothing to work with; `r` is never pinned.

On the built-in example, whose true γ-dynamic burst is known — bag pCa 8.39
(10% activation) from 0.35 to 1.15 s — the two modes land in different places,
on the same 20-iteration budget:

| | final cost | recovered bag burst | γ-static trace |
|---|---|---|---|
| `'receptor'` (default) | **0.043** | pCa 8.63, 0.14 → 1.77 s — level close, burst too long | corr 0.67 with the truth |
| `'firing'` | 0.189 | pCa 6.28, 0.42 → 1.80 s — **~2 pCa too strong**, burst too long | corr 0.16 with the above |

Neither mode recovers the burst *timing* well on this budget: the bag is driven
low, so its burst is a small part of the trace. The receptor fit gets the bag
**level** about right; the firing fit overdrives the bag by about 2 pCa, and its
γ-static waveform barely resembles the receptor fit's (correlation 0.16).
Perturbing only the bag pCa about the receptor solution shows part of why — the
firing objective moves 0.14 across the bag's whole range where the receptor
objective moves 0.30, so it is roughly half as sensitive to the parameter, and
flat objectives do not get optimized well. Prefer the default unless you
specifically want the generator in the loop.

If you want the spike generator in the loop anyway, switch **Optimize by fitting**
to *firing rate* in the app, or pass `opts.fitTarget = 'firing'` in code. The cost
is mean-normalized in both cases.

### How γ-static is modelled

`opts.gammaStatic` (and the app's **gamma-static model** dropdown):

| mode | parameters | use it when |
|---|---|---|
| `'bspline-free'` **(default)** | 8 | any protocol. 5 control points spread across the trial, spline-interpolated, no periodicity assumed — it can express a **constant** (all points equal), a **ramp** (monotonic points) or any smooth shape |
| `'bspline-periodic'` | 8 | the protocol really is cyclic. The manuscript's construction: one cycle tiled, with the last control point tied to the first. Needs `opts.cyclePeriod` |
| `'constant'` | 4 | you only want a single γ-static level. Fastest |

The periodic variant is not merely the restricted case — when your data *is*
cyclic it is the **better** model, because five numbers then describe every
cycle, and the fit cannot chase cycle-to-cycle noise. It is what the manuscript
uses for gait. But it forces the waveform to return to where it started and
needs a cycle period, so it is wrong for a ramp-and-hold or a step.

The tutorial will not infer the cycle period from your data — you have to state
it, in the app's **Cycle period (s)** box or `opts.cyclePeriod`.

### How γ-dynamic is modelled

`opts.gammaDynamic` (and the app's **gamma-dynamic model** dropdown):

| mode | γ-dynamic parameters | what it is |
|---|---|---|
| `'pulse'` **(default)** | 3 | a rectangular burst: bag pCa, onset (s), offset (s) |
| `'bspline-free'` | 5 | 5 control points across the trial, as for γ-static |
| `'bspline-periodic'` | 5 | one cycle tiled — the manuscript's Figure 1D form. Needs `opts.cyclePeriod` |

The B-spline modes replace the burst's 3 parameters with 5 control points, so a
fit with a B-spline γ-static has 10 parameters in all. They can express a
gradual or repeated bag drive that an on/off burst cannot, at the cost of two
more parameters. The B-spline starts low and flat (pCa 8.0 at every point),
because the bag is strong and a little γ-dynamic goes a long way.

### Solver

`opts.solver` (and the app's **Solver** dropdown) chooses between:

- **`'fmincon'`** (default). On the built-in example, 20 iterations: cost
  0.538 → 0.043 in ~62 s.
- **`'patternsearch'`** — what the manuscript uses. Derivative-free, so it copes
  better with the stepped cost you get in `'firing'` mode, and worth trying if a
  fit looks like it stalled. Same budget: 0.538 → 0.084 in ~72 s.

fmincon is ahead here on both counts, but the two are within a factor of two.
Try both if a fit matters.

> The built-in example's `targetFiring` is generated as a rectified-linear function
> of `r` (`rate = a*(r - threshold)`), not by running the toolbox spike generator —
> which clips at 250 spikes/s wherever the drive is strong (9% of this example's
> trace at its low drive, most of it at higher drive), and a clipped target is
> unrepresentative of a real recording. See `compute/exampleUserData.m`.


## The built-in example

`exampleUserData()` generates a known model run so both actions work without a
file. Its true drive is:

| | |
|---|---|
| chain (γ-static) | a smooth rise and fall sweeping **10–60%** activation |
| bag (γ-dynamic) | a **10%** burst from 0.35 to 1.15 s |
| α (extrafusal) | constant 35% |

Two deliberate choices. γ-static **varies in time**, so the B-spline modes have a
shape to recover — with a constant truth every γ-static mode scores the same and
the spline looks pointless. And the bag is kept **low**: it drives `r` far harder
than the chain does, and at a high bag level `rms(r_d)` is several times
`rms(r_s)`, so the chain's contribution is swamped. At 10% the ratio is ~1.2, and
both components are visible in the trace.

With 20 iterations, fitting the receptor potential:

| γ-static model | parameters | cost |
|---|---|---|
| `bspline-free` | 8 | **0.043** |
| `bspline-periodic` (cycle 1.67 s) | 8 | **0.047** |
| `constant` | 4 | 0.122 |

Both splines beat the single-level fit, which is the example doing its job. With
a B-spline γ-dynamic as well (`gammaDynamic = 'bspline-free'`, 10 parameters)
the same budget reaches 0.082 — two more parameters to fit, and this example's
true γ-dynamic is a burst, which a burst describes exactly. Note
`targetFiring` here is rectified-linear in `r` rather than the toolbox spike
generator's output — see the comment in `compute/exampleUserData.m` for why.

## What gets saved

**Save results…** (or `saveUserResults(base, res, 'optimize')`) writes a `.mat`
and a `.csv`. The `.mat` records how the fit was configured, because without it
the file is ambiguous:

| field | why it matters |
|---|---|
| `fitTarget`, `fitUnits` | `fitOptimised` is a **receptor potential** in the default `'receptor'` mode and a **firing rate** in `'firing'` mode |
| `gammaStatic`, `gammaDynamic`, `cyclePeriod` | `paramNames` has 8 entries for the B-spline γ-static with the burst, 4 for `'constant'`, and 2 more when γ-dynamic is a B-spline |
| `solver` | which optimizer produced it |

The CSV names its fit columns to match: `fitOptimised_r_au` for a receptor fit,
`fitOptimised_sps` for a firing fit. `targetFiring_sps` is always your recording,
in spikes/s.

Both fit traces are stored in **raw** model units, not mean-normalized. The app
plots them normalized, because that is what the cost actually minimized — showing
raw traces overlaid would imply an absolute match that was never fitted.
