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
% A firing rate to optimize against. It is NOT produced by pushing this run
% through integrateAndFire_v2: that generator clips at 1/(4*dt) = 250 spikes/s,
% and at any interesting drive level the result is pinned there for most of the
% trace (65-90% of samples), which is an artefact of the time step rather than
% anything a real afferent does. Fitting against a clipped target would also
% unfairly handicap the default 'receptor' mode, which compares an UNclipped r.
%
% Instead the target is what an afferent with its own gain and threshold would
% have fired: rectified-linear in the receptor potential, rate = a*(r - rThr),
% scaled to a physiological peak. Below the spike generator's ceiling that is
% exactly the relationship the model implies (rate = r/threshold), and it is the
% relationship the mean-normalized cost relies on - see compute/meanNormRMSE.m.
rThr = 0.6 * min(ref.r);                        % afferent threshold
rate = max(0, ref.r(:)' - rThr);
d.targetFiring = movmean(rate * (180 / max(rate)), max(3, round(0.05 / d.dt)));
d.tendonStiffness = p.mtu.tendonStiffness;
d.availForward = true; d.availOptimize = true;
d.file = '(built-in example)';
end
