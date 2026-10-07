function [sarcB, sarcC] = syncIntrafusalStartLength(sarcB, sarcC, mtData)
% Start the intrafusal fibres at the same half-sarcomere length as the
% extrafusal fibre they sit in parallel with.
%
% WHY THIS EXISTS
% getDefaultSarcB / getDefaultSarcC set
%     sarcB.hs_length = sarcB.cmd_length = getDefaultSarcE().hs_length
% i.e. they inherit the extrafusal length at the moment the struct is built,
% which is the DEFAULT extrafusal length (1250 nm). Scripts that drive the
% muscle at a different operating length do so by overriding
% extrafusal_config.hs_length (1280 nm in the ideal-sinusoid protocols), and
% that override is applied to a local sarcE inside getExtrafusalConfigurable --
% it never reaches sarcB/sarcC. The intrafusal driver
% (sarcSimDriverIntrafusal20250627) then initialises the fibres at their own
% hs_length and afterwards receives only length INCREMENTS
% (delta_cdl = diff(mtData.hs_length)), so the offset persists for the whole
% simulation: the spindle runs 30 nm shorter than the fascicle it is embedded
% in.
%
% That matters because passive force is k_passive * (hs_length - hsl_slack),
% and the intrafusal slack lengths are close to the operating length:
%   bag   k_passive 90,  hsl_slack 1050 -> 30 nm is ~15% of its passive force
%   chain k_passive 250, hsl_slack 1200 -> 30 nm is ~60% of its passive force
%
% WHAT IT DOES
% Sets both fibres' initial hs_length and cmd_length to the extrafusal
% fascicle length at t = 0, so the intrafusal fibres start matched and then
% track the fascicle exactly (they already follow its increments). This is a
% no-op when the two already agree -- e.g. the empirical-MTU protocols, which
% run the extrafusal fibre at the default 1250 nm.
%
% Only the STARTING length is set here; everything downstream (slack handling,
% cross-bridge evolution) is unchanged.
%
% SCOPE
% This is called from the nine runSpindleSim* wrappers, which covers the
% forward simulations, the literature comparisons, the optimizations and the
% gamma-static sweep (Figures 1 and 2).
%
% The closed-loop feedback simulations (Figures 3, 4, 5, plus the feedback-gain
% estimation scripts) do NOT go through those wrappers: referenceAlphaSim /
% feedbackDrivenAlphaSim* / differenceFeedbackAlphaSim* / pdFeedbackAlphaSim
% build their own halfSarcWithCoop objects and seed them from sarcB.hs_length
% (sarcB = refData.sarcB). The same correction is therefore applied at the two
% places where those structs are created:
%     functions/initializeFeedbackSimulation.m
%     functions/referenceAlphaSim.m
% which between them cover every feedback consumer.
%
% Created August 2026 by Surabhi Simha

L0_extrafusal = mtData.hs_length(1);   % fascicle length at t = 0

sarcB.hs_length  = L0_extrafusal;
sarcB.cmd_length = L0_extrafusal;
sarcC.hs_length  = L0_extrafusal;
sarcC.cmd_length = L0_extrafusal;

end
