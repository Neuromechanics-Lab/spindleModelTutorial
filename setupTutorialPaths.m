function paths = setupTutorialPaths()
% setupTutorialPaths  Put the tutorial and its model dependencies on the path.
%
%   paths = setupTutorialPaths() adds this tutorial's own folders (compute/,
%   app/) plus the muscle spindle model code, and returns a struct of locations.
%
%   THIS REPO IS SELF-SUFFICIENT. The model files it needs are vendored under
%   vendor/ (see vendor/VENDOR_INFO.txt), so a plain `git clone` runs with
%   nothing else to install.
%
%   If you also have the SOURCE repositories checked out as siblings, they are
%   preferred automatically, so your edits there take effect immediately:
%       <parent>/matlabMuscleSpindleModellingTools/   (the model)
%       <parent>/gammaDriveOptimization/              (B-spline optimization)
%       <parent>/spindleModelTutorial/                <- this repo
%
%   Override either location with an environment variable:
%       setenv('SPINDLE_TOOLBOX_DIR', '/full/path/to/matlabMuscleSpindleModellingTools')
%       setenv('GAMMA_OPT_DIR',       '/full/path/to/gammaDriveOptimization')
%
%   paths.usingVendored is true for each dependency served from vendor/.
%   Re-sync the vendored copies with tools/refreshVendor.m.

thisFile   = mfilename('fullpath');
paths.root = fileparts(thisFile);
parentDir  = fileparts(paths.root);
vendorRoot = fullfile(paths.root, 'vendor');

% Tutorial's own code folders
paths.compute = fullfile(paths.root, 'compute');
paths.app     = fullfile(paths.root, 'app');
paths.data    = fullfile(paths.root, 'data');
paths.docs    = fullfile(paths.root, 'docs');
addpath(paths.compute, paths.app);

% ---- The model: live sibling repo if present, else the vendored copy ----
toolboxDir = getenv('SPINDLE_TOOLBOX_DIR');
if isempty(toolboxDir)
    toolboxDir = fullfile(parentDir, 'matlabMuscleSpindleModellingTools');
end
paths.usingVendoredToolbox = false;
if ~isfolder(fullfile(toolboxDir, 'spindle_model'))
    toolboxDir = fullfile(vendorRoot, 'matlabMuscleSpindleModellingTools');
    paths.usingVendoredToolbox = true;
end
if ~isfolder(fullfile(toolboxDir, 'spindle_model'))
    error('setupTutorialPaths:toolboxNotFound', ...
        ['Could not find the spindle model code.\n', ...
         'Expected either a sibling matlabMuscleSpindleModellingTools repo, or\n', ...
         'the vendored copy at:\n    %s\n', ...
         'If the vendor/ folder is missing, re-clone this repository.'], ...
        fullfile(vendorRoot, 'matlabMuscleSpindleModellingTools'));
end
paths.toolbox = toolboxDir;
addpath(fullfile(toolboxDir, 'spindle_model'));
addpath(fullfile(toolboxDir, 'extrafusal_model'));
if isfolder(fullfile(toolboxDir, 'utilities'))
    addpath(fullfile(toolboxDir, 'utilities'));   % source repo only
end

% ---- B-spline optimization: live sibling repo if present, else vendored ----
% Used by the Analysis Toolkit's "Gamma optimization" tab.
optDir = getenv('GAMMA_OPT_DIR');
if isempty(optDir)
    optDir = fullfile(parentDir, 'gammaDriveOptimization');
end
paths.usingVendoredGammaOpt = false;
if ~isfolder(fullfile(optDir, 'functions'))
    optDir = fullfile(vendorRoot, 'gammaDriveOptimization');
    paths.usingVendoredGammaOpt = true;
end
if isfolder(fullfile(optDir, 'functions'))
    addpath(fullfile(optDir, 'functions'));
    paths.gammaOpt = optDir;
else
    paths.gammaOpt = '';
    paths.usingVendoredGammaOpt = false;
end
paths.hasBspline = ~isempty(which('runSpindleSimForOpt_Bspline_5cp'));

% ---- Sanity check: the functions we rely on must be visible ----
required = {'getDefaultSarcB', 'sarcSimDriverIntrafusal20250627', ...
            'sarc2spindle_20240310', 'integrateAndFire_v2'};
missing = required(cellfun(@(f) isempty(which(f)), required));
if ~isempty(missing)
    error('setupTutorialPaths:missingFunctions', ...
        ['The model code was found at\n    %s\nbut these required functions ', ...
         'are not on the path: %s'], toolboxDir, strjoin(missing, ', '));
end
end
