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
| `alphaAct` | extrafusal (α-motor) activation | `0..1` or `0..100` % | optional |
| `chainAct` | γ-static (chain) activation | `0..1` or `0..100` % | forward |
| `bagAct` | γ-dynamic (bag) activation | `0..1` or `0..100` % | forward |
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
bagAct     = 90 * (t>0.3 & t<1.1);                     % gamma-dynamic burst
save('myForward.mat', 't','mtuLength','alphaAct','chainAct','bagAct');

% OPTIMIZE: length + recorded firing -> gamma
t            = 0:0.001:2;
mtuLength    = 1250 + 100*max(0, min(1, (t-0.3)/0.8));
alphaAct     = 35 * ones(size(t));
targetFiring = myRecordedIaRate;                       % spikes/s, same length as t
save('myOptimize.mat', 't','mtuLength','alphaAct','targetFiring');
```

## What the optimize mode fits

For arbitrary protocols (not just periodic gait data), the optimize mode fits a
compact, general gamma parameterization:

- γ-static level (constant chain pCa),
- γ-dynamic burst magnitude (bag pCa),
- burst onset and offset (s),

by minimizing a **mean-normalized** RMSE against your recording — see below —
between the model's response and your
target. This differs from the `Gamma optimization` tab, which fits the periodic
5-control-point B-spline used for the manuscript's gait data.

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

The cost is **mean-normalized**: each trace is divided by its own mean before the
RMSE, so only *shape* is compared.

```matlab
mN = model / mean(model);   dN = data / mean(data);
cost = sqrt(mean((mN - dN).^2));
```

This is the cost the manuscript minimizes
(`objFuncWithFixedTiming_Bspline_5cp_normSmooth.m` in `gammaDriveOptimization`),
and it matters for a specific reason. Comparing **absolute** traces makes the cost
punish any difference in overall level, and that punishment lands on the
gamma-**dynamic** drive: once gamma-static already matches the recorded amplitude,
adding bag drive only pushes the model above the data, so the optimizer turns it
off and the burst timing stops being identifiable. Normalizing both traces removes
that penalty.

### Why the default fits the receptor potential

Because the cost is shape-only, the model's **receptor potential** `r` can be
fitted directly to your recorded **firing rate**, despite the units differing.
Below the spike generator's ceiling the two are proportional — `rate = r/threshold`
— and a proportional factor is exactly what mean-normalization removes.

Simha et al. find the normalized fit gives similar answers either way, and fitting
`r` keeps the spike generator's limits (a 250 spikes/s ceiling at `dt = 1 ms`, and
rate quantization to `1/(k*dt)`) out of the objective entirely. Where the model's
firing is pinned at the ceiling, the objective is flat and the fit has nothing to
work with; `r` is never pinned.

If you want the spike generator in the loop anyway, switch **Optimize by fitting**
to *firing rate* in the app, or pass `opts.fitTarget = 'firing'` in code. The cost
is mean-normalized in both cases.

### Solver

`opts.solver` (and the app's **Solver** dropdown) chooses between:

- **`'fmincon'`** (default) — faster, and it converges better on this compact
  four-parameter fit. On the built-in example: cost 0.395 → 0.101.
- **`'patternsearch'`** — what the manuscript uses. Derivative-free, so it copes
  better with the stepped cost you get in `'firing'` mode, and worth trying if a
  fit looks like it stalled. Slower per iteration (it polls 2N points), so it
  needs a larger `maxIter`: at 12 it undershoots (cost 0.395 → 0.243) in a third
  of the time.

> The built-in example's `targetFiring` is generated as a rectified-linear function
> of `r` (`rate = a*(r - threshold)`), not by running the toolbox spike generator —
> which would clip 65–90% of the trace at 250 spikes/s and make the example
> unrepresentative of a real recording. See `compute/exampleUserData.m`.
