# Spindle Tutorial v1.1

Interactive companion to the biophysical muscle spindle model of
[Simha et al. (2026, bioRxiv)](https://doi.org/10.64898/2026.07.03.736206).

## Downloads — no MATLAB needed

| File | Platform | Runtime it fetches |
|------|----------|--------------------|
| `SpindleTutorialInstaller_mac.zip` | macOS, **Apple silicon** (M1 or newer, 2020+) | MATLAB Runtime **R2026b** |
| `SpindleTutorialInstaller_win.zip` | Windows 10/11 (64-bit) | MATLAB Runtime **R2026a** |

**Older Intel Mac?** (Apple menu → About This Mac shows "Intel".) This version
won't run on it — use the
[v1.0 Mac installer](https://github.com/SurabhiSimha/spindleModelTutorial/releases/download/v1.0/SpindleTutorialInstaller_mac.zip)
instead. It has the same tutorial content.

### Installing

1. **Unzip** the download.
2. **Run the installer.**
   - **Windows:** right-click the installer → **Run as administrator**. If
     SmartScreen says the publisher is unrecognized, choose **More info → Run
     anyway**.
   - **macOS:** right-click the installer → **Open** → *Open* (the app is not
     code-signed, so macOS warns the first time).
3. **Wait.** The installer downloads the free MATLAB Runtime from MathWorks
   (several GB), so you need an internet connection and it takes a while. Once
   installed, the app runs offline.
4. **Open Spindle Tutorial.** The first launch takes a minute while the Runtime
   starts up; after that it is quicker.

## What's new in v1.1

- **Readable in dark mode.** On computers set to dark mode, some text in the
  Windows app was unreadable. The app now always uses its light theme.
- **Window fits the screen.** On Windows laptops the window could open with
  its title bar above the top of the screen. It now sizes itself to fit.
- **No extra window on Windows.** A command window no longer stays open behind
  the app.
- **Faster on Apple silicon Macs.** The Mac app now runs natively instead of
  through Rosetta.
- **Faster first walkthrough.** The app warms up the model while you read the
  Overview, so the Guided walkthrough opens without a long pause.
- **Cleaner walkthrough text.** Paragraphs now wrap to the text box instead of
  breaking mid-sentence.

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

How this tutorial's workflow differs from the published pipeline is listed in
[docs/07](https://github.com/SurabhiSimha/spindleModelTutorial/blob/main/docs/07_differences_from_manuscript.md).

## Citation

**This software** is archived on Zenodo:

- all versions (resolves to the latest): [10.5281/zenodo.21774146](https://doi.org/10.5281/zenodo.21774146)

Cite the *all versions* DOI unless you need to pin the exact version you ran.

**The model** it implements:

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
