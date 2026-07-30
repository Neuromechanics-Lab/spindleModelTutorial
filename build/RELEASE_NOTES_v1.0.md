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
  activation) → cross-bridge distribution → receptor potential + yank →
  predicted Ia firing → the whole pipeline.
- **Playground** — move any parameter (stretch protocol, extrafusal α + tendon,
  γ drive, fiber kinetics, transduction gains) and watch every signal update,
  with a scrubber to step the cross-bridge distribution through time.

## For MATLAB users

Clone the source instead and run `launchSpindleTutorial`. See the
[README](../README.md) for the required sibling repositories.

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

MIT licensed.
