function out = runForwardFromData(d)
% runForwardFromData  Forward-run the spindle model on user-supplied inputs.
%
%   out = runForwardFromData(d) takes a normalized user-data struct (from
%   loadUserData) that provides length + activations, and runs the full model
%   (extrafusal MTU -> intrafusal fibers -> receptor potential -> firing). The
%   returned struct matches tutorialForwardSim's output, so the app plots it the
%   same way.
%
%   Unlike tutorialForwardSim, the fiber activations come DIRECTLY from the user
%   (converted activation -> pCa), rather than from parametric gamma-drive knobs.

t  = d.t(:)';
n  = d.n;
ac = loadActivationCurve();

% -- Fascicle length: from the user's fascicle trace, or via the MTU ---
if d.hasFascicle
    fascicle = d.fascicleLength(:)';
    mt = struct('fascicleLength', fascicle, 'mtuCmd', fascicle, ...
        'mtuLength', fascicle, 'alphaAct', zeros(n,1), 'ok', true, 'message', '', ...
        'force', zeros(1,n));
else
    p = defaultTutorialParams();
    p.mtu.tendonStiffness = d.tendonStiffness;
    alpha = d.alphaAct; if isempty(alpha), alpha = zeros(1,n); end
    mt = runExtrafusalMTU(t, p, d.mtuLength, alpha);
    fascicle = mt.fascicleLength;
end
delta_cdl = [0, diff(fascicle)];

% -- Intrafusal fibers, driven by user activations (-> pCa) ------------
sarcB = getDefaultSarcB();
sarcC = getDefaultSarcC();
sarcB.hs_length = fascicle(1); sarcB.cmd_length = fascicle(1);
sarcC.hs_length = fascicle(1); sarcC.cmd_length = fascicle(1);

pCaB = actToPca(ac.actToPcaB, d.bagAct, n);
pCaC = actToPca(ac.actToPcaC, d.chainAct, n);

% -- Settle lead-in -----------------------------------------------------
% The fibers start slack and unactivated. Without a lead-in the resting level
% is still climbing when the user's window opens, and since integrateAndFire_v2
% takes r(1) as the resting offset, that whole tonic level stays in the
% integrator and firing pins at its ceiling. So hold the first sample for
% p.sim.settle, run, then trim back to exactly the user's time range - no user
% data is dropped, only simulated lead-in.
dt    = t(2) - t(1);
nLead = max(1, round(defaultTutorialParams().sim.settle / dt));
tRun        = [t(1) - (nLead:-1:1)*dt, t];
fascicleRun = [repmat(fascicle(1), 1, nLead), fascicle];
sarcB.pCa   = [repmat(pCaB(1), 1, nLead), pCaB(:)'];
sarcC.pCa   = [repmat(pCaC(1), 1, nLead), pCaC(:)'];
% Toolbox convention: a run starts silent. Apply it to the head of the LEAD-IN,
% so the user's own window keeps the activation they supplied.
sarcB.pCa(1:min(10, numel(sarcB.pCa))) = 9;
sarcC.pCa(1:min(10, numel(sarcC.pCa))) = 9;

[hsB, dataB, ~, dataC] = sarcSimDriverIntrafusal20250627( ...
    tRun, [0, diff(fascicleRun)], sarcB, sarcC);

% -- Receptor potential + firing (default transduction gains) ----------
tr = defaultTutorialParams().trans;
[r_t, ~, ~, r, rs, rd] = sarc2spindle_20240310(dataB, dataC, ...
    tr.kFc, tr.kFb, tr.kYb, tr.occlusion, tr.threshold);
keepR = r_t >= t(1);
[t_firing, IFR] = integrateAndFire_v2(r_t(keepR), r(keepR), 1);
ok = isfinite(IFR); t_firing = t_firing(ok); IFR = IFR(ok);   % 1st spike has no ISI

% Trim the lead-in back off everything the caller sees.
keep = (nLead+1):numel(tRun);
for f = {'hs_force','cb_force','passive_force','hs_length'}
    dataB.(f{1}) = dataB.(f{1})(keep);
    dataC.(f{1}) = dataC.(f{1})(keep);
end
dataB.bin_pops = dataB.bin_pops(:, keep);
dataC.bin_pops = dataC.bin_pops(:, keep);
r_t = r_t(keepR); r = r(keepR); rs = rs(keepR); rd = rd(keepR);
sarcB.pCa = pCaB; sarcC.pCa = pCaC;

% -- Package (same shape as tutorialForwardSim) ------------------------
out.t = t; out.L = fascicle; out.delta_cdl = delta_cdl; out.mt = mt;
out.pCaB = sarcB.pCa; out.pCaC = sarcC.pCa; out.x_bins = hsB.x_bins;
out.actB = min(max(ac.pCaToActB(sarcB.pCa(:)),0),1);
out.actC = min(max(ac.pCaToActC(sarcC.pCa(:)),0),1);
out.actAlpha = mt.alphaAct(:);
out.bag.hs_force = dataB.hs_force; out.bag.cb_force = dataB.cb_force;
out.bag.passive_force = dataB.passive_force; out.bag.hs_length = dataB.hs_length;
out.bag.bin_pops = dataB.bin_pops;
out.chain.hs_force = dataC.hs_force; out.chain.cb_force = dataC.cb_force;
out.chain.passive_force = dataC.passive_force; out.chain.hs_length = dataC.hs_length;
out.chain.bin_pops = dataC.bin_pops;
out.r_t = r_t; out.r = r; out.rs = rs; out.rd = rd;
out.t_firing = t_firing; out.IFR = IFR;
out.targetFiring = d.targetFiring;   % carried through for overlay, if present
end


function pCa = actToPca(actToPcaFn, act, n)
% Convert a 0..1 activation trace to pCa; absent -> silent (pCa 9).
if isempty(act)
    pCa = 9 * ones(n, 1);
else
    pCa = min(max(actToPcaFn(act(:)), 4.5), 9);
end
% NB: the toolbox's silent-onset convention is applied by the caller, to the
% start of the SIMULATED run (the lead-in) rather than here. Doing it here
% silenced the value the lead-in holds, so the fiber never settled.
end
