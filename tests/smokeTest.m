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
nfail = nfail + check('ramp-and-hold drives a dynamic response (rd peak > baseline)', ...
    max(out.rd) > 3 * (out.rd(1) + eps));

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
    res = tutorialOptDemo(struct('tEnd', 1.4, 'maxIter', 10));
    nfail = nfail + check('optimizer cuts the cost by >60%', res.fvalOpt < 0.4 * res.fval0);
    nfail = nfail + check('optimizer recovers bag-burst magnitude (>85%)', ...
        res.recoveryPct(1) > 85);
    fprintf('   params : %s\n', strjoin(res.names, ', '));
    fprintf('   true   : %s\n', mat2str(res.xTrue, 3));
    fprintf('   opt    : %s\n', mat2str(res.xOpt, 3));
    fprintf('   recov%% : %s\n', mat2str(round(res.recoveryPct), 3));
    fprintf('   cost %.4g -> %.4g\n', res.fval0, res.fvalOpt);
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
