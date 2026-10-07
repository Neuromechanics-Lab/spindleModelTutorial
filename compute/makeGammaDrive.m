function [sarcB, sarcC] = makeGammaDrive(t, gamma, sarcB, sarcC)
% makeGammaDrive  Set intrafusal fiber activation (pCa) from fusimotor drive.
%
%   [sarcB, sarcC] = makeGammaDrive(t, gamma, sarcB, sarcC) fills the per-step
%   pCa vectors sarcB.pCa and sarcC.pCa from the gamma-drive parameters, and
%   returns the updated fiber structs ready for the intrafusal driver.
%
%   Biology encoded here:
%     - Chain fiber  <- gamma STATIC : a maintained drive that switches on at
%       chainOn. A constant level, a sinusoid, or a 5-control-point B-spline
%       (chainMode = 'constant' | 'sine' | 'bspline'; see the bspline branch for
%       the periodic vs free variants).
%     - Bag fiber    <- gamma DYNAMIC: a phasic burst (silent baseline with a
%       rectangular burst between bagOn/bagOff), or - bagMode = 'bspline', pCa
%       domain only - a 5-control-point B-spline from bagOn, built exactly like
%       the chain's (gamma.bag_cp, gamma.bag_periodic, gamma.bag_cyclePeriod).
%       That is the manuscript's Figure 1D form.
%
%   TWO WAYS TO SPECIFY THE DRIVE LEVELS
%   ------------------------------------
%   (a) % ACTIVATION (0-100), the friendly units the app shows on its plots:
%           gamma.chainLevel_pct   chain level, or the MEAN of the sinusoid
%           gamma.chainAmp_pct     sinusoid amplitude, % activation
%           gamma.chainPhase_s     sinusoid phase, SECONDS relative to chainOn
%           gamma.bagBurst_pct     bag burst level
%       The sinusoid is built in ACTIVATION space and then mapped to pCa, so it
%       matches the activation trace the app plots. (A sinusoid in pCa would look
%       distorted in activation, because the two are related nonlinearly.)
%
%   (b) pCa, the model's own internal variable - used by the optimization code,
%       which fits pCa directly:
%           gamma.chain_pCa, gamma.chain_amp, gamma.chain_phase (radians),
%           gamma.bagBurst, gamma.bagBaseline
%
%   Per fiber, the %-activation fields win if present; otherwise the pCa fields
%   are used. Shared by both: chainMode, chainOn, chain_freq, bagOn, bagOff.
%
%   pCa is clamped to the model's valid range [4.5, 9], and the first 10 samples
%   are forced silent (pCa = 9), matching the toolbox onset convention.
%
%   pCa convention: LOWER pCa = STRONGER activation (9 ~ silent, 4.5 ~ maximal).

t = t(:);
n = numel(t);
pCaFloor = 4.5;
pCaCeil  = 9.0;

usePctChain = isfield(gamma, 'chainLevel_pct') && ~isempty(gamma.chainLevel_pct);
usePctBag   = isfield(gamma, 'bagBurst_pct')   && ~isempty(gamma.bagBurst_pct);
if usePctChain || usePctBag
    ac = loadActivationCurve();   % cached; cheap to call
end

% -- Chain fiber: gamma static -----------------------------------------
% Silent until chainOn, then the chosen drive. Time is measured from onset, so
% the sinusoid's phase is referenced to when the drive starts.
sarcC.pCa = pCaCeil * ones(n, 1);
onIdx = find(t >= gamma.chainOn, 1, 'first');
% If the onset is beyond the simulated window, the chain simply stays silent.
if ~isempty(onIdx)
    active = onIdx:n;
    tRel = t(active) - t(onIdx);   % time since onset (phase reference)

    if usePctChain
        % Build the drive in ACTIVATION space (0-1), then convert to pCa.
        switch lower(gamma.chainMode)
            case 'constant'
                actC = (gamma.chainLevel_pct / 100) * ones(numel(active), 1);
            case 'sine'
                % Phase given in SECONDS: shift the wave along time.
                actC = (gamma.chainLevel_pct / 100) + (gamma.chainAmp_pct / 100) * ...
                    sin(2*pi*gamma.chain_freq * (tRel - gamma.chainPhase_s));
            otherwise
                error('makeGammaDrive:badChainMode', ...
                    'Unknown chainMode "%s". Use constant or sine.', gamma.chainMode);
        end
        actC = min(max(actC, 0), 1);
        sarcC.pCa(active) = ac.actToPcaC(actC);
    else
        % pCa domain (optimization path).
        switch lower(gamma.chainMode)
            case 'constant'
                sarcC.pCa(active) = gamma.chain_pCa;
            case 'sine'
                sarcC.pCa(active) = gamma.chain_pCa - ...
                    gamma.chain_amp * sin(2*pi*gamma.chain_freq*tRel + gamma.chain_phase);
            case 'bspline'
                % 5 control points in pCa; periodic or free (see splineDrive).
                per = [];
                if isfield(gamma, 'chain_periodic') && gamma.chain_periodic
                    per = gamma.chain_cyclePeriod;
                end
                sarcC.pCa(active) = splineDrive(gamma.chain_cp, tRel, per);
            otherwise
                error('makeGammaDrive:badChainMode', ...
                    'Unknown chainMode "%s". Use constant, sine or bspline.', gamma.chainMode);
        end
    end
end

% -- Bag fiber: gamma dynamic ------------------------------------------
if isfield(gamma, 'bagMode') && strcmpi(gamma.bagMode, 'bspline')
    % B-spline (pCa domain), silent until bagOn - same construction as chain.
    sarcB.pCa = pCaCeil * ones(n, 1);
    onB = find(t >= gamma.bagOn, 1, 'first');
    if ~isempty(onB)
        per = [];
        if isfield(gamma, 'bag_periodic') && gamma.bag_periodic
            per = gamma.bag_cyclePeriod;
        end
        sarcB.pCa(onB:n) = splineDrive(gamma.bag_cp, t(onB:n) - t(onB), per);
    end
else
    % Phasic burst.
    if usePctBag
        baselinePca = ac.actToPcaB(0);              % 0% activation = silent
        burstPca    = ac.actToPcaB(min(max(gamma.bagBurst_pct/100, 0), 1));
    else
        baselinePca = gamma.bagBaseline;
        burstPca    = gamma.bagBurst;
    end
    sarcB.pCa = baselinePca * ones(n, 1);
    burst = (t >= gamma.bagOn) & (t <= gamma.bagOff);
    sarcB.pCa(burst) = burstPca;
end

% -- Clamp + silent onset ----------------------------------------------
sarcB.pCa = min(max(sarcB.pCa, pCaFloor), pCaCeil);
sarcC.pCa = min(max(sarcC.pCa, pCaFloor), pCaCeil);
sarcB.pCa(1:min(10, n)) = pCaCeil;
sarcC.pCa(1:min(10, n)) = pCaCeil;
end


function pCa = splineDrive(cp, tRel, per)
% 5 control points in pCa, spline-interpolated over time since onset. Two
% variants:
%
%  PERIODIC (per = cycle period) reproduces the manuscript's construction
%  (getIntrafusal_pCa_Bspline_5cp): points sit at 0/20/40/60/80% of one cycle, a
%  sixth point repeats the first so the waveform joins up, and the cycle is
%  tiled across the trial. Use it when the protocol really is cyclic - it ties
%  every cycle to one waveform, so 5 numbers describe all of them.
%
%  FREE (per empty) spreads the same 5 points evenly across the ACTIVE window
%  with no wrap constraint, so it can express a constant (all points equal), a
%  ramp (monotonic points) or any smooth shape. Use it for arbitrary protocols,
%  where a repeating waveform would be meaningless.
cp = cp(:); tRel = tRel(:);
if ~isempty(per)
    ctrlT = linspace(0, 1, numel(cp) + 1)' * per;   % one cycle
    ctrlV = [cp; cp(1)];                            % last = first
    pCa   = interp1(ctrlT, ctrlV, mod(tRel, per), 'spline');
else
    span  = max(tRel(end), eps);
    ctrlT = linspace(0, span, numel(cp))';
    pCa   = interp1(ctrlT, cp, tRel, 'spline');
end
end
