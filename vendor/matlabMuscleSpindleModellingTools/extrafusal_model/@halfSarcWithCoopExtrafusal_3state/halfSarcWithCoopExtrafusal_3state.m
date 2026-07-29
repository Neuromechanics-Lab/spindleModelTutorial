classdef halfSarcWithCoopExtrafusal_3state < handle
    
    properties
        % These properties can be accessed from the driver script
        
        % INITIAL STATE PARAMETERS %
        cmd_length = [];
        hs_length = [];   % the initial length of the half-sarcomere in nm
        hs_force;           % the stress (in N m^(-2)) in the half-sarcomere
        f_overlap;
        f_bound;
        cb_force;
        passive_force;
        Ca;
        pCa_perStep;
        tendon_stiffness;
        passive_force_mode;
        isTendon;
        cb_force_constant;
        x_bins_plus_stroke;
        passive_force_temp;
        bin_pops_interpolant;
        f_times_bin_width;

        % DISTRIBUTION BIN PARAMETERS %
        bin_min = -20;      % min x value for myosin distributions in nm
        bin_max = 20;       % max x value for myosin distributions in nm
        bin_width = 0.5;    % width of bins for myosin distributions in nm
        x_bins;             % array of x_bin values
        no_of_x_bins;       % no of x_bins
        
        % INDIVIDUAL CROSSBRIDGE PARAMETERS %
        k_cb = 0.001;       % Cross-bridge stiffness in N m^-1
        power_stroke = 2.5;   % Cross-bridge power-stroke in nm
        
        % PARAMETERS RELATED TO FORWARD AND REVERSE RATES %
        f_parameters = 20;
        g_parameters = 20;
                            

        thick_filament_length = 815;
                            % length of thick filaments in nm=
        thin_filament_length = 1120;
                            % length of thin filaments in nm
        bare_zone_length = 80;
                            % length of thick filament bare zone in nm
        k_falloff = 0.002;  % defines how f_overlap falls hs_length shortens
                            % below optimal
                            
        f;                  % forward rates
        g;                  % reverse rates
        srx_f;
        srx_g;
        
        bin_pops;           % number of heads bound in each bin
        no_detached;        % number of heads not attached to a binding site
        no_attached;
        no_actin_off;
        no_on_unbound;
        no_bound;
        y
        
        max_rate = 5000;    % clip f or g values above this value
        
        compliance_factor = 0.50;
                            % proportion of delta_hsl that the
                            % cb distribution is moved
                            
        cb_number_density = 6.9e16;
                            % number of cbs in a half-sarcomere with a
                            % cross-sectional area of 1 m^2
                            
        hsl_slack = 850;   % slack length of half-sarcomere in nm
        k_passive = 0; %5 for non FL and FV trials
                            % passive stiffness of half-sarcomere in
                            % N m^-2 nm^-1
        passive_L = 0; %5 for non FL and FV trials
                            % passive stiffness of half-sarcomere in
                            % N m^-2 nm^-1
        passive_sigma = 1; % for exponential parallel passive force

    end
    
    methods
        
        % BUILD halfSarcBag OBJECT %
        function obj = halfSarcWithCoopExtrafusal_3state(varargin)
            
            % Set up x_bins
            obj.x_bins = obj.bin_min:obj.bin_width:obj.bin_max;
            obj.no_of_x_bins = numel(obj.x_bins);

            
            % Set up rates
            obj.srx_f = 6 * ...
                (8 + 5e-4 * max([0 obj.cb_force]));
            obj.srx_f = min([obj.srx_f obj.max_rate]);

            obj.srx_g = min([obj.max_rate 100]);

            obj.f = zeros(size(obj.x_bins)); %Preallocate
            obj.f = 1200 - 65*((obj.x_bins-2).^2);
            obj.f(obj.f<0) = 0;
            obj.f(obj.f>obj.max_rate)=obj.max_rate;


            obj.g = zeros(size(obj.x_bins)); %Preallocate
            obj.g(obj.x_bins<0) = 1000*(obj.x_bins(obj.x_bins<0)-0).^2;
            obj.g(obj.x_bins>=0) = (5*(obj.x_bins(obj.x_bins>=0)-0).^2)+10;
            obj.g(obj.g>obj.max_rate)=obj.max_rate;
            
            % Limit max values
            obj.f(obj.f>obj.max_rate) = obj.max_rate;
            obj.g(obj.g>obj.max_rate) = obj.max_rate;
            
            % Initialize bins
            obj.bin_pops = zeros(obj.no_of_x_bins,1);
            obj.y = [1 ; 0 ; obj.bin_pops; 1; 0];
            
            % Precompute constants used in calcForces
            obj.cb_force_constant = obj.cb_number_density * obj.k_cb * 1e-9;
            obj.x_bins_plus_stroke = obj.x_bins + obj.power_stroke;
            
            % Precompute constants used in evolve_cbDist
            obj.f_times_bin_width = obj.f .* obj.bin_width;
            
        end
        
        % Other methods
        function update_filamentOverlap(obj)
            
            x_no_overlap = obj.hs_length - obj.thick_filament_length; %Length of thin filament w/0 overlapping thick filament
            x_overlap = obj.thin_filament_length - x_no_overlap; %
            max_x_overlap = obj.thick_filament_length -  ...
                obj.bare_zone_length; %Region of thick filament containing myosin heads
            
            if (x_overlap<0) %This is impossible in a sarcomere
                obj.f_overlap=0;
            end
            
            if ((x_overlap>0)&&(x_overlap<=max_x_overlap)) %Operating range of half sarcomere
                obj.f_overlap = x_overlap/max_x_overlap;
            end
            
            if (x_overlap>max_x_overlap) %This is impossible in a sarcomere
                obj.f_overlap=1;
            end
            protrusion = obj.thin_filament_length - ...
                (obj.hs_length + obj.bare_zone_length);
            
            if (protrusion > 0)
                x_overlap = (max_x_overlap - protrusion);
                obj.f_overlap = x_overlap / max_x_overlap;
            end
                       
        end
        
        
        function update_fracBound(obj)
            obj.f_bound = sum(obj.bin_pops);
        end
        
        
        function evolve_cbDist(obj,time_step)
            
            % Construct a vector y where
            % y(1) is the number of cbs in the detached state
            % y(2 ... no_of_x_bins+1) is the number of cbs in bins 1 to no_of_x_bins
            
            y = obj.y;
            
            % Evolve the system
%            options = odeset('RelTol', 1e-4, 'AbsTol', 1e-6, 'MaxStep', 0.001);
           [~, y_new] = ode15s(@derivs, time_step*[0 1], y);
            
            % Update the bound cross-bridges
            obj.bin_pops = y_new(end,3:end-2)';
            obj.no_detached = y_new(end,1);
            obj.y=y_new(end,:);
            
            function dy = derivs(~,y)
            % Update the bound cross-bridges
            f_myosin_srx = y(1);
            f_myosin_detached = y(2); 
            n_myosin_attached = y(3:end-2);
            f_actin_off = y(end-1);
            f_actin_on_unbound = y(end);
            f_actin_bound = sum(n_myosin_attached);
            
            
                % Calculating fluxes as from MyoSim 2 state (copied pretty
                % much)
                J1 = obj.srx_f * f_myosin_srx;
                J2 = obj.srx_g * f_myosin_detached;
                J3 = obj.f_times_bin_width * f_myosin_detached * (f_actin_on_unbound - f_actin_bound);
                J4 = obj.g .* (n_myosin_attached');
                x_no_overlap = obj.hs_length - obj.thick_filament_length;
                if ((obj.thin_filament_length - x_no_overlap)>0)
                    J_on = 80000000 * (10^(-obj.pCa_perStep)) * (obj.f_overlap - f_actin_on_unbound) * ...
                        (1 + 5 * (f_actin_on_unbound/obj.f_overlap));
                    J_off = 200 * (f_actin_on_unbound - f_actin_bound) * ...
                        (1 + 5 * ((obj.f_overlap - f_actin_on_unbound)/obj.f_overlap));
                else
                    J_on = 0;
                    J_off = 200 * (f_actin_on_unbound - f_actin_bound);
                end

                dy=zeros(length(y),1);
                % Calculate the derivs
                dy(1) = -J1 + J2;
                dy(2) = (J1 + sum(J4)) - (J2 + sum(J3));
                for i=1:obj.no_of_x_bins
                    dy(2+i) = J3(i) - J4(i);
                end
                dy(end-1) = -J_on + J_off;
                dy(end) = J_on - J_off;
                
            end
        end
        
        
        function shift_cbDist(obj,delta_x)
            % Adjust for filament compliance
            delta_x = delta_x * obj.compliance_factor;
            
            % Cache the bound crossbridges indices
            cb_indices = 3:length(obj.y)-2;
            cbs_bound_before = sum(obj.y(cb_indices));
            
            % Shift populations by interpolation
            interp_positions = obj.x_bins - delta_x;
            obj.y(cb_indices) = interp1(obj.x_bins, obj.y(cb_indices), interp_positions, 'linear', 0)';
            
            % Try to manage cbs ripped off filaments
            cbs_lost = cbs_bound_before - sum(obj.y(cb_indices));
            if cbs_lost > 0
                obj.y(1) = obj.y(1) + cbs_lost;
            end
        end
        

        function calcForces(obj,delta_hsl)
            obj.cb_force = obj.cb_force_constant * sum(obj.x_bins_plus_stroke .* obj.y(3:end-2));
            
            switch obj.passive_force_mode
                case 'linear'
                    obj.passive_force = obj.k_passive * (obj.hs_length - obj.hsl_slack);
                case 'exponential'
                    obj.passive_force = obj.passive_sigma * ...
                        (exp((obj.hs_length - obj.hsl_slack)/ ...
                        obj.passive_L)-1);
            end
            obj.hs_force = obj.cb_force + obj.passive_force;
        end

        
        
        function forwardStep(obj,time_step,delta_hsl,delta_cdl,evolve,shift)
            %This function uses the methods for updating the half-sarcomere
            %every time step
                        
            obj.cmd_length = obj.cmd_length + delta_cdl;
            obj.hs_length = obj.hs_length + delta_hsl;
            
            % Change cb distribution based on cycling kinetics
            if evolve == 1
                obj.update_filamentOverlap();
                obj.update_fracBound();
                obj.evolve_cbDist(time_step);
            end
            
            % Shift cb distribution based on imposed movements
            % Also, perform calculations that are dependent on hs_length
            if shift == 1
                obj.shift_cbDist(delta_hsl);
            end
                            
            % Calculate forces
            obj.calcForces(delta_hsl);
            
        end
        
    end
end      
            
            
            
            
        
        