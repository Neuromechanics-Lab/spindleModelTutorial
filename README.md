# Muscle Spindle Model — Interactive Tutorial

An interactive, tutorial-style MATLAB app for the biophysical muscle spindle
model in [`matlabMuscleSpindleModellingTools`](../matlabMuscleSpindleModellingTools).
It lets you *play* with the model — move a parameter and immediately see how
individual fiber forces, the Ia receptor potential, and the cross-bridge
distribution respond — and it walks you through how the model is put together
and how the fusimotor-drive optimization (from
[`gammaDriveOptimization`](../gammaDriveOptimization)) works.

**Author:** Surabhi Simha · Neuromechanics Lab, Emory University

---

## What's inside

`launchSpindleTutorial` opens a small launcher with two focused windows:

### Interactive Tutorial (Learn)

| Tab | What it does |
|-----|--------------|
| **Overview** | What the model is and how the pipeline fits together. |
| **Guided walkthrough** | A narrated, five-step tour: inputs (length + activation) → cross-bridge distribution (pre/early/post-stretch snapshots, with cursors) → receptor potential + yank → predicted firing → the whole pipeline. |
| **Playground** | Free exploration. Sliders for the stretch protocol, the **extrafusal MTU** (α drive + tendon stiffness), gamma drive (including a sinusoidal gamma-static with phase/offset), fiber kinetics, and transduction gains. Plots length, **activation (%)**, fiber forces, the receptor potential, **predicted firing**, and a **cross-bridge distribution scrubber**. Every panel is badged **INPUT / INTERMEDIATE / OUTPUT**. |

### Analysis Toolkit (Apply)

| Tab | What it does |
|-----|--------------|
| **Gamma optimization** | Generate a target Ia from *known* gamma drive, then watch an optimizer recover it — including the **gamma-static B-spline waveform**, drawn against the truth. Uses the manuscript's own B-spline routines. |
| **Your data** | Run the model on **your own** inputs (see [file format](#bring-your-own-data-your-data-tab)): length + activations → firing (forward), or length + recorded Ia firing → the gamma drive that reproduces it (optimize). A built-in example demonstrates both. |

The two windows share one codebase (so they stay visually consistent) but open
independently, so the Learn window stays light and never touches the optimization
code. Everything each window plots is produced by the **real** toolbox functions
(`musTenDriver20250627`, `sarcSimDriverIntrafusal20250627`,
`sarc2spindle_20240310`, `integrateAndFire`), and the optimization tab calls
`gammaDriveOptimization`'s own B-spline routines. Nothing is re-implemented — you
are driving the published model.

---

## Requirements

- **MATLAB R2020a or later** (uses `uifigure` apps).
- **Signal Processing Toolbox** — `butter`/`filtfilt`, used inside `sarc2spindle`.
- **Optimization Toolbox** — `fmincon`, used by the optimization tab.
- The sibling **`matlabMuscleSpindleModellingTools`** toolbox on disk (required).
- The sibling **`gammaDriveOptimization`** repo on disk — only for the
  optimization tab, whose real B-spline routines it calls. Without it, the first
  three tabs work fully and the optimization tab is disabled with a note.
- *Optional:* **Parallel Computing Toolbox** — the optimization tab's "Use
  parallel" checkbox speeds the fit by parallelizing finite differences.

## Folder layout

Clone this repo next to the toolbox and the optimization repo (the tutorial finds
them automatically):

```
GitHub/Emory/                          (or any parent folder)
├── matlabMuscleSpindleModellingTools/   <- the model (required)
├── gammaDriveOptimization/              <- needed only for the optimization tab
└── spindleModelTutorial/                <- this repo
```

If they live elsewhere, set environment variables before launching:

```matlab
% macOS / Linux
setenv('SPINDLE_TOOLBOX_DIR', '/full/path/to/matlabMuscleSpindleModellingTools');
setenv('GAMMA_OPT_DIR',       '/full/path/to/gammaDriveOptimization');

% Windows
setenv('SPINDLE_TOOLBOX_DIR', 'C:\path\to\matlabMuscleSpindleModellingTools');
setenv('GAMMA_OPT_DIR',       'C:\path\to\gammaDriveOptimization');
```

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

## Verify the engine (headless)

The numerical core can be checked without opening the GUI:

```matlab
setupTutorialPaths();
smokeTest
```

or from a shell:

```bash
matlab -batch "run('tests/smokeTest.m')"
```

This runs the forward simulation and the optimization demo and prints
PASS/FAIL for each sanity check.

---

## Bring your own data (`Your data` tab)

The **Your data** tab runs the model on inputs you supply in a `.mat` file. Save
these variables (or a single struct named `data` with these fields) — all
time-series the **same length as `t`**:

| Variable | Meaning | Needed for |
|----------|---------|-----------|
| `t` | time (s), ~1 ms uniform step | always |
| `mtuLength` *or* `fascicleLength` | length in nm (MTU is run through the tendon; fascicle is used as-is) | always |
| `alphaAct` | extrafusal (α) activation, `0..1` or `0..100` % | optional |
| `chainAct`, `bagAct` | γ-static / γ-dynamic activations | **forward** run |
| `targetFiring` | recorded Ia firing rate (spikes/s) | **optimize** run |
| `tendonStiffness` | scalar (default 5000) | optional |

- **Forward** (`length + activations → firing`): predicts fiber forces, receptor
  potential, and firing from your inputs.
- **Optimize** (`length + your firing → gamma`): infers a compact gamma drive
  (γ-static level, γ-dynamic burst magnitude + on/off timing) that reproduces
  your firing. This uses a general parameterization suited to arbitrary
  protocols, rather than the periodic B-spline used for gait data on the
  `Gamma optimization` tab.

Activations may be fractions (`0..1`) or percent (`0..100`); values above ~1.5
are treated as percent. Click **Load built-in example** to see a valid dataset
and try both actions without a file.

---

## Shipping a standalone app (no MATLAB license needed)

The **Interactive Tutorial (Learn)** window can be compiled into a
double-clickable desktop app that runs against the free **MATLAB Runtime** — so
readers/reviewers without a MATLAB license can use it.

**One-time setup:** install the **MATLAB Compiler** add-on (Home → Add-Ons →
*MATLAB Compiler*). Check with `exist('mcc')` → should be `2`.

**Build** (do this once per operating system — the output is platform-specific;
build on macOS → Mac app, on Windows → `.exe`):

```matlab
cd build
buildLearnApp        % -> build/SpindleTutorialLearn_mac/  (or _win on Windows)
```

`spindleLearnApp.m` is the entry point (opens the Learn window and keeps it
alive); the activation-curve `.mat`, the overview figure, and the model functions
are bundled automatically. The script also packages an **installer** that fetches
the free Runtime at install time.

### Building for Windows

The compiler emits a **native binary for whatever OS you build on** — there is no
cross-compiling. To ship a Windows version you must run the same script *on a
Windows machine* that has MATLAB + MATLAB Compiler:

1. Clone this repo and `matlabMuscleSpindleModellingTools` side by side on Windows.
2. In MATLAB: `cd build`, then `buildLearnApp`.
3. Output lands in `build/SpindleTutorialLearn_win/` — a `SpindleTutorial.exe`
   plus a `SpindleTutorialInstaller` (the `.exe` your Windows users run).

The MATLAB source itself is OS-agnostic (all paths use `fullfile`), so the app,
the toolkit, and the tests all run unchanged on macOS and Windows — only the
*compiled* artifact is platform-specific.

### How people get it

| Audience | What they need | How to distribute |
|----------|----------------|-------------------|
| **Has MATLAB** | The source | Link to the **git repo**; they clone it (next to the toolbox) and run `launchSpindleTutorial`. |
| **No MATLAB** | The compiled app | They **download one installer** (per OS) + the free Runtime — no git clone, no MATLAB. |

For a **website link**, the compiled installer is a large binary (~hundreds of
MB with the Runtime), so host the built file as a download rather than in the
repo itself: a **GitHub Release** asset (you can link straight to it), **Zenodo**
(gives a citable DOI — handy for the manuscript), or your own server. A plain git
link is right for the *source*, but for the click-to-run app link the *installer
download*. (A truly install-free "runs in the browser" link is a different,
heavier route — a hosted MATLAB Web App Server — not what compilation produces.)

---

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
│   ├── runForwardFromData.m      user length + activations -> firing
│   ├── runOptFromData.m          user length + firing -> inferred gamma drive
│   └── exampleUserData.m         built-in demo dataset in the user-data format
├── data/
│   └── ActCurveSim120240819.mat  vendored pCa<->activation curve (self-contained)
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
