function c = rPotentialCost(model, data, baseline)
% rPotentialCost  The manuscript's receptor-potential cost.
%
%   c = rPotentialCost(model, data, baseline) scores a model RECEPTOR POTENTIAL
%   against a target firing rate the way the manuscript's Figure 1 fits do
%   (gammaDriveOptimization/functions/objFuncWithFixedTiming_Bspline_5cp_rPotential.m):
%
%       rSig = max(model - baseline, 0);     % above the no-drive level, floored
%       c    = meanNormRMSE(rSig, data);     % shape only
%
%   baseline is the receptor potential with no drive: the manuscript takes
%   mean(r(1:10)), because the first 10 samples of every simulation are forced
%   silent (pCa 9 on both fibers) by the drive construction.
%
%   WHY SUBTRACT IT. A mean-normalized shape comparison only works if both
%   signals share a zero. A firing rate has a true zero (silent). The receptor
%   potential does not - with no drive at all it sits at a passive level (in the
%   manuscript's fits, ~36% of its mean). Left in, that pedestal compresses the
%   model's normalized swing toward the target's and lowers the cost for the
%   wrong reason. Below baseline the afferent would be silent, hence the floor.
%
%   The manuscript also divides the cost by 1e2. That is a constant, so the
%   minimum is unchanged; cost VALUES here are 100x the ones its scripts print.
%   A model that is all at or below baseline has zero mean and scores 1e6, as
%   in the manuscript.

rSig = model(:) - baseline;
rSig(rSig < 0) = 0;
c = meanNormRMSE(rSig, data(:));
end
