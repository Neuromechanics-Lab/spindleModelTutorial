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
bagAct   = 90 * (t > 0.3 & t < 1.1);             % gamma-dynamic burst, to the bag fiber

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
ylabel('activation (%)'); legend({'\alpha','chain','bag'}, 'Location','best'); grid on

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
% Uncomment once you have a recorded Ia rate in `targetFiring`. This fits a
% compact gamma drive (static level, burst magnitude, burst on/off) by
% minimising RMSE against your firing. Each evaluation runs the full model, so
% expect ~1-2 minutes.
%
%   data2 = struct('t', t, 'mtuLength', mtuLength, 'restingLength', restingLength, ...
%                  'alphaAct', alphaAct, 'targetFiring', targetFiring);
%   save(fullfile(tempdir,'myFit.mat'), '-struct', 'data2');
%   d2  = loadUserData(fullfile(tempdir,'myFit.mat'));
%   res = runOptFromData(d2, struct('maxIter', 20));
%   fprintf('cost %.3g -> %.3g\n', res.fval0, res.fvalOpt);
%   for i = 1:numel(res.names)
%       fprintf('  %-32s %.3f\n', res.labels{i}, res.xOpt(i));
%   end
%   saveUserResults(fullfile(tempdir,'myFitResults'), res, 'optimize');
