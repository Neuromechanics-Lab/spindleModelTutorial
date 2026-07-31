# 1. Overview

A **muscle spindle** is a stretch sensor embedded among muscle fibers. It
reports muscle length and its rate of change to the nervous system through the
firing of its **Ia afferent**. This model predicts that Ia signal *from first
principles* — starting from the molecular cross-bridges inside the spindle's own
tiny muscle fibers.

## The pipeline

```
   length change  +  alpha (α) drive
                     │
                     ▼
     EXTRAFUSAL muscle-tendon unit           ← α-driven muscle in series with tendon
                     │
                     ▼
          fascicle length                     ← what the spindle actually feels
                     │  +  gamma (γ) drive
                     ▼
        bag & chain intrafusal fibers         ← cross-bridge (myosin) mechanics
                     │
                     ▼
       fiber force  and  yank (dF/dt)
                     │
                     ▼
     Ia receptor potential  r = r_s + r_d
                     │
                     ▼
         Ia receptor potential
```

(The cross-bridge distribution that generates fiber force is the mechanistic
core of the fiber stage — see `03_crossbridge_distribution.md` — but it is an
*internal* detail of the fiber, not a separate stage of the signal pipeline.)

The muscle-tendon unit matters because the tendon is compliant: not all of the
length change applied to the MTU reaches the muscle fascicle, and α drive to the
extrafusal muscle changes how the length is shared between muscle and tendon. The
spindle fibers lie in parallel with the extrafusal muscle, so they inherit the
*fascicle* length.

Each stage is a real function in `matlabMuscleSpindleModellingTools`:

| Stage | Function |
|-------|----------|
| MTU (α + tendon) → fascicle length | `musTenDriver20250627` |
| Fibers → forces & cross-bridge distributions | `sarcSimDriverIntrafusal20250627` |
| Forces + yank → receptor potential | `sarc2spindle_20240310` |
| Receptor potential → spikes | `integrateAndFire_v2` (not plotted; see `examples/spikesFromReceptorPotential.m`) |

## Two fibers, two roles

The spindle model contains two intrafusal fiber types working in parallel:

- **Bag fiber** — driven by **gamma-dynamic** fusimotor neurons. Fast
  cross-bridge kinetics give it a large, *transient* force and a big **yank**
  (rate of force change) at the onset of stretch. This produces the
  velocity-sensitive **dynamic** response.
- **Chain fiber** — driven by **gamma-static** fusimotor neurons. Slower,
  steadier force that tracks *how much* the fiber is stretched. This produces
  the length-sensitive **static** response.

The Ia afferent senses both, and the model combines them into a single receptor
potential.

## Where to go next

- **`02_fibers_and_forces.md`** — how a fiber turns stretch + activation into force.
- **`03_crossbridge_distribution.md`** — the distribution that generates force.
- **`04_receptor_potential.md`** — force and yank → the Ia receptor potential.
- **`05_gamma_optimization.md`** — inferring fusimotor drive by optimization.

Or just launch the app (`launchSpindleTutorial`) and start with the **Guided
walkthrough** tab.
