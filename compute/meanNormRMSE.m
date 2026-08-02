function c = meanNormRMSE(model, data)
% meanNormRMSE  Shape-only cost: divide each trace by its own mean, then RMSE.
%
%   c = meanNormRMSE(model, data) is the cost the manuscript minimizes
%   (gammaDriveOptimization/functions/objFuncWithFixedTiming_Bspline_5cp_normSmooth.m):
%
%       mN = model / mean(model);  dN = data / mean(data);
%       c  = sqrt(mean((mN - dN).^2));
%
%   The manuscript scales this by 1/100 before returning it. That is a constant,
%   so the minimum is in the same place; it only means cost VALUES here are 100x
%   the ones its scripts print.
%
%   WHY normalize both. Comparing ABSOLUTE traces makes the cost punish any
%   difference in overall level, and that punishment lands on the gamma-dynamic
%   drive: once gamma-static already matches the recorded amplitude, adding bag
%   drive only pushes the model above the data, so the optimizer turns it off and
%   the burst timing stops being identifiable. That is exactly what happened in
%   the manuscript's first pass - the normalization had been commented out - and
%   restoring it is what made gamma-dynamic recoverable again.
%
%   Dividing each trace by its own mean compares SHAPE, so an arbitrary overall
%   gain drops out. That is also what lets a model RECEPTOR POTENTIAL be fitted
%   to a recorded FIRING RATE: below the spike generator's ceiling the two are
%   proportional (rate = r / threshold), and a proportional factor is exactly
%   what mean-normalization removes. See docs/06_your_data.md.
%
%   Non-finite samples in either trace are dropped pairwise. Returns 1e6 if
%   fewer than two usable samples remain or if a mean is zero/non-finite, so an
%   optimizer treats it as a bad point rather than erroring.

model = model(:); data = data(:);
if numel(model) ~= numel(data)
    error('meanNormRMSE:sizeMismatch', ...
        'model (%d) and data (%d) must be the same length.', numel(model), numel(data));
end

ok = isfinite(model) & isfinite(data);
if sum(ok) < 2, c = 1e6; return; end
m = model(ok); dta = data(ok);

mMean = mean(m); dMean = mean(dta);
if mMean == 0 || dMean == 0 || ~isfinite(mMean) || ~isfinite(dMean)
    c = 1e6; return;
end

c = sqrt(mean((m/mMean - dta/dMean).^2));
if ~isfinite(c), c = 1e6; end
end
