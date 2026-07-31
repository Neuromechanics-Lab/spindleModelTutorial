function result = runOptFromData(d, opts)
% runOptFromData  Infer gamma drive that reproduces a user's recorded Ia firing.
%
%   result = runOptFromData(d, opts) takes a normalized user-data struct (from
%   loadUserData) providing length + a recorded Ia firing rate, and optimizes the
%   fusimotor (gamma) drive so the model reproduces it.
%
%   WHAT IS COMPARED (opts.fitTarget):
%     'receptor' (DEFAULT) - the model's RECEPTOR POTENTIAL r is fitted to your
%                 recorded firing rate. That sounds like a units mismatch, but the
%                 cost is MEAN-NORMALIZED (see meanNormRMSE): each trace is divided
%                 by its own mean, so only shape is compared and any overall gain
%                 cancels. Below the spike generator's ceiling firing IS
%                 proportional to r (rate = r/threshold), so the shapes agree -
%                 and this keeps the refractory ceiling and the 1/(k*dt) rate
%                 quantisation out of the objective entirely.
%     'firing'  - push the model through integrateAndFire_v2 and fit the model's
%                 firing rate instead. Same mean-normalized cost. Use this if you
%                 specifically want the spike generator in the loop; be aware it
%                 saturates at 1/(4*dt) = 250 spikes/s at dt = 1 ms, which flattens
%                 the objective wherever the model is pinned.
%   See docs/06_your_data.md.
%
%   To stay robust for ARBITRARY user protocols (not just periodic gait data), it
%   fits a compact, general gamma parameterization rather than the periodic
%   B-spline used on the manuscript's gait data:
%       x = [ chain pCa (gamma-static level),
%             bag burst pCa (gamma-dynamic magnitude),
%             bag burst onset (s), bag burst offset (s) ]
%
%   The fascicle length (from the user's length + alpha via the MTU, or their
%   fascicle trace directly) does not depend on gamma, so it is computed ONCE and
%   reused on every objective evaluation.
%
%   opts (optional): .maxIter (default 20), .iterFcn (callback for live updates),
%   .fitTarget ('receptor' | 'firing', default 'receptor').
%
%   result fields: .t, .target, .fit0, .fitOpt (on the user grid, in whatever
%   quantity was fitted), .fitTarget, .fitUnits,
%   .x0, .xOpt, .names, .labels, .history, .fval0, .fvalOpt, and .gammaOpt
%   (recovered gamma pCa traces for plotting), plus .outOpt (full model output).

if nargin < 2, opts = struct(); end
t  = d.t(:)';
n  = d.n;
maxIter   = getOpt(opts, 'maxIter', 20);
iterFcn   = getOpt(opts, 'iterFcn', []);
fitTarget = lower(getOpt(opts, 'fitTarget', 'receptor'));
if ~ismember(fitTarget, {'receptor','firing'})
    error('runOptFromData:badFitTarget', ...
        'opts.fitTarget must be ''receptor'' or ''firing'' (got ''%s'').', fitTarget);
end

if isempty(d.targetFiring)
    error('runOptFromData:noTarget', 'This file has no targetFiring to optimize against.');
end

% -- Fascicle length (computed once) -----------------------------------
ac = loadActivationCurve();
if d.hasFascicle
    fascicle = d.fascicleLength(:)';
    alphaAct = zeros(n,1);
else
    p = defaultTutorialParams(); p.mtu.tendonStiffness = d.tendonStiffness;
    alpha = d.alphaAct; if isempty(alpha), alpha = zeros(1,n); end
    mt = runExtrafusalMTU(t, p, d.mtuLength, alpha);
    fascicle = mt.fascicleLength; alphaAct = mt.alphaAct;
end
delta_cdl = [0, diff(fascicle)];

sarcB0 = getDefaultSarcB(); sarcC0 = getDefaultSarcC();
sarcB0.hs_length = fascicle(1); sarcB0.cmd_length = fascicle(1);
sarcC0.hs_length = fascicle(1); sarcC0.cmd_length = fascicle(1);
tr = defaultTutorialParams().trans;

% -- Smoothed target rate ----------------------------------------------
smoothWin = max(3, round(0.05 / d.dt));           % ~50 ms
target = movmean(fillmissing(d.targetFiring(:)', 'linear'), smoothWin);

    function [sig, out] = modelSignal(x)
        % Returns whichever quantity is being compared, on the user's grid.
        g = struct('chainMode','constant','chainOn',t(1),'chain_pCa',x(1), ...
            'chain_amp',0,'chain_freq',1,'chain_phase',0, ...
            'bagBaseline',9,'bagBurst',x(2),'bagOn',x(3),'bagOff',x(4));
        [sB, sC] = makeGammaDrive(t, g, sarcB0, sarcC0);
        [~, dB, ~, dC] = sarcSimDriverIntrafusal20250627(t, delta_cdl, sB, sC);
        [r_t, ~, ~, r] = sarc2spindle_20240310(dB, dC, tr.kFc, tr.kFb, tr.kYb, ...
            tr.occlusion, tr.threshold);
        [tf, ifr] = integrateAndFire_v2(r_t, r, 1);
        ok = isfinite(ifr); tf = tf(ok); ifr = ifr(ok);   % 1st spike has no ISI
        if strcmp(fitTarget, 'receptor')
            % The receptor potential, smoothed the same way the target is, so
            % the two traces are treated identically before normalization.
            sig = movmean(interp1(r_t(:), r(:), t, 'linear', 'extrap'), smoothWin);
        elseif isempty(tf)
            sig = zeros(1, n);
        else
            sig = movmean(interp1(tf, ifr, t, 'linear', 0), smoothWin);
        end
        out = struct('r_t', r_t, 'r', r, 't_firing', tf, 'IFR', ifr, ...
            'pCaB', sB.pCa, 'pCaC', sC.pCa);
    end

    function c = objective(x)
        % MEAN-NORMALIZED RMSE, as the manuscript does it: each trace divided by
        % its own mean, so only shape is compared. That is what allows the model
        % receptor potential to be fitted to a recorded firing rate at all, and
        % it is also what keeps gamma-dynamic identifiable - an absolute cost
        % penalises any bag drive that lifts the model above the data, so the
        % optimizer simply turns it off.
        try
            c = meanNormRMSE(modelSignal(x), target);
        catch
            c = 1e6;
        end
    end

% -- Bounds + start -----------------------------------------------------
tSpan = [t(1) t(end)];
x0 = getOpt(opts, 'x0', [6.5, 6.0, t(1) + 0.15*(t(end)-t(1)), t(1) + 0.7*(t(end)-t(1))]);
lb = [4.5, 4.5, tSpan(1), tSpan(1)];
ub = [9.0, 9.0, tSpan(2), tSpan(2)];
names  = {'chain_pCa','bagBurst','bagOn','bagOff'};
labels = {'Chain pCa (\gamma-static)','Bag burst pCa (\gamma-dynamic)', ...
          'Bag burst onset (s)','Bag burst offset (s)'};

history = struct('iter', {}, 'fval', {}, 'x', {});
    function stop = outfun(x, ov, state)
        stop = false;
        if strcmp(state, 'iter')
            history(end+1) = struct('iter', ov.iteration, 'fval', ov.fval, 'x', x(:)');
            if ~isempty(iterFcn)
                iterFcn(struct('iter', ov.iteration, 'fval', ov.fval, 'x', x(:)', 'names', {names}));
            end
        end
    end

options = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'off', ...
    'MaxIterations', maxIter, 'MaxFunctionEvaluations', 800, ...
    'FiniteDifferenceStepSize', 1e-2, 'OutputFcn', @outfun);

fval0 = objective(x0);
[xOpt, fvalOpt] = fmincon(@objective, x0, [], [], [], [], lb, ub, [], options);

[sig0, ~]    = modelSignal(x0);
[sigOpt, oO] = modelSignal(xOpt);

result.t = t; result.target = target;
result.fit0 = sig0; result.fitOpt = sigOpt;
% What was compared, so callers can label the axis honestly. The traces are
% plotted mean-normalized because that is what the cost actually minimized -
% showing them in raw units would imply an absolute match that was never fitted.
result.fitTarget = fitTarget;
if strcmp(fitTarget, 'receptor')
    result.fitUnits = 'receptor potential r (mean-normalized)';
else
    result.fitUnits = 'firing rate (mean-normalized)';
end
result.x0 = x0; result.xOpt = xOpt; result.names = names; result.labels = labels;
result.history = history; result.fval0 = fval0; result.fvalOpt = fvalOpt;
result.gammaOpt = struct('t', t, 'chainPca', oO.pCaC(:), 'bagPca', oO.pCaB(:));
result.outOpt = runForwardFromData(setGammaData(d, xOpt, ac));  % full output at solution
result.fascicle = fascicle; result.alphaAct = alphaAct;
end


% ======================================================================
function d2 = setGammaData(d, x, ac)
% Build a forward-data struct whose activations equal the optimized gamma, so
% the full model output can be produced/plotted at the solution.
g = struct('chainMode','constant','chainOn',d.t(1),'chain_pCa',x(1), ...
    'chain_amp',0,'chain_freq',1,'chain_phase',0, ...
    'bagBaseline',9,'bagBurst',x(2),'bagOn',x(3),'bagOff',x(4));
sB = getDefaultSarcB(); sC = getDefaultSarcC();
[sB, sC] = makeGammaDrive(d.t, g, sB, sC);
d2 = d;
d2.chainAct = min(max(ac.pCaToActC(sC.pCa(:))', 0), 1);
d2.bagAct   = min(max(ac.pCaToActB(sB.pCa(:))', 0), 1);
end

function v = getOpt(opts, field, default)
if isfield(opts, field) && ~isempty(opts.(field)), v = opts.(field); else, v = default; end
end
