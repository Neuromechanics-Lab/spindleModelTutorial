function [t, hsL, mL, r,rs,rd] = sarc2spindle_20240310(dataB,dataC,kFc,kFb,kYb,occlusion,threshold)

t1 = dataC.t; %time

% find non-nan values in both bag and chain fibres
notNanChainIndices = find(~isnan(dataC.hs_force));
notNanBagIndices = find(~isnan(dataB.hs_force));
commonIndices = intersect(notNanChainIndices,notNanBagIndices);
Fs = dataC.hs_force(commonIndices);
Fd = dataB.hs_force(commonIndices);
t = t1(commonIndices);
hsL = dataB.hs_length(commonIndices); %this needs to be fixed to get both bag and chain lengths
if isfield(dataB,'muscle_length')
    mL = dataB.muscle_length(commonIndices);
    Ca = dataB.Ca(commonIndices);
else
    mL=0;
end
% tSteadyState = find(t>2,1); % need to change the value based on the trial. it's 2 here because i allow 2s for the force to reach steady state before the protocol begins for cusTri
% Fs = Fs-Fs(tSteadyState);
% Fd = Fd-Fd(tSteadyState);

% filter forces
N = 1/(dataC.t(2)-dataC.t(1));
cutoff = 300;
if cutoff<(N/2)
    [b,a]=butter(2,cutoff/N/2,'low');
    Fs_filt = filtfilt(b,a,Fs);
    Fd_filt = filtfilt(b,a,Fd);
else
    Fs_filt = Fs;
    Fd_filt = Fd;
end

% Force-dominant fiber (static fiber)
Fs_filt(Fs_filt<0) = 0;

% Yank-dominant fiber (dynamic fiber)
Fd_filt(Fd_filt<0) = 0; %threshold
Y = diff(Fd_filt)./diff(t); %yank
Y(Y<0) = 0; %threshold
Y = [Y(1) Y]; %make Y same length as F; this was edited by SNS on 20250320. All earlier versions repeat the last element at the end to match length
% Y(end+1) = Y(end); %make Y same length as F

% Y(Fd<8e4) = 0; %Yank threshold on force


rs = Fs_filt*kFc; %static component
rd = Fd_filt*kFb + Y*kYb; %dynamic component

rs(rs<0) = 0;

rs = 2*rs/(10^5);
rd = 2*rd/(10^5);

if occlusion % Hypothesis that branches of Ia ending compete for total firing rate
    rsComp = rs;
    rsComp(rd>=rs) = 0.3*rsComp(rd>=rs);  % 0.3 chosen to match Banks et al. 1997
    
    rdComp = rd;
    rdComp(rs>rd) = 0.3*rdComp(rs>rd);
    
    clear rs rd
    rs=rsComp;rd=rdComp;
    r = rsComp + rdComp;
%     rs = rsComp;
%     rd = rdComp;
else
    r = rs + rd; %linear sum
end

%Firing Threshold
r = r - threshold;
r(r<0.0) = 0; 

end