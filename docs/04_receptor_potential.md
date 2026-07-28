# 4. From force to the Ia receptor potential

The Ia afferent wraps around both intrafusal fibers and transduces their
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
low-pass filtered, and scaled, before being summed. A **firing threshold** can
be subtracted from `r`.

## Occlusion (optional)

Real Ia endings branch onto both fibers, and the branches can **compete** rather
than simply add. With **occlusion** on, whichever component (static or dynamic)
is momentarily smaller is attenuated (to 30%, chosen to match Banks et al.,
1997), rather than the two summing linearly. Toggle it in the Playground to see
how it reshapes `r`.

## From receptor potential to firing

`integrateAndFire.m` converts the continuous `r` into discrete afferent spikes:
it integrates `r` over time and emits a spike whenever the integral crosses
threshold (with a short refractory period). The instantaneous firing rate (IFR)
is what you would compare against recorded Ia spike trains.

## Try it

In the **Playground**, watch the receptor-potential plot (blue `r_s`, orange
`r_d`, black total `r`) as you:

- Increase **Yank gain kYb** → the onset transient in `r_d` grows.
- Increase **Static gain kFc** → the sustained `r_s` level rises.
- Turn on **Branch occlusion** → the smaller component gets suppressed instant
  by instant.
