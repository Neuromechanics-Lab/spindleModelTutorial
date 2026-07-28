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
p.protocol.perturbStart  = 0.3;          % s, when the stretch begins
p.protocol.rampDur       = 0.8;          % s, rise time (ramp-hold & triangle)
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
p.gamma.chainMode     = 'constant';  % 'constant' | 'sine'
p.gamma.chainOn       = 0.3;         % s, chain (gamma-static) onset
p.gamma.chain_pCa     = 6.0;         % gamma static level / sine vertical offset
p.gamma.chain_amp     = 0.5;         % gamma static sine amplitude (pCa)
p.gamma.chain_freq    = 1.0;         % gamma static sine frequency (Hz)
p.gamma.chain_phase   = 0.0;         % gamma static sine phase (rad)
p.gamma.bagBaseline   = 9.0;         % bag pCa when gamma-dynamic is silent
p.gamma.bagBurst      = 6.0;         % bag pCa during the gamma-dynamic burst
p.gamma.bagOn         = 0.3;         % s, burst onset
p.gamma.bagOff        = 1.1;         % s, burst offset

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
