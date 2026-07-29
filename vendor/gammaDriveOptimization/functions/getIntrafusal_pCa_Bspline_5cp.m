function [sarcC, sarcB] = getIntrafusal_pCa_Bspline_5cp(t, sineStart, ~, act_freq, sarcC, sarcB, gDynOnPct, gDynOffPct, sarcC_control_points, sarcC_phaseShift_s, sarcC_pCaToActGridded, sarcC_ActToPcaGridded)
% Generate intrafusal fiber activation using B-splines for gamma static (5 control points)
%
% This version uses B-spline interpolation with 5 control points to define
% gamma static activation profile, allowing more flexible temporal patterns
% than versions with fewer control points.
%
% Inputs:
%   t - time vector
%   sineStart - index where perturbation starts
%   ~ - MTUfreq (not used, kept for compatibility)
%   act_freq - activation frequency (for gamma dynamic timing)
%   sarcC - chain fiber properties
%   sarcB - bag fiber properties
%   gDynOnPct - gamma dynamic burst ON point (% of gait cycle, 0-100)
%   gDynOffPct - gamma dynamic burst OFF point (% of gait cycle, 0-100)
%   sarcC_control_points - [5x1] control point values (pCa) for B-spline
%                          [cp1, cp2, cp3, cp4, cp5] at [0%, 20%, 40%, 60%, 80%] of cycle
%                          becomes [cp1, cp2, cp3, cp4, cp5, cp1] for periodicity
%   sarcC_phaseShift_s - phase shift for entire gamma static pattern (seconds)
%   sarcC_pCaToActGridded - gridded interpolant for pCa to activation conversion
%   sarcC_ActToPcaGridded - gridded interpolant for activation to pCa conversion
%
% Outputs:
%   sarcC - chain fiber with updated pCa and act
%   sarcB - bag fiber with updated pCa

time_step = t(2) - t(1);
n_steps = length(t);

%% Chain activation using B-spline interpolation

% Preallocate sarcC arrays
sarcC.pCa = zeros(n_steps, 1);
sarcC.act = zeros(n_steps, 1);

% Set initial values
sarcC.pCa(:) = mean(sarcC_control_points);  % Use mean of control points as baseline
sarcC.pCa(1:10) = 9;

% Calculate cycle period from act_freq
cycle_period = 1 / act_freq;  % seconds per cycle

% Define control point times (evenly spaced across cycle)
% Using 6 points: [0%, 20%, 40%, 60%, 80%, 100%] with first = last for periodicity
n_control_points = 6;
control_times_normalized = linspace(0, 1, n_control_points);  % [0, 0.2, 0.4, 0.6, 0.8, 1.0]
control_times = control_times_normalized * cycle_period;       % in seconds

% Create periodic control point values: [cp1, cp2, cp3, cp4, cp5, cp1]
% This ensures smooth cycling by making the end equal to the beginning
control_values = [sarcC_control_points(1);
                  sarcC_control_points(2);
                  sarcC_control_points(3);
                  sarcC_control_points(4);
                  sarcC_control_points(5);
                  sarcC_control_points(1)];  % Periodic: last = first

% For active portion (after sineStart)
if sineStart < n_steps
    active_indices = sineStart + 1:n_steps;

    % Calculate time relative to start, with phase shift
    t_relative = (t(active_indices) - t(sineStart)) + sarcC_phaseShift_s;

    % Map time to position within cycle [0, cycle_period]
    % Use modulo to handle multiple cycles
    t_in_cycle = mod(t_relative, cycle_period);

    % Interpolate control points to get pCa values at each time point
    % Use 'pchip' (piecewise cubic Hermite) for smooth, shape-preserving interpolation
    sarcC.pCa(active_indices) = interp1(control_times, control_values, t_in_cycle, 'pchip');

    % Convert pCa to activation
    sarcC.act(active_indices) = sarcC_pCaToActGridded(sarcC.pCa(active_indices));
end

% Set baseline activation for pre-perturbation period
baseline_act = sarcC_pCaToActGridded(mean(sarcC_control_points));
sarcC.act(11:sineStart) = baseline_act;

% Vectorized clamping
sarcC.act = max(0, min(1, sarcC.act));
sarcC.act(1:10) = 0;

% Update pCa based on final activation
sarcC.pCa = sarcC_ActToPcaGridded(sarcC.act);

%% Bag activation (gamma dynamic - percentage of gait cycle)

% Compute on/off times as percentage of each gait cycle
sineStart_time = sineStart * time_step;
cycle_starts = sineStart_time:cycle_period:t(end);

% Preallocate and set baseline sarcB.pCa
sarcB.pCa = repmat(sarcB.initial_pCa, n_steps, 1);

% Create logical mask for all activation periods
activation_mask = false(n_steps, 1);

% Wrap percentages to [0, 100) to handle values from old format conversion
onPct = mod(gDynOnPct, 100);
offPct = mod(gDynOffPct, 100);

if onPct <= offPct
    % Normal case: burst is within a single cycle (e.g., ON=40%, OFF=80%)
    for i = 1:length(cycle_starts)
        start_idx = max(1, round((cycle_starts(i) + (onPct / 100) * cycle_period) / time_step));
        end_idx = min(n_steps, round((cycle_starts(i) + (offPct / 100) * cycle_period) / time_step));
        if start_idx <= end_idx
            activation_mask(start_idx:end_idx) = true;
        end
    end
else
    % Wrap-around case: burst crosses cycle boundary (e.g., ON=80%, OFF=20%)
    % This occurs when the burst starts late in the cycle and extends into the next.
    % Equivalent to the old format where gDynOffPct > 100%.
    for i = 1:length(cycle_starts)
        % Segment A: ON% to end of this cycle
        start_idx = max(1, round((cycle_starts(i) + (onPct / 100) * cycle_period) / time_step));
        end_idx = min(n_steps, round((cycle_starts(i) + cycle_period) / time_step));
        if start_idx <= end_idx
            activation_mask(start_idx:end_idx) = true;
        end

        % Segment B: start of next cycle to OFF%
        start_idx_b = max(1, round((cycle_starts(i) + cycle_period) / time_step));
        end_idx_b = min(n_steps, round((cycle_starts(i) + cycle_period + (offPct / 100) * cycle_period) / time_step));
        if start_idx_b <= end_idx_b
            activation_mask(start_idx_b:end_idx_b) = true;
        end
    end
end

% Apply activation in one vectorized operation
sarcB.pCa = repmat(sarcB.initial_pCa, n_steps, 1);
sarcB.pCa(activation_mask) = sarcB.activating_pCa;

% Vectorized clamping
sarcB.pCa = max(4.5, min(9, sarcB.pCa));
sarcB.pCa(1:10) = 9;

end
