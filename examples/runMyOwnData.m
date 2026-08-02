%% Run the muscle spindle model on your own data - editable template
%
% This script does from code what the "Your data" tab does through the GUI.
% Copy it, edit the marked sections, and run. Nothing here is special to the
% app: these are the same compute functions the GUI calls.
%
% Model: Simha et al. (2026), doi:10.64898/2026.07.03.736206
%
% Two things you can do:
%   FORWARD   length + activations  -> fiber forces + Ia receptor potential
%   OPTIMIZE  length + your Ia firing -> the gamma drive that reproduces it
%
% Run this file as-is first: it fabricates a small example so you can see the
% whole flow work, then swap in your own recording.

%% 0. Set up the path (always do this first)
here = fileparts(mfilename('fullpath'));
run(fullfile(fileparts(here), 'setupTutorialPaths.m'));

%% 1. BUILD YOUR INPUT  <-- EDIT THIS SECTION
% Replace this block with your own recording. The only hard requirements are
% that everything is the same length as t, and that dt is ~1 ms (the model is
% tuned for 1 kHz and is not dt-invariant - see the README).

t = 0:0.001:2;                                   % time (s), 1 kHz

% Muscle length. Give it in ANY units, together with restingLength in the SAME
% units - the ratio is what matters, so the units cancel. (Here: millimetres.)
restingLength = 30;                              % mm, your muscle's resting length
mtuLength     = 30 + 2.4 * max(0, min(1, (t - 0.3) / 0.8));   % mm, a ramp-and-hold

% Motor drive, as % of maximum activation (0-100).
alphaAct = 35 * ones(size(t));                   % alpha, to the extrafusal muscle
chainAct = 50 * ones(size(t));                   % gamma-static, to the chain fiber
bagAct   = 10 * (t > 0.3 & t < 1.1);             % gamma-dynamic burst, to the bag fiber

% If you are FITTING instead, supply your recorded Ia rate and leave the gamma
% activations out:
%   targetFiring = myRecordedIaRate;             % spikes/s, same length as t

%% 2. Package it the way the loader expects
% Either save these variables to a .mat and call loadUserData('myFile.mat'),
% or build the struct directly and save it, as below.
data = struct('t', t, 'mtuLength', mtuLength, 'restingLength', restingLength, ...
              'alphaAct', alphaAct, 'chainAct', chainAct, 'bagAct', bagAct);
tmpFile = fullfile(tempdir, 'myInput.mat');
save(tmpFile, '-struct', 'data');

d = loadUserData(tmpFile);      % validates, normalises units, reports what's possible
fprintf('Loaded %d samples at dt = %.4g s. Forward: %d, Optimize: %d\n', ...
    d.n, d.dt, d.availForward, d.availOptimize);

%% 3. FORWARD RUN: length + activations -> receptor potential
out = runForwardFromData(d);

fprintf('Peak bag force      : %.3g N/m^2\n', max(out.bag.hs_force));
fprintf('Peak receptor pot.  : %.3g a.u.\n',  max(out.r));
fprintf('Receptor potential  : %.2f - %.2f (a.u.)\n', min(out.r), max(out.r));

% Everything you might want is in `out`:
%   out.t, out.L (fascicle length, nm), out.mt.mtuCmd
%   out.actAlpha / out.actC / out.actB   (0-1)
%   out.bag.hs_force, out.chain.hs_force
%   out.bag.bin_pops                     (cross-bridge distribution, bins x time)
%   out.r_t, out.r, out.rs, out.rd       (receptor potential: total/static/dynamic)
%   out.t_firing, out.IFR                (spike times and rate; see
%                                         examples/spikesFromReceptorPotential.m)

%% 4. Plot it
figure('Color', 'w', 'Name', 'My spindle simulation');
tl = tiledlayout(4, 1, 'TileSpacing', 'compact');

nexttile; plot(out.t, out.L, 'k', 'LineWidth', 1.5);
ylabel('fascicle (nm)'); title('Length'); grid on

nexttile; plot(out.t, 100*out.actAlpha, out.t, 100*out.actC, out.t, 100*out.actB, ...
    'LineWidth', 1.5);
ylabel('activation (%)');
legend({'extrafusal (\alpha)','chain (\gamma-static)','bag (\gamma-dynamic)'}, ...
    'Location','best'); grid on

nexttile; plot(out.t, out.bag.hs_force, out.t, out.chain.hs_force, 'LineWidth', 1.5);
ylabel('force (N m^{-2})'); legend({'bag','chain'}, 'Location','best'); grid on

nexttile; plot(out.t, out.rs, out.t, out.rd, out.t, out.r, 'LineWidth', 1.4);
ylabel('r (a.u.)'); xlabel('time (s)');
legend({'r_s (static)','r_d (dynamic)','r (total)'}, 'Location','best'); grid on
title(tl, 'Muscle spindle model output');

%% 5. Save the results (.mat with everything + .csv of the time series)
saveUserResults(fullfile(tempdir, 'myResults'), out, 'forward');
fprintf('Saved results to %s\n', tempdir);

%% 6. OPTIMIZE instead: length + your firing -> gamma drive
% Uncomment once you have a recorded Ia rate in `targetFiring`. This fits 8
% parameters to your recording: the gamma-static waveform (5 B-spline control
% points), the gamma-dynamic burst magnitude, and the burst on/off times. Each
% evaluation runs the full model, so expect ~2 minutes.
%
% THE COST IS MEAN-NORMALIZED: each trace is divided by its own mean before the
% RMSE, so only SHAPE is compared - the same cost the manuscript minimises. That
% is what lets the model's RECEPTOR POTENTIAL be fitted to your recorded FIRING
% RATE (the default): below the spike generator's ceiling the two are
% proportional, and a proportional factor is exactly what normalisation removes.
% It also keeps the generator's 250 spikes/s ceiling out of the objective.
%
% Two options you can pass (both also exposed in the app's Your-data tab):
%
%   fitTarget : 'receptor' (default) fits the model's r to your recorded rate.
%               'firing' pushes the model through integrateAndFire_v2 first -
%               which saturates at 250 spikes/s at dt = 1 ms, so the objective
%               goes flat wherever the model is pinned.
%   solver    : 'fmincon' (default). 'patternsearch' is the manuscript's solver -
%               derivative-free, so it copes better with the stepped cost you get
%               in 'firing' mode, but it polls 2N points per iteration so it is
%               slower here. On the built-in example the two land close together
%               (0.064 vs 0.071); neither dominates, so try both if a fit matters.
%   gammaStatic : how gamma-static is modelled.
%               'bspline-free' (default) - 5 control points across the trial,
%                 no periodicity assumed. Covers a constant (all points equal)
%                 and a ramp (monotonic points) as special cases, so it suits
%                 ARBITRARY protocols. 8 parameters.
%               'bspline-periodic' - the manuscript's construction: one cycle
%                 tiled, last control point = first. The BETTER model when your
%                 protocol really is cyclic, because 5 numbers then describe
%                 every cycle. Needs opts.cyclePeriod (seconds); the tutorial
%                 will not guess it. 8 parameters.
%               'constant' - a single gamma-static level. 4 parameters, fastest.
%
% See docs/06_your_data.md and compute/meanNormRMSE.m.
%
%   data2 = struct('t', t, 'mtuLength', mtuLength, 'restingLength', restingLength, ...
%                  'alphaAct', alphaAct, 'targetFiring', targetFiring);
%   save(fullfile(tempdir,'myFit.mat'), '-struct', 'data2');
%   d2  = loadUserData(fullfile(tempdir,'myFit.mat'));
%   res = runOptFromData(d2, struct('maxIter', 20));   % r, fmincon, free spline
%   % ... or spell it all out. For cyclic data prefer the periodic spline:
%   % res = runOptFromData(d2, struct('maxIter', 20, ...
%   %                                 'fitTarget',   'receptor', ...
%   %                                 'solver',      'patternsearch', ...
%   %                                 'gammaStatic', 'bspline-periodic', ...
%   %                                 'cyclePeriod', 0.64));
%   fprintf('fitted %s with %s | cost %.3g -> %.3g\n', ...
%           res.fitTarget, res.solver, res.fval0, res.fvalOpt);
%   for i = 1:numel(res.names)
%       fprintf('  %-32s %.3f\n', res.labels{i}, res.xOpt(i));
%   end
%   saveUserResults(fullfile(tempdir,'myFitResults'), res, 'optimize');
