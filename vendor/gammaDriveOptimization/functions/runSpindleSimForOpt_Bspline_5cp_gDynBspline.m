function [r_t, hsL, mL, r, rs, rd, hsB, dataB, hsC, dataC] = runSpindleSimForOpt_Bspline_5cp_gDynBspline(t, sineStart, MTUfreq, act_freq, ...
    sarcC, sarcB, gDyn_control_points, gDyn_phaseShift_s, sarcC_control_points, sarcC_phaseShift_s, ...
    mtData, sarcC_pCaToActGridded, sarcC_ActToPcaGridded, sarcB_pCaToActGridded, sarcB_ActToPcaGridded)
% Wrapper for the spindle simulation with periodic B-splines for BOTH gamma
% drives (gamma static: 5 control points; gamma dynamic: numel(gDyn_control_points)
% control points). Mirrors runSpindleSimForOpt_Bspline_5cp.m; everything
% downstream of drive construction is identical.
%
% Created August 2026 by Surabhi Simha (rebuilt 2026-08-14).

[sarcC, sarcB] = getIntrafusal_pCa_Bspline_5cp_gDynBspline(t, sineStart, MTUfreq, act_freq, ...
    sarcC, sarcB, gDyn_control_points, gDyn_phaseShift_s, sarcC_control_points, sarcC_phaseShift_s, ...
    sarcC_pCaToActGridded, sarcC_ActToPcaGridded, sarcB_pCaToActGridded, sarcB_ActToPcaGridded);

% Start the intrafusal fibres at the extrafusal length (see function header)
[sarcB, sarcC] = syncIntrafusalStartLength(sarcB, sarcC, mtData);

delta_cdlI = [0 diff(mtData.hs_length)];
[hsB, dataB, hsC, dataC] = sarcSimDriverIntrafusal20250627(t, delta_cdlI(1, :), sarcB, sarcC);

[r_t, hsL, mL, r, rs, rd] = sarc2spindle_20240310(dataB, dataC, 0.6, 1.1, 0.1, 0, 0);

end
