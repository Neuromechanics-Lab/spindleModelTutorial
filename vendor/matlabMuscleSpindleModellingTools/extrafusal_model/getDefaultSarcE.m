function sarcE = getDefaultSarcE()
sarcE.pCa=[];
sarcE.act=[];
sarcE.initial_act       = 35; % 25 for Taylor 2006 NCM; 15 for "passive" NCM; 45 Taylor manuscript; 5 passive manuscript
sarcE.activating_act    = 65; % 50 for Taylor 2006 NCM; 50 for "active" NCM; 75 Taylor manuscript
sarcE.power_stroke      = 2.5;
sarcE.hs_length         = 1250;
sarcE.compliance_factor = 0.5;
sarcE.act_phaseShift_s  = -0.33;
sarcE.act_amplitude     = (sarcE.activating_act-sarcE.initial_act)/100;
sarcE.act_freq          = 1;

%% extrafusal fiber passive parameteres; we only change this to get force resposne to sinusoidal length change
sarcE.isTendon           = 1;
sarcE.tendon_stiffness   = 5e3;
sarcE.passive_force_mode = 'exponential'; % linear exponential
sarcE.hsl_slack          = 850;
sarcE.k_passive          = 10; % only for linear parallel passive force
sarcE.passive_sigma      = 1; % only for exponential parallel passive force
sarcE.passive_L          = 45; % only for exponential parallel passive force
end
