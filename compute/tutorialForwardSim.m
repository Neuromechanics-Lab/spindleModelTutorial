function out = tutorialForwardSim(p, mtCache)
% tutorialForwardSim  Run the full spindle model once and return everything.
%
%   out = tutorialForwardSim(p) takes a parameter struct (see
%   defaultTutorialParams) and runs the complete biophysical pipeline using the
%   real matlabMuscleSpindleModellingTools functions:
%
%       length command
%              |
%              v
%     runExtrafusalMTU (musTenDriver)   -> fascicle length (alpha + tendon)
%              |  + gamma drive
%              v
%     sarcSimDriverIntrafusal20250627   -> bag & chain fiber forces + cross-bridge
%              |                            distributions (bin_pops)
%              v
%     sarc2spindle_20240310             -> Ia receptor potential (rs, rd, r)
%              |
%              v
%     integrateAndFire_v2               -> predicted firing (spikes/s)
%
%   out = tutorialForwardSim(p, mtCache) reuses a previously computed MTU result
%   (from runExtrafusalMTU) instead of recomputing it. Because gamma drive does
%   NOT affect the extrafusal MTU, the optimization loop computes the MTU once
%   and passes it back in here on every objective evaluation.
%
%   The returned struct bundles every signal the app plots:
%     .t                 time vector (s)
%     .L, .delta_cdl     fascicle length and its increments (nm)
%     .mt                extrafusal MTU result (see runExtrafusalMTU)
%     .pCaB, .pCaC       gamma drive to bag / chain fibers
%     .x_bins            cross-bridge strain bins (nm), shared by both fibers
%     .bag, .chain       per-fiber structs with force components + bin_pops
%     .rs, .rd, .r       static / dynamic / total receptor potential
%     .r_t               time base for rs/rd/r (may drop leading NaNs)
%     .t_firing, .IFR    predicted spike times and instantaneous firing rate
%     .params            the params actually used (echoed back)
%
%   This function is GUI-free so it can be exercised by the headless smoke test.

if nargin < 1 || isempty(p)
    p = defaultTutorialParams();
end

% -- Time base ----------------------------------------------------------
dt = p.sim.dt;
t  = 0:dt:p.sim.tEnd;

% -- Extrafusal MTU -> fascicle length ----------------------------------
if nargin >= 2 && ~isempty(mtCache)
    mt = mtCache;
else
    mt = runExtrafusalMTU(t, p);
end
L         = mt.fascicleLength;         % the fascicle length the fibers inherit
delta_cdl = [0, diff(L)];

% -- Fiber structs: start from toolbox defaults, apply overrides --------
sarcB = getDefaultSarcB();
sarcC = getDefaultSarcC();
sarcB = applyKineticOverrides(sarcB, p.bag);
sarcC = applyKineticOverrides(sarcC, p.chain);

% Start the intrafusal fibers at the resting fascicle length.
sarcB.hs_length  = L(1);  sarcB.cmd_length = L(1);
sarcC.hs_length  = L(1);  sarcC.cmd_length = L(1);

% -- Gamma drive -> pCa -------------------------------------------------
[sarcB, sarcC] = makeGammaDrive(t, p.gamma, sarcB, sarcC);

% -- Intrafusal simulation (the heavy cross-bridge integration) ---------
[hsB, dataB, ~, dataC] = sarcSimDriverIntrafusal20250627(t, delta_cdl, sarcB, sarcC);

% -- Force + yank -> Ia receptor potential ------------------------------
[r_t, ~, ~, r, rs, rd] = sarc2spindle_20240310( ...
    dataB, dataC, p.trans.kFc, p.trans.kFb, p.trans.kYb, ...
    p.trans.occlusion, p.trans.threshold);

% -- Drop the settle-in window ------------------------------------------
% The fibers start slack and unactivated, so the first ~0.2 s is the drive
% coming up to its operating point - a numerical startup transient, not
% anything physiological. It matters more than it looks: integrateAndFire_v2
% subtracts r(1) as the resting offset, so if the trace STARTS at the
% pre-activation value the whole tonic level survives into the integrator and
% firing pins at its ceiling (1/(4*dt)) for the entire run. Trimming first
% makes r(1) the settled resting level, which is what the manuscript's
% gait-cycle sims start from, and firing becomes informative again.
keepT = t >= p.sim.settle;        % keep the masks the same shape as the
keepR = r_t >= p.sim.settle;      % series they index, so orientation survives

% -- Predicted firing ---------------------------------------------------
% integrateAndFire_v2 returns the instantaneous rate as 1/ISI, so the FIRST
% spike has no defined rate (Inf). Drop non-finite entries.
[t_firing, IFR] = integrateAndFire_v2(r_t(keepR), r(keepR), 1);
ok = isfinite(IFR); t_firing = t_firing(ok); IFR = IFR(ok);

% -- Package ------------------------------------------------------------
kt = keepT;                     % shorthand; every series below is time-indexed
out.t         = t(kt);
out.L         = L(kt);          % fascicle length
out.delta_cdl = delta_cdl(kt);
out.mt        = mt;             % extrafusal MTU result (trimmed just below)
out.mt.alphaAct       = mt.alphaAct(kt);
out.mt.fascicleLength = mt.fascicleLength(kt);
out.mt.mtuCmd         = mt.mtuCmd(kt);
out.mt.mtuLength      = mt.mtuLength(kt);
out.mt.force          = mt.force(kt);
out.pCaB      = sarcB.pCa(kt);
out.pCaC      = sarcC.pCa(kt);
out.x_bins    = hsB.x_bins;     % strain bins - NOT time-indexed

% Fractional activation (0-1) of each drive, for display as % activation.
% (pCa is the model's internal variable; activation is the friendlier input.)
ac = loadActivationCurve();
out.actB     = min(max(ac.pCaToActB(out.pCaB(:)), 0), 1);    % bag / gamma-dynamic
out.actC     = min(max(ac.pCaToActC(out.pCaC(:)), 0), 1);    % chain / gamma-static
out.actAlpha = out.mt.alphaAct(:);                           % extrafusal / alpha

out.bag.hs_force      = dataB.hs_force(kt);
out.bag.cb_force      = dataB.cb_force(kt);
out.bag.passive_force = dataB.passive_force(kt);
out.bag.hs_length     = dataB.hs_length(kt);
out.bag.bin_pops      = dataB.bin_pops(:, kt);   % (bins x time)

out.chain.hs_force      = dataC.hs_force(kt);
out.chain.cb_force      = dataC.cb_force(kt);
out.chain.passive_force = dataC.passive_force(kt);
out.chain.hs_length     = dataC.hs_length(kt);
out.chain.bin_pops      = dataC.bin_pops(:, kt);   % (bins x time)

kr = keepR;
out.r_t      = r_t(kr);
out.r        = r(kr);
out.rs       = rs(kr);
out.rd       = rd(kr);
out.t_firing = t_firing;
out.IFR      = IFR;

out.params = p;
end


function sarc = applyKineticOverrides(sarc, ov)
% Apply non-empty override fields onto a fiber struct. Empty = keep default.
fields = {'f', 'g', 'power_stroke', 'k_passive', 'hsl_slack'};
for k = 1:numel(fields)
    f = fields{k};
    if isfield(ov, f) && ~isempty(ov.(f))
        sarc.(f) = ov.(f);
    end
end
end
