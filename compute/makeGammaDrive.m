function [sarcB, sarcC] = makeGammaDrive(t, gamma, sarcB, sarcC)
% makeGammaDrive  Set intrafusal fiber activation (pCa) from fusimotor drive.
%
%   [sarcB, sarcC] = makeGammaDrive(t, gamma, sarcB, sarcC) fills the per-step
%   pCa vectors sarcB.pCa and sarcC.pCa from the gamma-drive parameters, and
%   returns the updated fiber structs ready for the intrafusal driver.
%
%   Biology encoded here:
%     - Chain fiber  <- gamma STATIC : a maintained drive that switches on at
%       chainOn. Either a constant pCa level or a sinusoid with adjustable
%       vertical offset (chain_pCa), amplitude, frequency and phase (chainMode).
%     - Bag fiber    <- gamma DYNAMIC: a phasic burst. Silent baseline pCa with
%       a rectangular burst to a lower (more-activated) pCa between bagOn/bagOff.
%
%   This mirrors getIntrafusal_pCa_IdealSine.m / getIntrafusal_pCa_Constant.m
%   from gammaDriveOptimization, but works directly in pCa (the quantity the
%   toolbox driver consumes) to keep the tutorial dependency-free.
%
%   pCa is clamped to the model's valid range [4.5, 9], and the first 10 samples
%   are forced silent (pCa = 9), matching the toolbox onset convention.

t = t(:);
n = numel(t);
pCaFloor = 4.5;
pCaCeil  = 9.0;

% -- Chain fiber: gamma static -----------------------------------------
% Silent (pCa = ceil) until chainOn, then the chosen drive. Time is measured
% from onset so the sinusoid's phase is referenced to when the drive starts.
sarcC.pCa = pCaCeil * ones(n, 1);
onIdx = find(t >= gamma.chainOn, 1, 'first');
% If the onset is beyond the simulated window, the chain simply stays silent.
if ~isempty(onIdx)
    active = onIdx:n;
    tRel = t(active) - t(onIdx);   % time since onset (phase reference)
    switch lower(gamma.chainMode)
        case 'constant'
            sarcC.pCa(active) = gamma.chain_pCa;
        case 'sine'
            % Vertical offset = chain_pCa (mean level); amplitude/freq/phase adjustable.
            sarcC.pCa(active) = gamma.chain_pCa - ...
                gamma.chain_amp * sin(2*pi*gamma.chain_freq*tRel + gamma.chain_phase);
        otherwise
            error('makeGammaDrive:badChainMode', ...
                'Unknown chainMode "%s". Use constant or sine.', gamma.chainMode);
    end
end

% -- Bag fiber: gamma dynamic (phasic burst) ---------------------------
sarcB.pCa = gamma.bagBaseline * ones(n, 1);
burst = (t >= gamma.bagOn) & (t <= gamma.bagOff);
sarcB.pCa(burst) = gamma.bagBurst;

% -- Clamp + silent onset ----------------------------------------------
sarcB.pCa = min(max(sarcB.pCa, pCaFloor), pCaCeil);
sarcC.pCa = min(max(sarcC.pCa, pCaFloor), pCaCeil);
sarcB.pCa(1:min(10, n)) = pCaCeil;
sarcC.pCa(1:min(10, n)) = pCaCeil;
end
