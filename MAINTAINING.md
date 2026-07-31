# Maintaining this repository

Notes for whoever maintains the tutorial — not needed to *use* it. If you
just want to run the app, see the [README](README.md).

---

## Re-syncing the vendored model code

The model files under `vendor/` are copies (see
[README § Vendored model code](README.md#vendored-model-code)). After changing
`matlabMuscleSpindleModellingTools` or `gammaDriveOptimization`, re-sync them:

```matlab
cd tools
refreshVendor      % re-copies the file list, re-stamps vendor/VENDOR_INFO.txt
```

The file list inside `refreshVendor.m` is the complete dependency surface,
determined with `matlab.codetools.requiredFilesAndProducts`. If the apps gain a
new dependency, re-run that check and update the list. Note it copies but does
**not** prune, so delete files you remove from the list.

---

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

`launchLearnAppDeployed.m` is the entry point (opens the Learn window and keeps it
alive); the activation-curve `.mat`, the overview figure, and the model functions
are bundled automatically. The script also packages an **installer** that fetches
the free Runtime at install time.

### Building for Windows

The compiler emits a **native binary for whatever OS you build on** — there is no
cross-compiling, and there is no separate "Windows version" of the source. To
ship a Windows build you run the *same* script on a Windows machine.

On that machine you need MATLAB plus these three add-ons installed (Home →
Add-Ons → **Get Add-Ons**). Being *licensed* is not enough — they must be
installed, which `ver` will confirm:

| Add-on | Why | Check |
|--------|-----|-------|
| **MATLAB Compiler** | produces the `.exe` | `exist('mcc')` → `2` |
| **Signal Processing Toolbox** | `butter`/`filtfilt` inside `sarc2spindle` | `which butter` → non-empty |
| **Optimization Toolbox** | only if you also compile the Toolkit window | `which fmincon` → non-empty |

Signal Processing is a hard requirement for the Learn app: without it `mcc`
still emits an executable, but one that dies at runtime on your users'
machines. `buildLearnApp` now preflights this and refuses to build instead.

Then:

1. Clone this repo on Windows. Nothing else to install — the model code is
   vendored (see [Vendored model code](#vendored-model-code)).
2. In MATLAB: `cd build`, then `buildLearnApp`.
3. Output lands in `build/SpindleTutorialLearn_win/` — a `SpindleTutorial.exe`
   plus a `SpindleTutorialInstaller` (the `.exe` your Windows users run).

The MATLAB source itself is OS-agnostic (all paths use `fullfile`), so the app,
the toolkit, and the tests all run unchanged on macOS and Windows — only the
*compiled* artifact is platform-specific.

### How people get it

| Audience | What they need | How to distribute |
|----------|----------------|-------------------|
| **Has MATLAB** | The source | Link to the **git repo**; they clone it and run `launchSpindleTutorial`. |
| **No MATLAB** | The compiled app | They **download one installer** (per OS) + the free Runtime — no git clone, no MATLAB. |

Prebuilt installers for **macOS** and **Windows** are attached to the
[latest release](../../releases/latest) — not committed to this repository. Both
are *web* installers: small, because they fetch the free MATLAB Runtime during
installation (so you need internet once; the Runtime version is pinned per
build). Neither is code-signed, so on first launch use **right-click → Open**
(macOS) or **More info → Run anyway** (Windows).

> **Do not commit installers.** Binaries stay in git history permanently and
> bloat every future clone. `.gitignore` excludes `dist/`, `*.zip`, and
> `build/SpindleTutorialLearn*/` for exactly this reason — attach build outputs
> to a Release instead.

For a **website link**, the compiled installer is a large binary (~hundreds of
MB with the Runtime), so host the built file as a download rather than in the
repo itself: a **GitHub Release** asset (you can link straight to it), **Zenodo**
(gives a citable DOI — handy for the manuscript), or your own server. A plain git
link is right for the *source*, but for the click-to-run app link the *installer
download*. (A truly install-free "runs in the browser" link is a different,
heavier route — a hosted MATLAB Web App Server — not what compilation produces.)

---

