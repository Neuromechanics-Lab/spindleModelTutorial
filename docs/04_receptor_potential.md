# 4. From force to the Ia receptor potential

The Ia afferent innervates both intrafusal fibers and transduces their
mechanical state into a **receptor potential** `r`, which drives firing. The
model (`sarc2spindle_20240310.m`) builds `r` from two components:

```
   r_s  (static)   =  kFc · (chain force)
   r_d  (dynamic)  =  kFb · (bag force)  +  kYb · (bag yank)
   r    (total)    =  r_s + r_d
```

where **yank** is the time-derivative of bag force, `dF/dt`.

## Why two components

- **`r_s` — static / length signal.** The chain fiber's force tracks how much
  the fiber is stretched, so `r_s` encodes **length**. Gain `kFc`.
- **`r_d` — dynamic / velocity signal.** The bag fiber contributes both its
  force (`kFb`) and, crucially, its **yank** (`kYb`). Because yank is largest
  while the fiber is *moving*, `r_d` produces the sharp burst at movement onset
  that makes real Ia afferents so velocity-sensitive.

Forces and yank are half-wave rectified (negative values set to zero), lightly
low-pass filtered, and scaled, before being summed. A **receptor threshold** can
then be subtracted from `r` (`r = r - threshold`, negatives clipped to zero).

> Note this threshold belongs to the **transduction step**, not to the spike
> generator: it is applied inside `sarc2spindle` and so changes the receptor
> potential itself. That is why moving it in the Playground visibly reshapes the
> `r` trace. The integrate-and-fire has its own, separate threshold — see
> `examples/spikesFromReceptorPotential.m`.

## Occlusion (optional)

Real Ia endings branch onto both fibers, and the branches can **compete** rather
than simply add. With **occlusion** on, whichever component (static or dynamic)
is momentarily smaller is attenuated (to 30%, chosen to match Banks et al.,
1997), rather than the two summing linearly. Toggle it in the Playground to see
how it reshapes `r`.

## From receptor potential to spikes

`r` is where this tutorial stops: it is what the biophysical model predicts, and
everything the spindle does to the stretch is already in it.

Converting `r` into afferent spikes is a separate modelling choice. The toolbox
ships one — `integrateAndFire_v2.m`, which integrates `r` and emits a spike each
time the integral crosses a threshold, subject to a refractory period. Its output
is plotted in exactly one place — the **Guided walkthrough**'s "from receptor
potential to spikes" step — so you can see what it does; no other panel in either
window shows it. Two limits set by the time step are why it is confined there at
`dt = 1 ms`:

- **Ceiling.** The refractory period is enforced by counting samples, which costs
  an extra `2*dt` on top of it, so the maximum rate is `1/(refractory + 2*dt)` =
  **250 spikes/s**, not the 500 the 2 ms refractory implies.
- **Quantisation.** Spikes land on samples, so every interval is a whole number of
  them and the rate can only be `1/(k*dt)`: 250, 200, 167, 143, 125, … The steps
  get coarser the faster the firing.

Any realistic gamma drive pushes `r` past that ceiling and the firing trace goes
flat, but this reflects a limitation of the time step used in simulation rather
than anything about the model.

`examples/spikesFromReceptorPotential.m` runs the generator on any simulation,
checks directly for saturation, and documents what to change — the gain/threshold
ratio, `dt`, or the generator itself (a time-based refractory removes the
`dt`-dependence; interpolating the threshold crossing removes the quantisation and
the downward bias that comes with it).
