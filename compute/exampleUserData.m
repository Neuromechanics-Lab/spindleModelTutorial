function d = exampleUserData()
% exampleUserData  A built-in demo dataset in the user-data format.
%
%   d = exampleUserData() returns a normalized user-data struct (the same shape
%   loadUserData produces) so the "Your data" tab can demonstrate both a FORWARD
%   run and a gamma OPTIMIZE run without needing an external file. It is generated
%   from a known model run, so the optimizer has a real target to recover.
%
%   It also shows exactly what fields a user's own .mat should contain.

p = defaultTutorialParams(); p.sim.tEnd = 1.8;
% (% activation; ~pCa 6.2 and 5.8 on the chain/bag curves respectively)
p.gamma.chainLevel_pct = 34; p.gamma.bagBurst_pct = 92;
p.gamma.bagOn = 0.35; p.gamma.bagOff = 1.15;
ref = tutorialForwardSim(p);

t = ref.t;
d.t = t; d.dt = t(2) - t(1); d.n = numel(t);
d.mtuLength = ref.mt.mtuCmd(:)';   d.hasFascicle = false; d.fascicleLength = [];
d.alphaAct  = ref.actAlpha(:)';    % 0..1
d.chainAct  = ref.actC(:)';        % 0..1  (so a forward run is possible)
d.bagAct    = ref.actB(:)';        % 0..1
if isempty(ref.t_firing)
    d.targetFiring = zeros(1, d.n);
else
    d.targetFiring = movmean(interp1(ref.t_firing, ref.IFR, t, 'linear', 0), ...
        max(3, round(0.05 / d.dt)));   % a firing rate to optimize against
end
d.tendonStiffness = p.mtu.tendonStiffness;
d.availForward = true; d.availOptimize = true;
d.file = '(built-in example)';
end
