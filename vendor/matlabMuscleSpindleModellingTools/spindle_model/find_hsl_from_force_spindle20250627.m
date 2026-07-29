function x = find_hsl_from_force_spindle20250627(obj, F_isotonic)

obj.cb_force_constant = obj.cb_number_density * obj.k_cb * 1e-9;
obj.x_bins_plus_stroke = obj.x_bins + obj.power_stroke;
obj.bin_pops_interpolant = griddedInterpolant(obj.x_bins, obj.bin_pops, 'linear', 'none');

x_adj = fzero(@(x) tempForce20250627(x,obj,F_isotonic), 0, optimset('display','off'));

x = obj.hs_length + x_adj;

%     x_adj = 0;  % Starting point
%     tol = 1e-10;
%     h = 1e-6;  % Step size for numerical derivative
%     max_iter = 10;  % Should converge quickly for force balance
%     
%     for i = 1:max_iter
%         f = tempForce20250627(x_adj, obj, F_isotonic);
%         if abs(f) < tol, break; end
%         
%         % Numerical derivative (central difference)
%         df = (tempForce20250627(x_adj + h, obj, F_isotonic) - tempForce20250627(x_adj - h, obj, F_isotonic)) / (2*h);
%         
%         % Prevent division by very small numbers
%         if abs(df) < 1e-15
%             break;  % Derivative too small, stop
%         end
%         
%         % Newton step with step limiting for robustness
%         step = f / df;
%         if abs(step) > 0.01  % Limit step size
%             step = 0.01 * sign(step);
%         end
%         
%         x_adj = x_adj - step;
%     end
%     
%     x = obj.hs_length + x_adj;
end


function zeroF = tempForce20250627(x, obj, F_isotonic)
    % Adjust for filament compliance
    delta_x = x * obj.compliance_factor;
    interp_positions = obj.x_bins - delta_x;
    
    % Use griddedInterpolant instead of interp1
    temp_bin_pops = obj.bin_pops_interpolant(interp_positions);
    % Handle NaNs (equivalent to your 0 default)
    temp_bin_pops(isnan(temp_bin_pops)) = 0;
    
    % Use precomputed constants
    cbF = obj.cb_force_constant * sum(obj.x_bins_plus_stroke .* temp_bin_pops);
    
    % Passive force calculation (at adjusted length)
    pF = obj.k_passive * ((obj.hs_length + x) - obj.hsl_slack);
    hsF = cbF + pF;
    
    zeroF = hsF - F_isotonic;
end