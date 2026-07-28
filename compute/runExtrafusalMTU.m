function mt = runExtrafusalMTU(t, p, LmtuOverride, alphaOverride)
% runExtrafusalMTU  Run the extrafusal muscle-tendon unit for the tutorial.
%
%   mt = runExtrafusalMTU(t, p) applies the length protocol to the extrafusal
%   MTU (an alpha-driven muscle in series with a tendon) and returns the
%   FASCICLE length that the intrafusal spindle fibers inherit.
%
%   This uses the real toolbox driver musTenDriver20250627, exactly as the
%   forward/optimization pipelines in gammaDriveOptimization do
%   (getExtrafusalConstMTU -> musTenDriver -> fascicle length).
%
%   Returned struct mt:
%     .fascicleLength  fascicle (intrafusal) length trace, nm  [= mtData.hs_length]
%     .mtuCmd          MTU commanded length trace, nm          [= mtData.cmd_length]
%     .mtuLength       total MTU length (fascicle + tendon), nm
%     .alphaAct        extrafusal (alpha) activation trace, 0-1
%     .force           MTU force trace
%     .mtData          full mtData struct from the driver (used by the opt tab)
%     .sarcE           the extrafusal fiber struct used
%     .ok              true if the MTU ran; false if it fell back
%     .message         explanation when .ok is false
%
%   Robustness: very extreme tendon stiffness or activation can make the
%   force-balance solver misbehave. On any failure (or non-finite output) the
%   function falls back to driving the fascicle directly with the length
%   command (as if there were no compliant tendon) and reports it in .message.

t  = t(:)';
n  = numel(t);

% MTU length command: an explicit trace (custom data) or the parametric protocol.
if nargin >= 3 && ~isempty(LmtuOverride)
    Lmtu = LmtuOverride(:)';
    delta_cdlE = [0, diff(Lmtu)];
else
    [Lmtu, delta_cdlE] = makeLengthCommand(t, p.protocol);
end

% Build the extrafusal fiber from toolbox defaults.
sarcE = getDefaultSarcE();
sarcE.tendon_stiffness = p.mtu.tendonStiffness;
sarcE.tendon_stiffness_vec = repmat(sarcE.tendon_stiffness, 1, n);

% Alpha (extrafusal) activation -> pCa (explicit trace, or built from p.mtu).
ac = loadActivationCurve();
if nargin >= 4 && ~isempty(alphaOverride)
    alphaAct = min(max(alphaOverride(:)', 0), 1);
    alphaAct(1:min(10, n)) = 0;
else
    alphaAct = alphaActivation(t, p.mtu);
end
sarcE.act = alphaAct(:);
sarcE.pCa = ac.actToPcaE(alphaAct(:));           % 0-1 activation -> pCa
sarcE.pCa = min(max(sarcE.pCa, 4.5), 9);
sarcE.pCa(1:min(10, n)) = 9;                      % silent onset, per toolbox

mt.sarcE    = sarcE;
mt.alphaAct = alphaAct(:);

% If the MTU is disabled, drive the fascicle directly with the command length.
if isfield(p.mtu, 'enabled') && ~p.mtu.enabled
    mt = directDrive(mt, t, Lmtu, 'MTU disabled: driving fascicle directly.');
    return
end

try
    ws = warning('off', 'all');   % the ODE solver can warn on extreme params
    cleanup = onCleanup(@() warning(ws));
    [~, mtData] = musTenDriver20250627(t, delta_cdlE, sarcE);
    clear cleanup
    if ~all(isfinite(mtData.hs_length)) || any(mtData.hs_length <= 0)
        error('runExtrafusalMTU:badOutput', 'non-finite fascicle length');
    end
    mtData.tendonLen = mtData.hs_force ./ sarcE.tendon_stiffness;
    mtData.mtuLen    = mtData.hs_length + mtData.tendonLen;

    mt.fascicleLength = mtData.hs_length;
    mt.mtuCmd         = mtData.cmd_length;
    mt.mtuLength      = mtData.mtuLen;
    mt.force          = mtData.hs_force;
    mt.mtData         = mtData;
    mt.ok             = true;
    mt.message        = '';
catch ME
    mt = directDrive(mt, t, Lmtu, ...
        sprintf('MTU solver failed (%s); driving fascicle directly.', ME.message));
end
end


function mt = directDrive(mt, t, Lmtu, msg)
% Fallback: fascicle = MTU command (rigid tendon), so the intrafusal fibers see
% the raw length protocol. Keeps the app usable if tendon params are extreme.
n = numel(t);
mtData.t           = t;
mtData.hs_length   = Lmtu;
mtData.cmd_length  = Lmtu;
mtData.hs_force    = zeros(1, n);
mtData.tendonLen   = zeros(1, n);
mtData.mtuLen      = Lmtu;
mt.fascicleLength  = Lmtu;
mt.mtuCmd          = Lmtu;
mt.mtuLength       = Lmtu;
mt.force           = zeros(1, n);
mt.mtData          = mtData;
mt.ok              = false;
mt.message         = msg;
end


function a = alphaActivation(t, mtu)
% Build the extrafusal (alpha) activation trace, 0-1. First 10 samples silent.
t = t(:)';
n = numel(t);
switch lower(mtu.alphaMode)
    case 'constant'
        a = (mtu.alphaLevel / 100) * ones(1, n);
    case 'sine'
        a = (mtu.alphaLevel / 100) + (mtu.alphaAmp / 100) * ...
            sin(2*pi*mtu.alphaFreq*t + mtu.alphaPhase);
    otherwise
        error('runExtrafusalMTU:badAlphaMode', ...
            'Unknown alphaMode "%s". Use constant or sine.', mtu.alphaMode);
end
a = min(max(a, 0), 1);
a(1:min(10, n)) = 0;
end
