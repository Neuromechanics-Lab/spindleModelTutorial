% spikesFromReceptorPotential  Turn the Ia receptor potential into spikes.
%
%   The tutorial stops at the receptor potential r, because that is what the
%   biophysical model actually predicts. Converting r into an afferent spike
%   train is a separate modelling choice, and the simple integrate-and-fire the
%   toolbox ships has limits that are easy to hit (see "What to watch out for"
%   below). This script shows how to run it, and where to change it.
%
%   Run it from anywhere:
%       run('examples/spikesFromReceptorPotential.m')

here = fileparts(mfilename('fullpath'));
run(fullfile(fileparts(here), 'setupTutorialPaths.m'));

% ---- 1. Get a receptor potential --------------------------------------
% Anything that produces r works: the parametric sim here, runForwardFromData
% for your own recordings, or a trace you load from disk.
p = defaultTutorialParams();
out = tutorialForwardSim(p);

r_t = out.r_t;      % time base (s)
r   = out.r;        % receptor potential (a.u.)

% ---- 2. Run the toolbox spike generator -------------------------------
% integrateAndFire_v2(r_t, r, removeOffsetFlag)
%   removeOffsetFlag = 1 subtracts r(1) as the resting offset. That is only
%   correct if the run STARTS at zero activation - which is why the tutorial's
%   gamma onsets are all slightly greater than zero, and why the toolbox holds
%   activation at zero for its first 10 steps. Starting from an already-active
%   state would subtract the tonic drive itself.
[t_spike, IFR] = integrateAndFire_v2(r_t, r, 1);

% The first spike has no preceding interval, so its rate is Inf. Drop it.
ok = isfinite(IFR);
t_spike = t_spike(ok);
IFR     = IFR(ok);

fprintf('%d spikes, rate %.0f-%.0f spikes/s\n', numel(t_spike), min(IFR), max(IFR));

% ---- 3. Look at it ----------------------------------------------------
figure('Color', 'w', 'Position', [100 100 780 520]);
ax1 = subplot(2,1,1);
plot(r_t, r, 'k', 'LineWidth', 1.6);
ylabel('r (a.u.)'); title('Ia receptor potential (the model output)');
ax2 = subplot(2,1,2);
stairs(t_spike, IFR, 'Color', [0.28 0.56 0.46], 'LineWidth', 1.2); hold on
plot(t_spike, IFR, 'o', 'MarkerSize', 4, 'MarkerFaceColor', [0.28 0.56 0.46], ...
    'Color', [0.28 0.56 0.46], 'LineStyle', 'none'); hold off
ylabel('firing (spikes/s)'); xlabel('time (s)');
title('Spikes from an integrate-and-fire');
linkaxes([ax1 ax2], 'x'); xlim([r_t(1) r_t(end)]);

% ---- What to watch out for --------------------------------------------
% The generator has two hard limits, BOTH set by the time step:
%
%   ceiling      = 1/(refractory + 2*dt).  The 2 ms refractory is enforced by
%                  counting SAMPLES, which costs an extra 2*dt on top of it, so
%                  at dt = 1 ms the ceiling is 250 spikes/s, not 500.
%   quantisation = spikes land on samples, so every interval is a whole number
%                  of them and the rate can only be 1/(k*dt): 250, 200, 167,
%                  143, 125, ... The steps get coarser the faster the firing.
%
% Together these mean a strong gamma drive pins the whole trace at 250 and the
% shape disappears. Check for it directly:
ceilHz = 1 / (4 * (r_t(2) - r_t(1)));
fprintf('%.0f%% of spikes are at the %.0f spikes/s ceiling\n', ...
    100 * mean(IFR >= 0.99 * ceilHz), ceilHz);

% ---- Things to change -------------------------------------------------
% * SCALE. Only the ratio r/threshold matters below the ceiling: rate = r/0.005.
%   Scaling the transduction gains (p.trans.kFc/kFb/kYb) down is equivalent to
%   scaling the 0.005 threshold up. Pick the ratio that puts your rates in a
%   physiological range, and remember it does not change the shape of r at all.
% * REFRACTORY / dt. A smaller dt raises the ceiling and densifies the rate
%   ladder, but dt is not a free parameter - the cross-bridge kinetics are
%   integrated with it, so changing it changes what the model predicts.
% * THE GENERATOR ITSELF. Two cheap improvements if you write your own:
%   compare elapsed TIME rather than counting samples for the refractory period
%   (removes the dt-dependence of the ceiling), and interpolate the threshold
%   crossing within a sample instead of snapping to the boundary (removes the
%   quantisation, and the systematic downward bias that comes with it - the
%   current code always rounds an interval UP to the next whole sample).
