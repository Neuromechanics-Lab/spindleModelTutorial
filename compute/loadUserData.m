function d = loadUserData(filePath)
% loadUserData  Load and validate a user's own inputs from a .mat file.
%
%   d = loadUserData(filePath) reads a .mat file describing your own experiment
%   and returns a normalized struct the tutorial can run. It supports two uses:
%
%     FORWARD  (length + activations  ->  firing):
%         you provide the muscle length and the fiber activations, and the model
%         predicts fiber forces, the Ia receptor potential, and firing.
%
%     OPTIMIZE (length + target firing  ->  gamma drive):
%         you provide the muscle length and a recorded Ia firing rate, and the
%         model infers the fusimotor (gamma) drive that best reproduces it.
%
%   EXPECTED FILE FORMAT
%   --------------------
%   Save a .mat with these variables (or a single struct named `data` with these
%   fields). All time-series must be the same length as `t`.
%
%     t              [1xN] time in seconds. Use a (near-)uniform step; dt ~= 1 ms
%                    is recommended (the model runs at ~1 kHz).
%     mtuLength      [1xN] muscle-tendon unit length in nm.        (see note)
%       -- or --
%     fascicleLength [1xN] muscle fascicle length in nm.           (see note)
%
%     alphaAct       [1xN] extrafusal (alpha) activation, 0..1 or 0..100 %.  [optional]
%     chainAct       [1xN] gamma-static (chain) activation, 0..1 or 0..100 %. [forward]
%     bagAct         [1xN] gamma-dynamic (bag) activation, 0..1 or 0..100 %.  [forward]
%     targetFiring   [1xN] Ia firing rate to fit (spikes/s).                  [optimize]
%     tendonStiffness  scalar tendon stiffness (default 5000).               [optional]
%
%   NOTE on length: provide EITHER mtuLength (the model runs the extrafusal
%   muscle-tendon unit with your alpha drive + tendon to get the fascicle length)
%   OR fascicleLength directly (the intrafusal fibers follow it as-is).
%
%   Activations may be given as fractions (0..1) or percent (0..100); values with
%   a maximum above ~1.5 are treated as percent and divided by 100.
%
%   The returned struct reports d.availForward and d.availOptimize so the app can
%   enable the right actions.

if ~isfile(filePath)
    error('loadUserData:noFile', 'File not found:\n    %s', filePath);
end
raw = load(filePath);

% Accept either a wrapper struct `data` or loose top-level variables.
if isfield(raw, 'data') && isstruct(raw.data)
    S = raw.data;
else
    S = raw;
end

% -- time ---------------------------------------------------------------
if ~isfield(S, 't') || ~isnumeric(S.t) || numel(S.t) < 10
    error('loadUserData:t', 'The file must contain a numeric time vector `t` (>= 10 samples).');
end
t = double(S.t(:)');
n = numel(t);
dts = diff(t);
if any(dts <= 0)
    error('loadUserData:t', '`t` must be strictly increasing.');
end
dt = median(dts);
if max(abs(dts - dt)) > 0.25 * dt
    warning('loadUserData:nonuniform', ...
        'Time steps are non-uniform; the model assumes ~uniform dt (using median dt = %.4g s).', dt);
end
% The model was developed and tuned at dt = 1 ms, and its behaviour is NOT
% dt-invariant: the integrate-and-fire stage quantises spike intervals to dt (so
% firing rates shift with dt), and the MTU force balance is solved once per step.
% Warn rather than refuse - other steps still run, but results are less
% comparable to the published ones.
if dt > 0.002 || dt < 0.0002
    warning('loadUserData:timestep', ...
        ['dt = %.4g s. The model is tuned for dt = 1 ms; well outside ~0.2-2 ms the\n', ...
         'firing output in particular will differ from the published behaviour.\n', ...
         'Consider resampling your data to 1 kHz.'], dt);
end
d.t = t; d.dt = dt; d.n = n;

% -- length -------------------------------------------------------------
hasM = isfield(S, 'mtuLength') && ~isempty(S.mtuLength);
hasF = isfield(S, 'fascicleLength') && ~isempty(S.fascicleLength);
if ~hasM && ~hasF
    error('loadUserData:length', ...
        'The file must contain `mtuLength` or `fascicleLength` (nm), same length as t.');
end
if hasF
    d.fascicleLength = checkLen(S.fascicleLength, n, 'fascicleLength');
    d.hasFascicle = true;
    d.mtuLength = [];
else
    d.mtuLength = checkLen(S.mtuLength, n, 'mtuLength');
    d.hasFascicle = false;
    d.fascicleLength = [];
end

% -- activations (normalize to 0..1) -----------------------------------
d.alphaAct = getAct(S, 'alphaAct', n);
d.chainAct = getAct(S, 'chainAct', n);
d.bagAct   = getAct(S, 'bagAct', n);

% -- target firing ------------------------------------------------------
if isfield(S, 'targetFiring') && ~isempty(S.targetFiring)
    d.targetFiring = checkLen(S.targetFiring, n, 'targetFiring');
else
    d.targetFiring = [];
end

% -- tendon stiffness ---------------------------------------------------
if isfield(S, 'tendonStiffness') && isscalar(S.tendonStiffness)
    d.tendonStiffness = double(S.tendonStiffness);
else
    d.tendonStiffness = 5000;
end

% -- what can we do with this file? ------------------------------------
d.availForward  = ~isempty(d.chainAct) || ~isempty(d.bagAct);
d.availOptimize = ~isempty(d.targetFiring);
if ~d.availForward && ~d.availOptimize
    error('loadUserData:incomplete', ...
        ['File has length but no activations and no targetFiring.\n', ...
         'Add chainAct/bagAct for a FORWARD run, or targetFiring to OPTIMIZE gamma.']);
end
d.file = filePath;
end


% ======================================================================
function v = checkLen(x, n, name)
if ~isnumeric(x) || numel(x) ~= n
    error('loadUserData:size', '`%s` must be numeric and the same length as t (%d).', name, n);
end
v = double(x(:)');
if any(~isfinite(v))
    error('loadUserData:finite', '`%s` contains non-finite values.', name);
end
end

function a = getAct(S, name, n)
% Return a 0..1 activation row vector, or [] if absent. Percent auto-detected.
if ~isfield(S, name) || isempty(S.(name))
    a = [];
    return
end
a = checkLen(S.(name), n, name);
if max(a) > 1.5      % looks like percent
    a = a / 100;
end
a = min(max(a, 0), 1);
end
