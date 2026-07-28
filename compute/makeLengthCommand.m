function [L, delta_cdl] = makeLengthCommand(t, protocol)
% makeLengthCommand  Build the fascicle length trace applied to the spindle.
%
%   [L, delta_cdl] = makeLengthCommand(t, protocol) returns the absolute
%   half-sarcomere length L(t) (nm) and its per-step increment delta_cdl (the
%   quantity the toolbox drivers consume). Both fibers experience the same
%   length, since bag and chain lie mechanically in parallel.
%
%   protocol fields (see defaultTutorialParams):
%     type          'ramp-hold' | 'sine' | 'triangle'
%     L0            baseline length (nm)
%     amplitude_pct stretch amplitude as % of L0
%     perturbStart  s, when the stretch begins (constant L0 before this)
%     rampDur       s, RISE time  (used by ramp-hold and triangle)
%     freq          Hz, cycle frequency (used by sine and triangle)
%
%   Which knobs matter for each type:
%     ramp-hold : rampDur              (single rise, then hold)
%     sine      : freq                 (continuous sinusoid)
%     triangle  : rampDur AND freq     (repeating: rise over rampDur, fall over
%                                       the rest of each 1/freq cycle)
%
%   A settle period (constant length before perturbStart) lets forces reach
%   steady state before the perturbation, matching the toolbox convention.

t  = t(:)';
n  = numel(t);
L0 = protocol.L0;
A  = (protocol.amplitude_pct / 100) * L0;   % nm
L  = L0 * ones(1, n);

isPerturb = t >= protocol.perturbStart;
tp = t - protocol.perturbStart;   % time since perturbation onset

switch lower(protocol.type)
    case 'ramp-hold'
        rampDur = max(protocol.rampDur, t(2) - t(1));   % avoid divide-by-zero
        ramping = isPerturb & (tp < rampDur);
        holding = isPerturb & (tp >= rampDur);
        L(ramping) = L0 + A * (tp(ramping) / rampDur);
        L(holding) = L0 + A;

    case 'sine'
        % Start at L0 and rise: L0 + A*(1 - cos) keeps the onset continuous.
        L(isPerturb) = L0 + A * (1 - cos(2*pi*protocol.freq * tp(isPerturb))) / 2;

    case 'triangle'
        % Repeating asymmetric triangle: within each 1/freq cycle, rise linearly
        % over rampDur, then fall linearly over the remainder. Uses BOTH rampDur
        % (rise time) and freq (repeat rate).
        period  = 1 / protocol.freq;
        rise    = min(max(protocol.rampDur, t(2) - t(1)), period);  % clamp to (0, period]
        fall    = max(period - rise, t(2) - t(1));
        phase   = mod(tp(isPerturb), period);            % time within current cycle
        tri     = zeros(size(phase));
        up      = phase <= rise;
        tri(up)  = phase(up) / rise;                     % 0 -> 1 over the rise
        tri(~up) = 1 - (phase(~up) - rise) / fall;       % 1 -> 0 over the fall
        L(isPerturb) = L0 + A * max(tri, 0);

    otherwise
        error('makeLengthCommand:badType', ...
            'Unknown protocol type "%s". Use ramp-hold, sine, or triangle.', ...
            protocol.type);
end

delta_cdl = [0, diff(L)];
end
