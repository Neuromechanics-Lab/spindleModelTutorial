function [sarcB, sarcC] = makeGammaDrive(t, gamma, sarcB, sarcC)
% makeGammaDrive  Set intrafusal fiber activation (pCa) from fusimotor drive.
%
%   [sarcB, sarcC] = makeGammaDrive(t, gamma, sarcB, sarcC) fills the per-step
%   pCa vectors sarcB.pCa and sarcC.pCa from the gamma-drive parameters, and
%   returns the updated fiber structs ready for the intrafusal driver.
%
%   Biology encoded here:
%     - Chain fiber  <- gamma STATIC : a maintained drive that switches on at
%       chainOn. Either a constant level or a sinusoid (chainMode).
%     - Bag fiber    <- gamma DYNAMIC: a phasic burst. Silent baseline with a
%       rectangular burst between bagOn/bagOff.
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
            otherwise
                error('makeGammaDrive:badChainMode', ...
                    'Unknown chainMode "%s". Use constant or sine.', gamma.chainMode);
        end
    end
end

% -- Bag fiber: gamma dynamic (phasic burst) ---------------------------
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

% -- Clamp + silent onset ----------------------------------------------
sarcB.pCa = min(max(sarcB.pCa, pCaFloor), pCaCeil);
sarcC.pCa = min(max(sarcC.pCa, pCaFloor), pCaCeil);
sarcB.pCa(1:min(10, n)) = pCaCeil;
sarcC.pCa(1:min(10, n)) = pCaCeil;
end
