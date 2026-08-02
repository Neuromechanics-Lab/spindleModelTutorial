# 3. The cross-bridge distribution

This is the mechanistic heart of the model. Active force is not a lumped
equation — it emerges from a **population of myosin cross-bridges**, each bound
to actin at some displacement `x`.

## Displacement bins

The model tracks how many cross-bridges are bound at each displacement, across a
grid of **displacement bins** (`x_bins`, roughly −20 to +20 nm). `x` is a
*length* — how far a bound head is stretched from its neutral position, in
nanometres — not a strain: it is never divided by a reference length, and it
carries units. This is `bin_pops`: a distribution of bound heads over
displacement. Each bound head behaves like a spring, so the fiber's active force
is the sum, over all bins, of (number of heads) × (their displacement +
power-stroke):

```
   cb_force ∝ Σ  bin_pops(x) · (x + power_stroke)
```

## How the distribution evolves

Two things change the distribution at every time step:

1. **Kinetics (attachment / detachment).** Heads attach at a rate `f` and
   detach at a displacement-dependent rate `g`. Calcium (pCa) gates how much
   actin is available to bind. This is integrated with an ODE solver each step
   (`evolve_cbDist`). More activation → more bound heads → more force.
2. **Movement (shifting).** When the fiber changes length, the whole
   distribution is **shifted** along the displacement axis (`shift_cbDist`):
   stretching drags bound heads to positive displacement, raising their spring
   force immediately.
   A `compliance_factor` accounts for filament compliance (only part of the
   length change reaches the cross-bridges).

The interplay is what makes the spindle *dynamic*: a stretch first **shifts** the
existing bound heads (fast force rise = high yank), then kinetics **relax** the
distribution back toward a new steady state (force adaptation during the hold).

## Bag vs chain

The bag and chain fibers use different rate parameters (`f`, `g`), so their
distributions evolve differently:

- **Bag** — attaches readily and detaches such that a stretch produces a big,
  short-lived shift → large transient force and yank.
- **Chain** — reaches a steadier bound population → force that better reflects
  the held length.

## Try it

In the **Playground**, run a **ramp-and-hold** and then **drag the scrubber**
under the plots. Watch the bag (orange) and chain (blue) distributions:

- At rest: a modest bound population near `x = 0`.
- During the ramp: the distribution **shifts right** — this is the force rise.
- During the hold: it **relaxes** as kinetics rebalance — this is adaptation.

Then change **Bag detach rate g** and re-run: faster detachment collapses the
transient more quickly.
