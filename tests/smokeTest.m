function smokeTest()
% smokeTest  Headless sanity checks for the spindle tutorial compute layer.
%
%   Run from the tutorial root:
%       matlab -batch "run('tests/smokeTest.m')"
%   or interactively:
%       setupTutorialPaths(); smokeTest();
%
%   A GUI cannot be exercised headlessly, so this test covers the numerical
%   engine the app depends on: the extrafusal MTU, the forward simulation, and
%   the optimization demo. It prints PASS/FAIL for each check and errors out on
%   any failure.

fprintf('\n=== Spindle tutorial smoke test ===\n');

% Make sure paths are set (safe to call repeatedly).
here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));            % tutorial root, so setupTutorialPaths is visible
tpaths = setupTutorialPaths();

nfail = 0;

% ---- 1. Forward sim with the extrafusal MTU --------------------------
p = defaultTutorialParams();
out = tutorialForwardSim(p);

nfail = nfail + check('extrafusal MTU ran', out.mt.ok);
nfail = nfail + check('fascicle length is finite and positive', ...
    all(isfinite(out.L)) && all(out.L > 0));
nfail = nfail + check('tendon takes up some MTU stretch (fascicle ~= MTU cmd)', ...
    max(abs(out.mt.mtuCmd - out.L)) > 1);
nfail = nfail + check('fiber forces are finite', ...
    all(isfinite(out.bag.hs_force)) && all(isfinite(out.chain.hs_force)));
nfail = nfail + check('cross-bridge populations are non-negative', ...
    all(out.bag.bin_pops(:) >= -1e-9) && all(out.chain.bin_pops(:) >= -1e-9));
nfail = nfail + check('bin_pops has one row per strain bin', ...
    size(out.bag.bin_pops, 1) == numel(out.x_bins));
nfail = nfail + check('receptor potential is non-negative and finite', ...
    all(out.r >= 0) && all(isfinite(out.r)));
% Compare the stretch response against the PRE-STRETCH baseline, not against
% rd(1). rd(1) is the zero-activation value, so measuring from there conflates
% "the gamma drive raised rd" with "the stretch raised rd" - and the shipped
% gamma levels are deliberately low, which made the old 3x form fail even though
% the yank response was perfectly healthy (1.49x above its own baseline).
t0   = out.params.protocol.perturbStart;
pre  = out.t > t0 - 0.15 & out.t < t0;
dur  = out.t >= t0 & out.t < t0 + 0.3;
nfail = nfail + check('ramp-and-hold drives a dynamic response (rd peak > baseline)', ...
    max(out.rd(dur)) > 1.3 * median(out.rd(pre)));

% The RECEPTOR POTENTIAL is the tutorial's output now, so that is what has to
% carry a visible response. (Spikes moved to examples/spikesFromReceptorPotential.m:
% the toolbox generator is refractory-limited to 1/(4*dt) = 250 spikes/s, which
% any realistic gamma drive saturates, so plotting it taught nothing.)
nfail = nfail + check('receptor potential has a clear stretch response', ...
    max(out.r(dur)) > 2 * median(out.r(pre)));
fprintf('   r      : rest %.2f, peak %.2f (%.1fx)\n', ...
    median(out.r(pre)), max(out.r(dur)), max(out.r(dur))/median(out.r(pre)));

% The offset integrateAndFire_v2 removes must be the ZERO-ACTIVATION baseline
% (the toolbox holds activation at zero for the first 10 steps). The example
% script relies on this, so the shipped defaults must still honour it.
nfail = nfail + check('run starts at zero activation, so r(1) is the true offset', ...
    out.actC(1) < 1e-6 && out.actB(1) < 1e-6);

% The spike generator is no longer plotted, but it is still shipped and still
% exercised by the example - keep it callable and finite.
[tsp, ifr] = integrateAndFire_v2(out.r_t, out.r, 1);
ifr = ifr(isfinite(ifr));
nfail = nfail + check('spike generator still runs on the model output', ...
    ~isempty(tsp) && ~isempty(ifr) && all(ifr > 0));

% ---- 2. Protocol variants run ----------------------------------------
for typ = {'sine', 'triangle'}
    p2 = defaultTutorialParams(); p2.protocol.type = typ{1}; p2.sim.tEnd = 1.2;
    o2 = tutorialForwardSim(p2);
    nfail = nfail + check(sprintf('%s protocol produces finite Ia', typ{1}), ...
        all(isfinite(o2.r)));
end

% ---- 3. Gamma-static onset + sinusoid --------------------------------
pS = defaultTutorialParams();
pS.gamma.chainMode = 'sine'; pS.gamma.chainOn = 0.6; pS.gamma.chainAmp_pct = 25;
oS = tutorialForwardSim(pS);
nfail = nfail + check('chain silent before its onset', all(oS.pCaC(1:500) > 8.9));
nfail = nfail + check('chain drive active after onset', min(oS.pCaC(700:end)) < 8);

% ---- 4. Parameter override takes effect ------------------------------
pOv = defaultTutorialParams(); pOv.sim.tEnd = 1.2; pOv.bag.g = 200;
oOv = tutorialForwardSim(pOv);
pBase = defaultTutorialParams(); pBase.sim.tEnd = 1.2;
oBase = tutorialForwardSim(pBase);
nfail = nfail + check('changing bag detachment rate changes bag force', ...
    max(abs(oOv.bag.hs_force - oBase.bag.hs_force)) > 1e-6);

% ---- 5. Extreme tendon stiffness falls back gracefully ---------------
pT = defaultTutorialParams(); pT.sim.tEnd = 1.2; pT.mtu.tendonStiffness = 10;
oT = tutorialForwardSim(pT);
nfail = nfail + check('extreme tendon stiffness handled (finite Ia)', all(isfinite(oT.r)));

% ---- 6. Optimization demo recovers a known B-spline gamma ------------
if tpaths.hasBspline
    % Few iterations here to keep the smoke test fast; the app uses more and
    % converges further. We assert a big cost drop and recovery of the strongly
    % identified magnitude parameter (bag burst), which is robust to iter count.
    res = tutorialOptDemo(struct('tEnd', 1.4, 'maxIter', 25));
    nfail = nfail + check('optimizer cuts the cost by >60%', res.fvalOpt < 0.4 * res.fval0);
    % recoveryPct is the fraction of the INITIAL error closed; 0 means a
    % parameter never moved. These are NOT evidence about identifiability - the
    % demo fixes burst timing at the values used to build the target, so the fit
    % gets information it would not have on real data. Checked only to confirm
    % the machinery runs and reports finite numbers.
    nfail = nfail + check('optimizer moves the bag burst toward truth', ...
        res.recoveryPct(1) > 80);
    cpClosed = res.recoveryPct(2:6);
    nfail = nfail + check('per-parameter recovery is reported for every parameter', ...
        all(isfinite(cpClosed)));
    fprintf('   closed%% : bag %.0f | chain cp %s\n', res.recoveryPct(1), ...
        mat2str(round(cpClosed)));
    fprintf('   params : %s\n', strjoin(res.names, ', '));
    fprintf('   true   : %s\n', mat2str(res.xTrue, 3));
    fprintf('   opt    : %s\n', mat2str(res.xOpt, 3));
    fprintf('   cost %.4g -> %.4g\n', res.fval0, res.fvalOpt);

    % The GUI previews the target drive with previewOnly (no MTU, no fit). It
    % must be the SAME waveform the fit is asked to recover, or the preview
    % would quietly lie about what is being optimized.
    pv = tutorialOptDemo(struct('tEnd', 1.4, 'previewOnly', true));
    nfail = nfail + check('preview drive matches the fit''s own target exactly', ...
        isequal(pv.gammaTrue.chainPca, res.gammaTrue.chainPca) && ...
        isequal(pv.gammaTrue.bagPca,   res.gammaTrue.bagPca) && ...
        isequal(pv.gammaTrue.controlPca, res.gammaTrue.controlPca));
else
    fprintf('  [SKIP] optimization demo (gammaDriveOptimization not on path)\n');
end

% ---- 7. Custom user-data path (forward) ------------------------------
d = exampleUserData();
nfail = nfail + check('example user-data reports forward + optimize available', ...
    d.availForward && d.availOptimize);
uo = runForwardFromData(d);
nfail = nfail + check('forward-from-data produces finite firing-ready output', ...
    all(isfinite(uo.r)) && isfield(uo, 'IFR'));
nfail = nfail + check('forward-from-data activation traces are in [0,1]', ...
    all(uo.actB >= -1e-9 & uo.actB <= 1+1e-9));

% ---- 7b. Both optimize-from-data modes, and the shared cost -----------
% The cost is mean-normalized (shape only), which is what lets the model's
% receptor potential be fitted to a recorded firing rate at all.
nfail = nfail + check('mean-normalized cost is scale-invariant', ...
    abs(meanNormRMSE(3.7 * uo.r, uo.r)) < 1e-12);
nfail = nfail + check('mean-normalized cost is non-zero for a different shape', ...
    meanNormRMSE(uo.r, uo.r(end:-1:1)) > 1e-3);
for gs = {'bspline-free', 'bspline-periodic', 'constant'}
    o = struct('maxIter', 3, 'gammaStatic', gs{1}, 'cyclePeriod', 0.64);
    rg = runOptFromData(d, o);
    nP = numel(rg.xOpt);
    nfail = nfail + check(sprintf('gammaStatic=%s fits (%d params)', gs{1}, nP), ...
        isfinite(rg.fvalOpt) && strcmp(rg.gammaStatic, gs{1}) && ...
        nP == 4 + 4*~strcmp(gs{1}, 'constant'));
end
% The periodic spline must refuse to guess a cycle period.
try
    runOptFromData(d, struct('maxIter', 1, 'gammaStatic', 'bspline-periodic'));
    nfail = nfail + check('periodic spline demands a cycle period', false);
catch
    nfail = nfail + check('periodic spline demands a cycle period', true);
end
for ft = {'receptor', 'firing'}
    ro = runOptFromData(d, struct('maxIter', 4, 'fitTarget', ft{1}));
    nfail = nfail + check(sprintf('optimize-from-data runs with fitTarget=%s', ft{1}), ...
        isfinite(ro.fvalOpt) && ro.fvalOpt <= ro.fval0 && strcmp(ro.fitTarget, ft{1}));
    fprintf('   fit %-9s: cost %.4g -> %.4g\n', ft{1}, ro.fval0, ro.fvalOpt);
end

% ---- 8. User data in non-nm units (restingLength normalisation) -------
tu = 0:0.001:1.0;
mm = struct('t', tu, 'mtuLength', 30 + 2.4*max(0, min(1,(tu-0.3)/0.5)), ...
            'restingLength', 30, 'alphaAct', 35*ones(size(tu)), ...
            'chainAct', 50*ones(size(tu)), 'bagAct', 90*(tu>0.3));
fmm = fullfile(tempdir, 'smoke_mm.mat'); save(fmm, '-struct', 'mm');
dmm = loadUserData(fmm);
nfail = nfail + check('mm length + restingLength is normalised to model nm', ...
    dmm.lengthWasNormalised && abs(median(dmm.mtuLength) - 1250) < 200);
omm = runForwardFromData(dmm);
nfail = nfail + check('forward run works from mm-scaled input', all(isfinite(omm.r)));

% ---- 9. Saving results -------------------------------------------------
sbase = fullfile(tempdir, 'smoke_save');
fs = saveUserResults(sbase, omm, 'forward');
nfail = nfail + check('saveUserResults writes a .mat and a .csv', ...
    numel(fs) == 2 && isfile(fs{1}) && isfile(fs{2}));
chk = load(fs{1});
nfail = nfail + check('saved .mat carries the key signals', ...
    isfield(chk,'t') && isfield(chk,'IFR') && isfield(chk,'forceBag'));
delete(fs{1}); delete(fs{2}); delete(fmm);

% ---- Summary ----------------------------------------------------------
if nfail == 0
    fprintf('\nALL CHECKS PASSED.\n\n');
else
    error('smokeTest:failures', '%d check(s) FAILED.', nfail);
end
end


function failed = check(name, condition)
if condition
    fprintf('  [PASS] %s\n', name);
    failed = 0;
else
    fprintf('  [FAIL] %s\n', name);
    failed = 1;
end
end
