function p = defaultTutorialParams()
% defaultTutorialParams  Canonical parameter set for the spindle tutorial.
%
%   p = defaultTutorialParams() returns a nested struct holding every knob the
%   tutorial exposes, at sensible default values. This is the single source of
%   truth: the app's "Reset" button and the headless tests both start here.
%
%   Parameter groups (the app mirrors this layout):
%     p.sim       - time base
%     p.protocol  - the length change applied to the whole muscle-tendon unit
%     p.mtu       - extrafusal muscle-tendon unit (alpha drive + tendon)
%     p.gamma     - fusimotor (gamma) drive to the bag and chain fibers
%     p.bag/chain - intrafusal fiber cross-bridge kinetics (overrides)
%     p.trans     - force/yank -> Ia receptor-potential transduction gains
%
%   Physical picture (see runExtrafusalMTU + tutorialForwardSim):
%       length command  ->  EXTRAFUSAL MTU (alpha-driven muscle + tendon)
%                              -> fascicle length
%                              -> INTRAFUSAL bag & chain fibers (gamma-driven)
%                              -> forces -> Ia receptor potential
%   The intrafusal fibers inherit the fascicle length; the tendon sits in series
%   with the extrafusal muscle, so not all of the MTU stretch reaches the fascicle.
%
%   pCa convention: pCa = -log10[Ca2+]. LOWER pCa = STRONGER activation.
%   pCa 9 ~ silent, pCa 4.5 ~ maximal. This matches the toolbox.

% -- Time base ----------------------------------------------------------
p.sim.dt   = 0.001;   % s, integration step (matches the toolbox convention)
p.sim.tEnd = 2.0;     % s, total simulated time

% -- Length protocol (applied to the MTU) -------------------------------
% A long ramp by default so the interesting phase fills most of the window.
p.protocol.type          = 'ramp-hold';  % 'ramp-hold' | 'sine' | 'triangle'
p.protocol.L0            = 1250;          % nm, baseline MTU command length
p.protocol.amplitude_pct = 8;            % stretch amplitude, % of L0
p.protocol.perturbStart  = 0.6;          % s, when the stretch begins - well after
                                         % the gamma onsets, so the drive has settled
                                         % and there is a real baseline to compare to
p.protocol.rampDur       = 0.6;          % s, rise time (ramp-hold & triangle)
p.protocol.freq          = 1;            % Hz, cycle frequency (sine & triangle)

% -- Extrafusal muscle-tendon unit --------------------------------------
p.mtu.enabled        = true;    % run the MTU; false = drive fascicle directly
p.mtu.tendonStiffness = 5e3;    % tendon stiffness (getDefaultSarcE default)
p.mtu.alphaMode      = 'constant';  % 'constant' | 'sine'
p.mtu.alphaLevel     = 35;      % alpha (extrafusal) activation, % (0-100)
p.mtu.alphaAmp       = 15;      % activation swing, % (sine mode)
p.mtu.alphaFreq      = 1;       % Hz (sine mode)
p.mtu.alphaPhase     = 0;       % rad (sine mode)

% -- Gamma (fusimotor) drive -------------------------------------------
% Chain fiber = gamma static ; Bag fiber = gamma dynamic (phasic burst).
% Levels are in % ACTIVATION (0-100) - the same units the app plots - and are
% converted to the model's pCa internally by makeGammaDrive.
p.gamma.chainMode      = 'constant';  % 'constant' | 'sine'
p.gamma.chainOn        = 0.15;        % s, chain (gamma-static) onset. NOT 0: the
                                      % run must START at zero activation, because
                                      % integrateAndFire_v2 takes r(1) as the resting
                                      % offset (the toolbox holds activation at zero
                                      % for the first 10 steps for the same reason)
p.gamma.chainLevel_pct = 30;          % % activation: level, or MEAN of the sine
p.gamma.chainAmp_pct   = 20;          % % activation, sine amplitude
p.gamma.chain_freq     = 1.0;         % Hz, sine frequency
p.gamma.chainPhase_s   = 0.0;         % s, sine phase relative to chainOn
% Deliberately low. integrateAndFire_v2 is refractory-limited to 1/(3*dt) and its
% rate quantises to 1/(k*dt), so above ~150 spikes/s the steps are 200 -> 250 and
% all detail is lost. The bag drives r hard, so anything above ~5% pins the whole
% trace at the ceiling. Turn it up in the Playground to see that happen - it is a
% real property of the model at dt = 1 ms, not a bug.
p.gamma.bagBurst_pct   = 4;           % % activation during the gamma-dynamic burst
p.gamma.bagOn          = 0.15;        % s, burst onset (see chainOn)
p.gamma.bagOff         = 1.8;         % s, burst offset

% -- Bag fiber kinetics (override; [] = toolbox default) ----------------
p.bag.f            = [];   % forward (attachment) rate scale
p.bag.g            = [];   % reverse (detachment) rate scale
p.bag.power_stroke = [];   % nm
p.bag.k_passive    = [];   % passive stiffness
p.bag.hsl_slack    = [];   % nm, slack length

% -- Chain fiber kinetics (override; [] = toolbox default) --------------
p.chain.f            = [];
p.chain.g            = [];
p.chain.power_stroke = [];
p.chain.k_passive    = [];
p.chain.hsl_slack    = [];

% -- Ia transduction (force + yank -> receptor potential) ---------------
% Defaults match runSpindleSimForGammaFwdSim.m (0.6, 1.1, 0.1, off, 0).
p.trans.kFc       = 0.6;    % static gain (chain force -> rs)
p.trans.kFb       = 1.1;    % dynamic force gain (bag force -> rd)
p.trans.kYb       = 0.1;    % yank gain (bag dF/dt -> rd)
p.trans.occlusion = false;  % branch competition between static & dynamic
p.trans.threshold = 0.0;    % firing threshold subtracted from r
end
