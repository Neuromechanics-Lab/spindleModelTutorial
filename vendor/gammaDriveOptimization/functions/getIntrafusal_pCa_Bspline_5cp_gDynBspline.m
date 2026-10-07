function [sarcC, sarcB] = getIntrafusal_pCa_Bspline_5cp_gDynBspline(t, sineStart, ~, act_freq, ...
    sarcC, sarcB, gDyn_control_points, gDyn_phaseShift_s, ...
    sarcC_control_points, sarcC_phaseShift_s, ...
    sarcC_pCaToActGridded, sarcC_ActToPcaGridded, ...
    sarcB_pCaToActGridded, sarcB_ActToPcaGridded)
% Intrafusal drive construction with PERIODIC B-SPLINES FOR BOTH FIBERS.
%
% Gamma static (chain): 5 periodic control points + phase shift -- this block
% is copied verbatim from getIntrafusal_pCa_Bspline_5cp.m.
% Gamma dynamic (bag): the SAME construction with nB = numel(gDyn_control_points)
% periodic control points + its own phase shift, replacing the rectangular
% ON/OFF pulse of the original. The control point vector is wrapped
% (last = first) and evaluated against a modulo-wrapped time, so the waveform
% repeats every gait cycle (C0-periodic, like gamma static).
%
% Inputs (differences from getIntrafusal_pCa_Bspline_5cp):
%   gDyn_control_points - [nB x 1] control point values (pCa) for the bag,
%                         at [0, 1/nB, ..., (nB-1)/nB] of the cycle
%   gDyn_phaseShift_s   - phase shift of the bag pattern (seconds). Only
%                         [0, cycle/nB) is non-redundant: a full-interval
%                         shift equals a cyclic permutation of the control
%                         points, which the optimizer can already do.
%   sarcB_pCaToActGridded / sarcB_ActToPcaGridded - bag activation curve
%                         interpolants (bag and chain have different curves)
%
% Outputs: sarcC, sarcB with pCa (and act) time series. Samples 1:10 are
% zero-activation (pCa 9) on both fibers by design -- the baseline window.
%
% Created August 2026 by Surabhi Simha (rebuilt 2026-08-14 to the August spec
% after an accidental working-tree discard; verified against the pulse
% formulation by the gamma-dynamic-off bit-identity check).

time_step = t(2) - t(1); %#ok<NASGU>  % kept for parity with the original
n_steps = length(t);
cycle_period = 1 / act_freq;

%% Chain activation using B-spline interpolation (verbatim from _Bspline_5cp)

sarcC.pCa = zeros(n_steps, 1);
sarcC.act = zeros(n_steps, 1);
sarcC.pCa(:) = mean(sarcC_control_points);
sarcC.pCa(1:10) = 9;

n_control_points = 6;
control_times_normalized = linspace(0, 1, n_control_points);
control_times = control_times_normalized * cycle_period;

control_values = [sarcC_control_points(1);
                  sarcC_control_points(2);
                  sarcC_control_points(3);
                  sarcC_control_points(4);
                  sarcC_control_points(5);
                  sarcC_control_points(1)];   % periodic: last = first

if sineStart < n_steps
    active_indices = sineStart + 1:n_steps;
    t_relative = (t(active_indices) - t(sineStart)) + sarcC_phaseShift_s;
    t_in_cycle = mod(t_relative, cycle_period);
    sarcC.pCa(active_indices) = interp1(control_times, control_values, t_in_cycle, 'pchip');
    sarcC.act(active_indices) = sarcC_pCaToActGridded(sarcC.pCa(active_indices));
end

baseline_act = sarcC_pCaToActGridded(mean(sarcC_control_points));
sarcC.act(11:sineStart) = baseline_act;
sarcC.act = max(0, min(1, sarcC.act));
sarcC.act(1:10) = 0;
sarcC.pCa = sarcC_ActToPcaGridded(sarcC.act);

%% Bag activation: same periodic-spline construction, nB control points

nB = numel(gDyn_control_points);
sarcB.pCa = zeros(n_steps, 1);
sarcB.act = zeros(n_steps, 1);
sarcB.pCa(:) = mean(gDyn_control_points);
sarcB.pCa(1:10) = 9;

gDyn_times = linspace(0, 1, nB + 1) * cycle_period;
gDyn_values = [gDyn_control_points(:); gDyn_control_points(1)];   % periodic: last = first

if sineStart < n_steps
    active_indices = sineStart + 1:n_steps;
    t_relative = (t(active_indices) - t(sineStart)) + gDyn_phaseShift_s;
    t_in_cycle = mod(t_relative, cycle_period);
    sarcB.pCa(active_indices) = interp1(gDyn_times, gDyn_values, t_in_cycle, 'pchip');
    sarcB.act(active_indices) = sarcB_pCaToActGridded(sarcB.pCa(active_indices));
end

gDyn_baseline_act = sarcB_pCaToActGridded(mean(gDyn_control_points));
sarcB.act(11:sineStart) = gDyn_baseline_act;
sarcB.act = max(0, min(1, sarcB.act));
sarcB.act(1:10) = 0;
sarcB.pCa = sarcB_ActToPcaGridded(sarcB.act);

end
