function [hsE, mtData] = musTenDriver20250627(t,delta_cdl,sarcE)

hsE = halfSarcWithCoopExtrafusal_3state();
hsE.power_stroke = sarcE.power_stroke;
hsE.hsl_slack = sarcE.hsl_slack;
hsE.k_passive = sarcE.k_passive;
hsE.compliance_factor = sarcE.compliance_factor;
% hsE.tendon_stiffness=sarcE.tendon_stiffness;
hsE.passive_force_mode = sarcE.passive_force_mode;
hsE.passive_L = sarcE.passive_L;
hsE.passive_sigma = sarcE.passive_sigma;

% Preallocate all mtData arrays at the start to save time
n_steps = numel(t);
mtData.t = zeros(1, n_steps);
mtData.f_bound = zeros(1, n_steps);
mtData.f_overlap = zeros(1, n_steps);
mtData.cb_force = zeros(1, n_steps);
mtData.passive_force = zeros(1, n_steps);
mtData.hs_force = zeros(1, n_steps);
mtData.hs_length = zeros(1, n_steps);
mtData.cmd_length = zeros(1, n_steps);
mtData.bin_pops = zeros(length(hsE.bin_pops), n_steps);  
mtData.no_detached = zeros(1, n_steps);


for i = 1:numel(t)
    hsE.pCa_perStep = sarcE.pCa(i);
    
    
    if sarcE.isTendon==1
        hsE.tendon_stiffness = sarcE.tendon_stiffness_vec(i);
        if i > 1
            time_step = t(i) - t(i-1);
        else
            hsE.cmd_length = sarcE.hs_length;
            hsE.hs_length = sarcE.hs_length;
            time_step = t(2) - t(1);
            
            x_new = mtu_balance_forces_for_spindle20250627(hsE);
            x_adj = x_new - hsE.hs_length;
            hsE.forwardStep(0,x_adj,0,0,1);
            
        end
        
        
        hsE.forwardStep(time_step,0,0,1,0)
        
        x_new = mtu_balance_forces_for_spindle20250627(hsE);
        x_adj = x_new - hsE.hs_length;
        hsE.forwardStep(0,x_adj,delta_cdl(i),0,1);
    else
        if i > 1
            time_step = t(i) - t(i-1);
        else
            hsE.cmd_length = sarcE.hs_length;
            hsE.hs_length = sarcE.hs_length;
            time_step = t(2) - t(1);
        end
        delta_hsl = delta_cdl(i);
        hsE.forwardStep(time_step,delta_hsl,delta_cdl(i),1,1);
    end
    
    % if mod(i,100)==0, disp(['done with t' num2str(i)]);end
    
    mtData.f_bound(i) = sum(hsE.bin_pops);
    mtData.f_overlap(i) = hsE.f_overlap;
    mtData.cb_force(i) = hsE.cb_force;
    
    
    mtData.passive_force(i) = hsE.passive_force;
    mtData.hs_force(i) = hsE.hs_force;
    mtData.hs_length(i) = hsE.hs_length;
    mtData.cmd_length(i) = hsE.cmd_length;
    mtData.bin_pops(:,i) = hsE.bin_pops;
    mtData.no_detached(i) = hsE.no_detached;
end

mtData.t = t;

end

