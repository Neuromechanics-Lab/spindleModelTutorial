function new_length = mtu_balance_forces_for_spindle20250627(obj)

obj.cb_force_constant = obj.cb_number_density * obj.k_cb * 1e-9;
obj.x_bins_plus_stroke = obj.x_bins + obj.power_stroke;
obj.passive_force_temp = obj.k_passive * (obj.hs_length - obj.hsl_slack);
obj.bin_pops_interpolant = griddedInterpolant(obj.x_bins, obj.bin_pops, 'linear', 'none');

    x_adj = fzero(@(x) tempForce20250627(x,obj), 0, optimset('display','off','TolFun',1e-10));
    new_length = obj.hs_length + x_adj;

%     x = 0;  % Starting point
%     tol = 1e-10;
%     h = 1e-6;  % Step size for numerical derivative
%     max_iter = 10;  % Should converge quickly for force balance
%     
%     for i = 1:max_iter
%         f = tempForce20250627(x, obj);
%         if abs(f) < tol, break; end
%         
%         % Add debugging
%         if mod(i,1)==0  % Print every iteration
%             fprintf('Iter %d: x=%.6f, f=%.6f\n', i, x, f);
%         end
%         
%         % Numerical derivative (central difference)
%         df = (tempForce20250627(x + h, obj) - tempForce20250627(x - h, obj)) / (2*h);
%         
%         % Prevent division by very small numbers
%         if abs(df) < 1e-15
%             break;  % Derivative too small, stop
%         end
%         
%         % Newton step with step limiting for robustness
%         step = f / df;
%         if abs(step) > 0.01  % Limit step size (adjust based on typical x_adj values)
%             step = 0.01 * sign(step);
%         end
%         
%         x = x - step;
%     end
    
%     % Check final convergence
%     final_f = tempForce20250627(x, obj);
%     if abs(final_f) > tol
%         warning('Force balance did not converge! Final error: %.2e', final_f);
%     end
    
%     new_length = obj.hs_length + x;
end

function zeroF = tempForce20250627(x, obj)
    % Adjust for filament compliance
    delta_x = x * obj.compliance_factor;
    interp_positions = obj.x_bins - delta_x;
    
    % Use griddedInterpolant instead of interp1
    temp_bin_pops = obj.bin_pops_interpolant(interp_positions);
    temp_bin_pops(isnan(temp_bin_pops)) = 0;  % Replace NaNs with 0    
    
    % Calculate crossbridge force (using precomputed constants)
    cbF = obj.cb_force_constant * sum(obj.x_bins_plus_stroke .* temp_bin_pops);
    
    % Total muscle force (using precomputed passive force)
    hsF = cbF + obj.passive_force_temp;
    
    % Calculate tendon force
    newTendonLength = max(0, obj.cmd_length - (obj.hs_length + delta_x));
    newTendonForce = obj.tendon_stiffness * newTendonLength;
    
    % Force difference
    zeroF = hsF - newTendonForce;
end