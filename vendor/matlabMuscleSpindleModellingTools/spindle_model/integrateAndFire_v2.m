function [t_firing,r_IFR] = integrateAndFire_v2(r_t,r,removeOffsetFlag)

refracPeriod_threshold = (2/1000)/(r_t(2)-r_t(1)); % refractory period of 2ms
threshold = 0.005; % The "voltage-time" area needed to fire

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
cumulative_integral = cumtrapz(r_t,offsetRemovedR);

for i = 2:length(offsetRemovedR)
    % Get integral from resetInd to i using precomputed cumulative values
    r_firing_temp = cumulative_integral(i) - cumulative_integral(resetInd);
    
    if r_firing_temp > threshold && refracPeriod > refracPeriod_threshold
        % FIRE
        r_firing(i) = r_firing_temp;
        resetInd = i;
        refracPeriod = 0;
    else
        % NO FIRE
        r_firing(i) = 0;
        refracPeriod = refracPeriod + 1;
    end
end

ISI = [0 diff(r_t(r_firing>0))];
r_IFR = 1./ISI;%r_firing(r_firing > 0);
t_firing = r_t(r_firing > 0);

end