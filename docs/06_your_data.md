# 6. Bringing your own data

The **Your data** tab (and the compute functions behind it) let you run the
model on inputs *you* supply, in two directions.

## The two modes

- **Forward** — you have the muscle **length** and the fiber **activations**, and
  you want the model's **firing**:
  `length + activations → forces → receptor potential → firing`.
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
% FORWARD: length + activations -> firing
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

by minimizing the RMSE between the model's (smoothed) firing rate and your
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
