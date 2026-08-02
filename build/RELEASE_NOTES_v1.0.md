# Spindle Tutorial v1.0

Interactive companion to the biophysical muscle spindle model of
[Simha et al. (2026, bioRxiv)](https://doi.org/10.64898/2026.07.03.736206).

## Downloads — no MATLAB needed

| File | Platform | Runtime it fetches |
|------|----------|--------------------|
| `SpindleTutorialInstaller_mac.zip` | macOS | MATLAB Runtime **R2022b** |
| `SpindleTutorialInstaller_win.zip` | Windows 10/11 (64-bit) | MATLAB Runtime **R2026a** |

Unzip, run the installer, and launch **Spindle Tutorial**. No MATLAB license
required.

**These are *web* installers** — small, because they download the free MATLAB
Runtime from MathWorks during installation. So you need an internet connection
while installing, and it takes a while (the Runtime is several GB). Once
installed, the app runs offline. The Runtime version is pinned per build, which
is why the two platforms list different versions.

**First launch — the app is not code-signed:**

- **macOS:** you'll see an "unidentified developer" warning. **Right-click the
  app → Open** → *Open*. Once only.
- **Windows:** SmartScreen may say the publisher is unrecognized. Choose
  **More info → Run anyway**.

## What's in the app

- **Overview** — what the model is and how the pipeline fits together.
- **Guided walkthrough** — a narrated, five-step tour: inputs (length +
  activation) → cross-bridge distribution → receptor potential + yank → from
  receptor potential to spikes → the whole pipeline.
- **Playground** — move any parameter (stretch protocol, extrafusal α + tendon,
  γ drive, fiber kinetics, transduction gains) and watch every signal update,
  with a scrubber to step the cross-bridge distribution through time.

The model's output here is the Ia **receptor potential**. Turning it into spikes
is a separate step, left to `examples/spikesFromReceptorPotential.m` — the
integrate-and-fire the toolbox ships is refractory-limited to 250 spikes/s at
`dt = 1 ms`, which any realistic γ drive saturates, so plotting it would show
the time step rather than the spindle. See
[docs/04](https://github.com/SurabhiSimha/spindleModelTutorial/blob/main/docs/04_receptor_potential.md).

## For MATLAB users

If you have MATLAB you don't need the installers above — run it from source and
you also get the **Analysis Toolkit**: recover γ drive from a simulated Ia, or
fit the model to **your own** recordings. The standalone app does not include it.

Either clone the repository:

```bash
git clone https://github.com/SurabhiSimha/spindleModelTutorial.git
cd spindleModelTutorial
```

…or download **Source code (zip)** at the bottom of this release and unzip it.
Then, in MATLAB:

```matlab
launchSpindleGUI          % pick Interactive Tutorial (Learn) or Analysis Toolkit (Apply)
```

**Nothing else to install** — the muscle spindle model code is included under
`vendor/`. You need MATLAB R2020a or later with the **Signal Processing** and
**Optimization** Toolboxes; the Analysis Toolkit also uses **Global
Optimization** (for `patternsearch`) and benefits from **Parallel Computing**.

Full details in the
[README](https://github.com/SurabhiSimha/spindleModelTutorial#readme). How this
tutorial's workflow differs from the published pipeline is listed in
[docs/07](https://github.com/SurabhiSimha/spindleModelTutorial/blob/main/docs/07_differences_from_manuscript.md).

## Citation

- Simha SN, Ting LH (2024). Intrafusal cross-bridge dynamics shape
  history-dependent muscle spindle responses to stretch. *Experimental
  Physiology* 109(1):112–124. doi:10.1113/EP090767
- Simha S, Sawicki G, Cope T, Ting L (2026). The mammalian muscle spindle as a
  tunable feedback controller in locomotion. *bioRxiv* 2026.07.03.736206.
  doi:10.64898/2026.07.03.736206
- Blum KP, et al. (2020). Diverse and complex muscle spindle afferent firing
  properties emerge from multiscale muscle mechanics. *eLife* 9:e55177.
  doi:10.7554/eLife.55177

Licensed under the GNU Affero General Public License v3 or later (AGPL-3.0-or-later).
Clone, run and modify freely; the copyleft applies if you redistribute a modified
version or serve one over a network.
