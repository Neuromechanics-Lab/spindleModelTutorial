# 2. Intrafusal fibers and their forces

Each intrafusal fiber is modelled as a **half-sarcomere** — the fundamental
contractile unit. Its force has two parts:

```
   fiber force  =  cross-bridge (active) force  +  passive force
```

- **Passive force** comes from the fiber's parallel elasticity (titin and
  connective tissue). In the model it grows with how far the half-sarcomere is
  stretched beyond its slack length:
  `passive_force = k_passive * (hs_length - hsl_slack)`.
- **Active (cross-bridge) force** comes from myosin heads bound to actin, each
  acting like a tiny strained spring. This is where activation and movement
  history enter — see `03_crossbridge_distribution.md`.

## What activation does

Fibers are activated by **gamma (fusimotor) drive**, expressed in the model as
**pCa** (`= -log10[Ca²⁺]`). The convention is:

> **lower pCa → more calcium → stronger activation.**
> pCa ≈ 9 is essentially silent; pCa ≈ 4.5 is near-maximal.

More activation means more myosin heads are available to bind, so a stretched
fiber develops more active force.

- The **chain** fiber's pCa is set by **gamma-static** drive (a maintained level).
- The **bag** fiber's pCa is set by **gamma-dynamic** drive (a phasic burst).

In the code, `makeGammaDrive.m` turns the gamma-drive parameters into the
per-time-step pCa traces `sarcB.pCa` (bag) and `sarcC.pCa` (chain) that the
simulation uses.

## What movement does

The stretch protocol (`makeLengthCommand.m`) sets the length of the **extrafusal
muscle-tendon unit** over time — a **ramp-and-hold**, a **sinusoid**, or a
**triangle**. That MTU (an α-driven muscle in series with a compliant tendon;
`runExtrafusalMTU.m` → `musTenDriver20250627`) produces the **fascicle length**,
and the intrafusal fibers inherit it. Because the bag and chain fibers lie
mechanically in parallel, they experience the *same* fascicle length change.
Their forces differ only because their cross-bridge kinetics differ:

- The **bag** fiber generates a sharp force transient when the
  fiber is moving, then relaxes.
- The **chain** fiber settles to a more sustained force set by
  the new length.

## Try it

In the **Playground**:

- Increase **Amplitude** or shorten **Ramp duration** → bigger, faster force
  transients (especially in the bag fiber).
- Lower the **bag burst pCa** → stronger bag activation → larger active force.
- Change **Bag/Chain passive stiffness** → shifts the baseline force the fiber
  holds at rest.
