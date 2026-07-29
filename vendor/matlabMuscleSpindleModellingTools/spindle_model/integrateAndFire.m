function [t_firing,r_IFR] = integrateAndFire(r_t,r,removeOffsetFlag)

resetInd = 1;
r_firing = zeros(size(r)); % Preallocate
r_firing(1) = 0;
refracPeriod = 0;
if removeOffsetFlag
    offsetRemovedR = r - r(1);
else
    offsetRemovedR = r;
end

% Compute cumulative integral once
cumulative_integral = cumtrapz(offsetRemovedR);

for i = 2:length(offsetRemovedR)
    % Get integral from resetInd to i using precomputed cumulative values
    r_firing_temp = cumulative_integral(i) - cumulative_integral(resetInd);
    
    if refracPeriod > 5 % 5 ms
        r_firing(i) = r_firing_temp;
        resetInd = i;
        refracPeriod = 0;
    else
        r_firing(i) = 0;
        refracPeriod = refracPeriod + 1;
    end
end

r_IFR = r_firing(r_firing > 0);
t_firing = r_t(r_firing > 0);

end