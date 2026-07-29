function [r_t, hsL, mL, r, rs, rd, hsB, dataB, hsC, dataC] = runSpindleSimForOpt_Bspline_5cp(t, sineStart, MTUfreq, act_freq, sarcC, sarcB, gDynOnPct, gDynOffPct, sarcC_control_points, sarcC_phaseShift_s, mtData, sarcC_pCaToActGridded, sarcC_ActToPcaGridded)
% Wrapper for running spindle simulation with B-spline gamma static (5 control points)
%
% This is a modified version of runSpindleSimForOpt that uses 5 B-spline
% control points instead of fewer, allowing more complex patterns.
%
% Inputs:
%   sarcC_control_points - [5x1] B-spline control point values (pCa)
%                          at [0%, 20%, 40%, 60%, 80%] of gait cycle
%   sarcC_phaseShift_s - phase shift for gamma static pattern (seconds)
%   gDynOnPct - gamma dynamic burst ON point (% of gait cycle, 0-100)
%   gDynOffPct - gamma dynamic burst OFF point (% of gait cycle, 0-100)
%   (other inputs same as original runSpindleSimForOpt)

% Generate intrafusal activation profiles using 5-control-point B-spline version
[sarcC, sarcB] = getIntrafusal_pCa_Bspline_5cp(t, sineStart, MTUfreq, act_freq, sarcC, sarcB, gDynOnPct, gDynOffPct, sarcC_control_points, sarcC_phaseShift_s, sarcC_pCaToActGridded, sarcC_ActToPcaGridded);

% Run intrafusal fiber simulation
delta_cdlI = [0 diff(mtData.hs_length)];
[hsB, dataB, hsC, dataC] = sarcSimDriverIntrafusal20250627(t, delta_cdlI(1, :), sarcB, sarcC);

% Generate spindle output
[r_t, hsL, mL, r, rs, rd] = sarc2spindle_20240310(dataB, dataC, 0.6, 1.1, 0.1, 0, 0);
 
end
