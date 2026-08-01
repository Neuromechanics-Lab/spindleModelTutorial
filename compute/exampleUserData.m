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

% gamma-STATIC is deliberately TIME-VARYING - a smooth rise and fall sweeping
% 10-60% activation. The optimizer's default model is a 5-control-point
% B-spline, so a constant truth (which this example used to have) gives it
% nothing to recover: every gamma-static mode scores the same and the B-spline
% looks pointless. A smooth waveform is representable by the spline and is what
% a real fusimotor drive would look like.
p.gamma.chainMode      = 'sine';
p.gamma.chainLevel_pct = 35;    % mean
p.gamma.chainAmp_pct   = 25;    % so it sweeps 10-60%
p.gamma.chain_freq     = 0.6;   % Hz - about one rise-and-fall over the trial
p.gamma.chainPhase_s   = 0;

% gamma-DYNAMIC kept low on purpose. The bag drives r far harder than the chain
% does, and at the 92% this example used to run, rms(r_d) was 5.5x rms(r_s) -
% the chain's contribution was swamped, so there was little for a fit to work
% with. At 10% the ratio is 2.2x: the bag still leads, as it should, but both
% components are visible in the trace.
p.gamma.bagBurst_pct   = 10;
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
