function files = saveUserResults(fileBase, res, kind)
% saveUserResults  Write the results of a Your-data run to disk.
%
%   files = saveUserResults(fileBase, res, kind) saves a run's results next to
%   each other in two forms:
%
%     <fileBase>.mat  - everything, as a struct (for reloading into MATLAB)
%     <fileBase>.csv  - the time series only, one column per signal (for Excel,
%                       Python, R, plotting elsewhere)
%
%   kind is 'forward' (res is the output of runForwardFromData) or 'optimize'
%   (res is the output of runOptFromData). It defaults to 'forward' unless res
%   looks like an optimization result.
%
%   Returns the cell array of files written.
%
%   Example:
%       d   = loadUserData('myData.mat');
%       out = runForwardFromData(d);
%       saveUserResults('myResults', out, 'forward');

if nargin < 3 || isempty(kind)
    if isfield(res, 'xOpt'), kind = 'optimize'; else, kind = 'forward'; end
end
[pth, nm] = fileparts(fileBase);
if isempty(nm), error('saveUserResults:name', 'Give a file name to save as.'); end
base = fullfile(pth, nm);

switch lower(kind)
    case 'forward'
        % ---- tidy struct ----
        S = struct();
        S.kind        = 'forward';
        S.t           = res.t(:);
        S.fascicleLength = res.L(:);
        S.mtuLength   = res.mt.mtuCmd(:);
        S.actAlpha    = 100*res.actAlpha(:);       % %
        S.actChain    = 100*res.actC(:);
        S.actBag      = 100*res.actB(:);
        S.forceBag    = res.bag.hs_force(:);
        S.forceChain  = res.chain.hs_force(:);
        S.receptorPotential_t = res.r_t(:);
        S.r           = res.r(:);
        S.rs          = res.rs(:);
        S.rd          = res.rd(:);
        S.spikeTimes  = res.t_firing(:);
        S.IFR         = res.IFR(:);
        S.units = struct('t','s','length','nm (half-sarcomere)', ...
            'activation','%','force','N m^-2','r','a.u.', ...
            'spikeTimes','s','IFR','spikes/s');

        % ---- CSV of the signals that share the time base ----
        T = table(res.t(:), res.L(:), res.mt.mtuCmd(:), ...
            100*res.actAlpha(:), 100*res.actC(:), 100*res.actB(:), ...
            res.bag.hs_force(:), res.chain.hs_force(:), ...
            'VariableNames', {'time_s','fascicleLength_nm','mtuLength_nm', ...
            'alphaAct_pct','chainAct_pct','bagAct_pct', ...
            'bagForce_Npm2','chainForce_Npm2'});

    case 'optimize'
        S = struct();
        S.kind      = 'optimize';
        S.t         = res.t(:);
        S.targetFiring = res.target(:);
        S.fitInitial   = res.fit0(:);
        S.fitOptimised = res.fitOpt(:);
        S.paramNames   = res.names;
        S.paramLabels  = res.labels;
        S.paramInitial = res.x0(:)';
        S.paramOptimised = res.xOpt(:)';
        S.costInitial   = res.fval0;
        S.costOptimised = res.fvalOpt;
        S.history       = res.history;
        S.gammaOpt      = res.gammaOpt;    % recovered drive (pCa traces)

        % How the fit was configured. Without these the file is ambiguous:
        % fitOptimised is a RECEPTOR POTENTIAL in the default 'receptor' mode but
        % a FIRING RATE in 'firing' mode, and paramNames has 8 entries for the
        % B-spline gamma-static models against 4 for 'constant'.
        S.fitTarget   = res.fitTarget;
        S.fitUnits    = res.fitUnits;
        S.solver      = res.solver;
        S.gammaStatic = res.gammaStatic;
        S.cyclePeriod = res.cyclePeriod;   % [] unless gammaStatic is periodic

        if strcmp(res.fitTarget, 'receptor')
            fitUnitSuffix = 'r_au';        % receptor potential, arbitrary units
        else
            fitUnitSuffix = 'sps';
        end
        S.units = struct('t','s','target','spikes/s', ...
            'fit', res.fitUnits, 'gamma','pCa');

        T = table(res.t(:), res.target(:), res.fit0(:), res.fitOpt(:), ...
            res.gammaOpt.chainPca(:), res.gammaOpt.bagPca(:), ...
            'VariableNames', {'time_s','targetFiring_sps', ...
            ['fitInitial_' fitUnitSuffix], ['fitOptimised_' fitUnitSuffix], ...
            'chainGamma_pCa','bagGamma_pCa'});

    otherwise
        error('saveUserResults:kind', 'kind must be ''forward'' or ''optimize''.');
end

S.savedOn = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
S.model   = 'Simha et al. 2026 biophysical muscle spindle model (doi:10.64898/2026.07.03.736206)';

matFile = [base '.mat'];  save(matFile, '-struct', 'S');
csvFile = [base '.csv'];  writetable(T, csvFile);
files = {matFile, csvFile};
end
