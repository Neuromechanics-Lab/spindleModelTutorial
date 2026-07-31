# Muscle Spindle Model — Interactive Tutorial

An interactive, tutorial-style MATLAB app for the biophysical muscle spindle
model of [Simha et al. (2026)](https://doi.org/10.64898/2026.07.03.736206). It
lets you *play* with the model — move a parameter and immediately see how
individual fiber forces, the Ia receptor potential, and the cross-bridge
distribution respond — and it walks you through how the model is put together
and how fusimotor (γ) drive is inferred by fitting the model to data.

**No MATLAB?** Download a prebuilt app for macOS or Windows from the
[latest release](../../releases/latest).

**Author:** Surabhi Simha · Neuromechanics Lab, Emory University

---

## What's inside

`launchSpindleTutorial` opens a small launcher with two focused windows:

### Interactive Tutorial (Learn)

| Tab | What it does |
|-----|--------------|
| **Overview** | What the model is and how the pipeline fits together. |
| **Guided walkthrough** | A narrated, five-step tour: inputs (length + activation) → cross-bridge distribution (pre/early/post-stretch snapshots, with cursors) → receptor potential + yank → from receptor potential to spikes → the whole pipeline. |
| **Playground** | Free exploration, with a **Reset** button to return every parameter to its starting value. Sliders for the stretch protocol, the **extrafusal MTU** (α drive + tendon stiffness), gamma drive (levels in **% activation**, matching the plot; optional sinusoidal γ-static with amplitude in % and phase in seconds), fiber kinetics, and transduction gains. Plots length, **activation (%)**, fiber forces, the **Ia receptor potential** (the model's output), and a **cross-bridge distribution scrubber**. Every panel is badged **INPUT / INTERMEDIATE / OUTPUT**. |

### Analysis Toolkit (Apply)

| Tab | What it does |
|-----|--------------|
| **Gamma optimization** | Generate a target Ia from *known* gamma drive, then watch an optimizer recover it — including the **gamma-static B-spline waveform**, drawn against the truth. Uses the manuscript's own B-spline routines. |
| **Your data** | Run the model on **your own** inputs (see [file format](#bring-your-own-data-your-data-tab)): length + activations → receptor potential (forward), or length + recorded Ia firing → the gamma drive that reproduces it (optimize). A built-in example demonstrates both. |

The two windows share one codebase (so they stay visually consistent) but open
independently, so the Learn window stays light and never touches the optimization
code. Everything each window plots is produced by the **real** toolbox functions
(`musTenDriver20250627`, `sarcSimDriverIntrafusal20250627`,
`sarc2spindle_20240310`, `integrateAndFire_v2`), and the optimization tab calls
`gammaDriveOptimization`'s own B-spline routines. Nothing is re-implemented — you
are driving the published model.

---

## How the fits are scored

Both optimizers minimize a **mean-normalized** RMSE on a **single** trace — each
divided by its own mean, then RMSE — which is the cost the manuscript uses
(`objFuncWithFixedTiming_Bspline_5cp_normSmooth.m`). One combined signal, because
that is all a real recording gives you: the gamma-optimization demo could score
its static and dynamic components separately (its target is simulated, so it knows
both), but that would hand the demo information no experiment has. The honest
consequence is that the bag burst recovers and the gamma-static waveform largely
does not — see [docs/05_gamma_optimization.md](docs/05_gamma_optimization.md). Comparing absolute traces
penalizes any bag drive that lifts the model above the data, so the optimizer turns
gamma-dynamic off and the burst timing stops being identifiable; normalizing both
traces removes that.

Because the cost is shape-only, **Your data** fits the model's *receptor potential*
to your recorded *firing rate* by default: below the spike generator's ceiling the
two are proportional, and that proportionality is what normalization cancels. It
also keeps the 250 spikes/s ceiling out of the objective. A switch (**Optimize by
fitting**, or `opts.fitTarget = 'firing'`) fits model firing instead if you want it.
Details in [docs/06_your_data.md](docs/06_your_data.md).

## Why the app stops at the receptor potential

The model's output is the Ia **receptor potential** `r`. Turning `r` into spikes
is a separate step, and the integrate-and-fire the toolbox ships
(`integrateAndFire_v2`) is limited by the time step in two ways at `dt = 1 ms`:
its ceiling is `1/(refractory + 2*dt)` = **250 spikes/s**, and because spikes land
on samples the rate is quantised to `1/(k*dt)` — 250, 200, 167, 143, … Any
realistic gamma drive saturates it, so the firing trace flattens and shows the
time step rather than the spindle.

So the app plots `r`, and **`examples/spikesFromReceptorPotential.m`** gives a
worked spike generator you can adapt: it runs on any simulation, checks for
saturation, and explains what to change.

## Differences from the manuscript

The tutorial calls the *same* model functions the manuscript does (vendored
verbatim in `vendor/`), but the workflow around them is simplified — most
importantly, the gamma-optimization demo fits a **simulated** target driven by a
**synthetic** sinusoidal MTU, with burst timing **fixed** rather than searched
over an outer 7×7 + 5×5 grid. Every known difference, and what each costs, is
listed in
[docs/07_differences_from_manuscript.md](docs/07_differences_from_manuscript.md).

## Requirements

**Just clone and run** — the model code this tutorial needs is included (see
[Vendored model code](#vendored-model-code) below). You need:

- **MATLAB R2020a or later** (uses `uifigure` apps). Runs on macOS and Windows.
- **Signal Processing Toolbox** — `butter`/`filtfilt`, used inside `sarc2spindle`.
- **Optimization Toolbox** — `fmincon`, used by the optimization tab.
- *Optional:* **Parallel Computing Toolbox** — the optimization tab's "Use
  parallel" checkbox speeds the fit by parallelizing finite differences.

## Vendored model code

This repository is **self-sufficient**: the muscle spindle model files it depends
on are vendored under [`vendor/`](vendor/) — 12 files from
`matlabMuscleSpindleModellingTools` (the model itself) and 2 from
`gammaDriveOptimization` (the B-spline γ routines used by the optimization tab).
They are **copies**, snapshotted at the commits recorded in
`vendor/VENDOR_INFO.txt`.

If you also have the **source repositories** checked out as siblings, they are
used automatically in preference to the vendored copies — so your edits there
take effect immediately:

```
<parent>/
├── matlabMuscleSpindleModellingTools/   <- used if present
├── gammaDriveOptimization/              <- used if present
└── spindleModelTutorial/                <- this repo (falls back to vendor/)
```

Point elsewhere with environment variables if needed:

```matlab
% macOS / Linux
setenv('SPINDLE_TOOLBOX_DIR', '/full/path/to/matlabMuscleSpindleModellingTools');
setenv('GAMMA_OPT_DIR',       '/full/path/to/gammaDriveOptimization');

% Windows
setenv('SPINDLE_TOOLBOX_DIR', 'C:\path\to\matlabMuscleSpindleModellingTools');
setenv('GAMMA_OPT_DIR',       'C:\path\to\gammaDriveOptimization');
```

Re-syncing those copies is a maintainer task — see
[MAINTAINING.md](MAINTAINING.md).

---

## Launch

From MATLAB, in this folder:

```matlab
launchSpindleTutorial       % launcher: choose Tutorial (Learn) or Toolkit (Apply)
```

Or open a window directly, skipping the menu:

```matlab
launchSpindleTutorialApp    % Interactive Tutorial (Overview, Walkthrough, Playground)
launchSpindleToolkit        % Analysis Toolkit (Gamma optimization, Your data)
```

Start on the **Overview** tab, work through the **Guided walkthrough**, then
experiment in the **Playground**. When you want to fit the model to data, open the
**Analysis Toolkit** window.

## Bring your own data (`Your data` tab)

The **Your data** tab runs the model on inputs you supply in a `.mat` file. Save
these variables (or a single struct named `data` with these fields) — all
time-series the **same length as `t`**:

| Variable | Meaning | Needed for |
|----------|---------|-----------|
| `t` | time (s), uniform step — **use ~1 ms** (see below) | always |
| `mtuLength` *or* `fascicleLength` | muscle length, **any units** (MTU is run through the tendon; fascicle is used as-is) | always |
| `restingLength` | scalar resting length **in the same units** as your length trace | recommended |
| `alphaAct` | extrafusal (α) activation, `0..1` or `0..100` % — **omitted = 0**, a passive muscle | optional |
| `chainAct`, `bagAct` | γ-static / γ-dynamic activations | **forward** run |
| `targetFiring` | recorded Ia firing rate (spikes/s) | **optimize** run |
| `tendonStiffness` | scalar (default 5000) | optional |

- **Forward** (`length + activations → receptor potential`): predicts fiber forces
  and the Ia receptor potential from your inputs.
- **Optimize** (`length + your firing → gamma`): infers a compact gamma drive
  (γ-static level, γ-dynamic burst magnitude + on/off timing) that reproduces
  your firing. This uses a general parameterization suited to arbitrary
  protocols, rather than the periodic B-spline used for gait data on the
  `Gamma optimization` tab.

**Units — give `restingLength` and yours cancel.** Internally the model works in
half-sarcomere nanometres (resting ≈ 1250 nm), which is nobody's recording unit.
So supply your length in **mm, cm, m — whatever you have** — plus `restingLength`
in those same units, and the loader normalises by the ratio. Omit `restingLength`
only if your trace really is in half-sarcomere nm (you'll get a warning if it
looks like it isn't).

**Time step matters.** The model is tuned for **dt = 1 ms** and is *not*
dt-invariant: the integrate-and-fire stage quantises spike intervals to dt, so
firing rates shift if you change it. The loader warns outside ~0.2–2 ms — resample
to 1 kHz if you can.

Activations may be fractions (`0..1`) or percent (`0..100`); values above ~1.5
are treated as percent. Click **Load built-in example** to see a valid dataset
and try both actions without a file.

**Saving.** After a run, **Save results…** writes a `.mat` (everything) and a
`.csv` (the time series, for Excel/Python/R).

**Prefer scripting?** [`examples/runMyOwnData.m`](examples/runMyOwnData.m) is an
editable template that does all of the above from code — build inputs, run
forward or optimize, plot, and save. Run it as-is to see the whole flow, then
swap in your own recording.

---

## Building the standalone apps

Prebuilt installers are on the [latest release](../../releases/latest). If you
need to *build* them yourself, see [MAINTAINING.md](MAINTAINING.md).

## How it's organized

```
spindleModelTutorial/
├── launchSpindleTutorial.m   launcher menu (choose Learn or Apply)
├── launchSpindleTutorialApp.m  open the Tutorial (Learn) window directly
├── launchSpindleToolkit.m    open the Analysis Toolkit (Apply) window directly
├── spindleLearnApp.m         entry point for the compiled standalone Learn app
├── build/
│   └── buildLearnApp.m       compile the Learn window (MATLAB Compiler)
├── setupTutorialPaths.m      adds the toolbox + local folders to the path
├── app/
│   ├── SpindleAppBase.m      shared styling + per-signal plot helpers (base class)
│   ├── SpindleLearnApp.m     Interactive Tutorial window (Overview/Walkthrough/Playground)
│   └── SpindleToolkitApp.m   Analysis Toolkit window (Gamma optimization/Your data)
├── compute/                  plain, headless-testable functions
│   ├── defaultTutorialParams.m   canonical parameter set (single source of truth)
│   ├── loadActivationCurve.m     pCa <-> activation interpolants
│   ├── makeLengthCommand.m       stretch protocols (ramp-hold / sine / triangle)
│   ├── runExtrafusalMTU.m        extrafusal MTU (α + tendon) -> fascicle length
│   ├── makeGammaDrive.m          gamma static/dynamic -> intrafusal pCa
│   ├── tutorialForwardSim.m      the full pipeline, params -> all signals
│   ├── tutorialOptDemo.m         recover known B-spline gamma drive (simulated Ia)
│   ├── loadUserData.m            load + validate a user .mat (Your data tab)
│   ├── runForwardFromData.m      user length + activations -> receptor potential
│   ├── runOptFromData.m          user length + firing -> inferred gamma drive
│   ├── saveUserResults.m         export a run to .mat + .csv
│   └── exampleUserData.m         built-in demo dataset in the user-data format
├── examples/
│   └── runMyOwnData.m        editable template: drive the model from a script
├── data/
│   ├── ActCurveSim120240819.mat  vendored pCa<->activation curve (self-contained)
│   └── spindleModelFig.png       model schematic shown on the Overview tab
├── vendor/                   snapshotted model code (see Vendored model code)
│   ├── VENDOR_INFO.txt           source commits the copies were taken from
│   ├── matlabMuscleSpindleModellingTools/   12 files: the model
│   └── gammaDriveOptimization/               2 files: B-spline gamma routines
├── tools/
│   └── refreshVendor.m       re-sync vendor/ from the source repos (maintainers)
├── docs/                     standalone narrative (mirrors the in-app text)
└── tests/
    └── smokeTest.m           headless checks for the compute layer
```

The `compute/` layer is deliberately GUI-free so the science can be tested and
reused independently of the app. See the [`docs/`](docs/) folder for the written
walkthrough.

## A note on parameters

`compute/defaultTutorialParams.m` is the single source of truth for defaults.
Fiber-kinetics defaults mirror `getDefaultSarcB`/`getDefaultSarcC` in the
toolbox. The pCa convention throughout is the model's own: **lower pCa = stronger
activation** (pCa 9 ≈ silent, pCa 4.5 ≈ maximal).

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
