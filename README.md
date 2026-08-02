# Muscle Spindle Model — Interactive Tutorial

An interactive, tutorial-style MATLAB app for the biophysical muscle spindle
model of [Simha et al. (2026)](https://doi.org/10.64898/2026.07.03.736206). Move
a parameter and immediately see how fiber forces, the Ia receptor potential, and
the cross-bridge distribution respond — then fit the model to your own data.

**No MATLAB?** Download a prebuilt app for macOS or Windows from the
[latest release](../../releases/latest).

**Author:** Surabhi Simha · Neuromechanics Lab, Emory University

---

## Quick start

Clone the repo and, from MATLAB in this folder:

```matlab
launchSpindleTutorial       % launcher: choose Tutorial (Learn) or Toolkit (Apply)
```

Or open a window directly, skipping the menu:

```matlab
launchSpindleTutorialApp    % Interactive Tutorial (Overview, Walkthrough, Playground)
launchSpindleToolkit        % Analysis Toolkit (Gamma optimization, Your data)
```

Start on the **Overview** tab, work through the **Guided walkthrough**, then
experiment in the **Playground**. To fit the model to data, open the **Analysis
Toolkit** window.

## Requirements

**Just clone and run** — the model code is vendored (see
[Vendored model code](#vendored-model-code)). You need:

- **MATLAB R2020a or later** (uses `uifigure` apps). Runs on macOS and Windows.
- **Signal Processing Toolbox** — `butter`/`filtfilt`, used inside `sarc2spindle`.
- **Optimization Toolbox** — `fmincon`, the `Your data` tab's default solver.
- *Optional:* **Global Optimization Toolbox** — `patternsearch`, the manuscript's
  solver and the `Gamma optimization` tab's default. Without it that tab falls
  back to `fmincon` automatically.
- *Optional:* **Parallel Computing Toolbox** — the "Use parallel" checkbox
  spreads `patternsearch`'s poll points across workers, ~2.6× here.

## The two windows

### Interactive Tutorial (Learn)

| Tab | What it does |
|-----|--------------|
| **Overview** | What the model is and how the pipeline fits together. |
| **Guided walkthrough** | A narrated, five-step tour: inputs → cross-bridge distribution → receptor potential + yank → from receptor potential to spikes → the whole pipeline. |
| **Playground** | Free exploration. Sliders for the stretch protocol, extrafusal MTU, gamma drive, fiber kinetics, and transduction gains, plus a cross-bridge distribution scrubber. Every panel is badged **INPUT / INTERMEDIATE / OUTPUT**. |

### Analysis Toolkit (Apply)

| Tab | What it does |
|-----|--------------|
| **Gamma optimization** | Recover a *known* gamma drive from a simulated Ia, using the manuscript's own B-spline routines. |
| **Your data** | Run the model on your own inputs: length + activations → receptor potential, or length + recorded Ia firing → the gamma drive that reproduces it. |

Both windows share one codebase but open independently, so the Learn window stays
light and never touches the optimization code. Everything they plot comes from the
**real** toolbox functions (`musTenDriver20250627`,
`sarcSimDriverIntrafusal20250627`, `sarc2spindle_20240310`,
`integrateAndFire_v2`) — nothing is re-implemented.

## Bring your own data

The **Your data** tab reads a `.mat` file with these variables (or a single
struct named `data` with these fields) — all time-series the same length as `t`:

| Variable | Meaning | Needed for |
|----------|---------|-----------|
| `t` | time (s), uniform step — **use ~1 ms** | always |
| `mtuLength` *or* `fascicleLength` | muscle length, **any units** | always |
| `restingLength` | resting length, **same units** as your length trace | recommended |
| `alphaAct` | extrafusal (α) activation, `0..1` or `0..100` % | optional |
| `chainAct`, `bagAct` | γ-static / γ-dynamic activations | **forward** run |
| `targetFiring` | recorded Ia firing rate (spikes/s) | **optimize** run |
| `tendonStiffness` | scalar (default 5000) | optional |

Click **Load built-in example** to try both actions without a file.
[`examples/runMyOwnData.m`](examples/runMyOwnData.m) does the same from a script.

Units, time-step requirements, what the optimizer fits, and how results are
saved: **[docs/06_your_data.md](docs/06_your_data.md)**.

## Documentation

The written narrative mirrors the in-app text and is the place for the details:

| Doc | Covers |
|-----|--------|
| [01_overview.md](docs/01_overview.md) | What the model is and the full pipeline |
| [02_fibers_and_forces.md](docs/02_fibers_and_forces.md) | Bag and chain fibers, and where force comes from |
| [03_crossbridge_distribution.md](docs/03_crossbridge_distribution.md) | The cross-bridge population and how it evolves |
| [04_receptor_potential.md](docs/04_receptor_potential.md) | Force + yank → `r`, and **why the app stops at the receptor potential** |
| [05_gamma_optimization.md](docs/05_gamma_optimization.md) | Recovering gamma drive, and **how the fits are scored** |
| [06_your_data.md](docs/06_your_data.md) | Running the model on your own recordings |
| [07_differences_from_manuscript.md](docs/07_differences_from_manuscript.md) | Every known difference from the published workflow, and what it costs |

Maintainer tasks — building the standalone apps, re-syncing `vendor/` — are in
[MAINTAINING.md](MAINTAINING.md).

## Vendored model code

This repository is **self-sufficient**: the model files it depends on are
snapshotted under [`vendor/`](vendor/) — 12 from
`matlabMuscleSpindleModellingTools` and 2 from `gammaDriveOptimization`, at the
commits recorded in `vendor/VENDOR_INFO.txt`.

If you have those repositories checked out as siblings they are used in
preference to the vendored copies, so your edits there take effect immediately.
Point elsewhere with `SPINDLE_TOOLBOX_DIR` / `GAMMA_OPT_DIR` if they live
somewhere else. Re-syncing is a maintainer task — see
[MAINTAINING.md](MAINTAINING.md).

## How it's organized

```
spindleModelTutorial/
├── launchSpindleTutorial.m     launcher menu (choose Learn or Apply)
├── launchSpindleTutorialApp.m  open the Tutorial (Learn) window directly
├── launchSpindleToolkit.m      open the Analysis Toolkit (Apply) window directly
├── launchLearnAppDeployed.m    entry point for the COMPILED standalone Learn app
├── setupTutorialPaths.m        adds the model + local folders to the path
├── app/                        the two windows + their shared base class
├── compute/                    plain, headless-testable functions (no GUI)
├── examples/                   editable scripts: your own data, spikes from r
├── build/                      compile the Learn window (MATLAB Compiler)
├── data/                       activation curve + the Overview schematic
├── vendor/                     snapshotted model code (see above)
├── tools/                      maintainer scripts (re-sync vendor/)
├── docs/                       the written narrative
└── tests/smokeTest.m           headless checks for the compute layer
```

The `compute/` layer is deliberately GUI-free so the science can be tested and
reused independently of the app:

```matlab
setupTutorialPaths(); smokeTest
```

## A note on parameters

`compute/defaultTutorialParams.m` is the single source of truth for defaults.
Fiber-kinetics defaults mirror `getDefaultSarcB`/`getDefaultSarcC`. The pCa
convention throughout is the model's own: **lower pCa = stronger activation**
(pCa 9 ≈ silent, pCa 4.5 ≈ maximal).

## References

- Simha SN, Ting LH (2024). Intrafusal cross-bridge dynamics shape history-dependent
  muscle spindle responses to stretch. *Experimental Physiology* 109(1):112–124.
  [doi:10.1113/EP090767](https://doi.org/10.1113/EP090767)
- Simha S, Sawicki G, Cope T, Ting L (2026). The mammalian muscle spindle as a
  tunable feedback controller in locomotion. *bioRxiv* 2026.07.03.736206 (preprint).
  [doi:10.64898/2026.07.03.736206](https://doi.org/10.64898/2026.07.03.736206)
- Blum KP, Campbell KS, Horslen BC, Nardelli P, Housley SN, Cope TC, Ting LH (2020).
  Diverse and complex muscle spindle afferent firing properties emerge from
  multiscale muscle mechanics. *eLife* 9:e55177.
  [doi:10.7554/eLife.55177](https://doi.org/10.7554/eLife.55177)

## License

MIT — see [LICENSE](LICENSE). If you use this in published work, please cite the
model papers above.
