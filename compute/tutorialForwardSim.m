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
%     integrateAndFire                  -> predicted firing (IFR)
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

% -- Predicted firing ---------------------------------------------------
[t_firing, IFR] = integrateAndFire(r_t, r, 1);

% -- Package ------------------------------------------------------------
out.t         = t;
out.L         = L;              % fascicle length
out.delta_cdl = delta_cdl;
out.mt        = mt;             % extrafusal MTU result
out.pCaB      = sarcB.pCa;
out.pCaC      = sarcC.pCa;
out.x_bins    = hsB.x_bins;

% Fractional activation (0-1) of each drive, for display as % activation.
% (pCa is the model's internal variable; activation is the friendlier input.)
ac = loadActivationCurve();
out.actB     = min(max(ac.pCaToActB(sarcB.pCa(:)), 0), 1);   % bag / gamma-dynamic
out.actC     = min(max(ac.pCaToActC(sarcC.pCa(:)), 0), 1);   % chain / gamma-static
out.actAlpha = mt.alphaAct(:);                               % extrafusal / alpha

out.bag.hs_force      = dataB.hs_force;
out.bag.cb_force      = dataB.cb_force;
out.bag.passive_force = dataB.passive_force;
out.bag.hs_length     = dataB.hs_length;
out.bag.bin_pops      = dataB.bin_pops;

out.chain.hs_force      = dataC.hs_force;
out.chain.cb_force      = dataC.cb_force;
out.chain.passive_force = dataC.passive_force;
out.chain.hs_length     = dataC.hs_length;
out.chain.bin_pops      = dataC.bin_pops;

out.r_t      = r_t;
out.r        = r;
out.rs       = rs;
out.rd       = rd;
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
