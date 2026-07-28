function paths = setupTutorialPaths()
% setupTutorialPaths  Add the tutorial and the spindle toolbox to the MATLAB path.
%
%   paths = setupTutorialPaths() adds this tutorial's own folders (compute/,
%   app/) and the sibling matlabMuscleSpindleModellingTools toolbox to the
%   path, and returns a struct of useful locations.
%
%   The tutorial depends only on the published toolbox
%   (matlabMuscleSpindleModellingTools). It does NOT depend on
%   gammaDriveOptimization or on any OneDrive data. The one data file it
%   needs (the pCa<->activation curve) is vendored under data/.
%
%   Expected folder layout (siblings under one parent):
%       <parent>/matlabMuscleSpindleModellingTools/
%       <parent>/spindleModelTutorial/            <- this repo
%
%   If your toolbox lives elsewhere, set the environment variable
%   SPINDLE_TOOLBOX_DIR to its full path before calling this function.

thisFile   = mfilename('fullpath');
paths.root = fileparts(thisFile);

% Tutorial's own code folders
paths.compute = fullfile(paths.root, 'compute');
paths.app     = fullfile(paths.root, 'app');
paths.data    = fullfile(paths.root, 'data');
paths.docs    = fullfile(paths.root, 'docs');
addpath(paths.compute, paths.app);

% Locate the spindle toolbox
toolboxDir = getenv('SPINDLE_TOOLBOX_DIR');
if isempty(toolboxDir)
    parentDir  = fileparts(paths.root);
    toolboxDir = fullfile(parentDir, 'matlabMuscleSpindleModellingTools');
end

if ~isfolder(toolboxDir)
    error('setupTutorialPaths:toolboxNotFound', ...
        ['Could not find matlabMuscleSpindleModellingTools.\n', ...
         'Expected it here:\n    %s\n', ...
         'Clone it as a sibling of spindleModelTutorial, or set the\n', ...
         'SPINDLE_TOOLBOX_DIR environment variable to its full path.'], ...
        toolboxDir);
end

paths.toolbox = toolboxDir;
% Add the toolbox subfolders that hold the functions and @class folders.
addpath(fullfile(toolboxDir, 'spindle_model'));
addpath(fullfile(toolboxDir, 'extrafusal_model'));
addpath(fullfile(toolboxDir, 'utilities'));

% Optionally locate gammaDriveOptimization. The "Gamma optimization" tab reuses
% that project's real B-spline gamma functions (runSpindleSimForOpt_Bspline_5cp,
% getIntrafusal_pCa_Bspline_5cp) so the demo matches the manuscript workflow.
% If it is not present, the tab falls back to a simpler self-contained fit.
optDir = getenv('GAMMA_OPT_DIR');
if isempty(optDir)
    parentDir = fileparts(paths.root);
    optDir = fullfile(parentDir, 'gammaDriveOptimization');
end
if isfolder(fullfile(optDir, 'functions'))
    addpath(fullfile(optDir, 'functions'));
    paths.gammaOpt = optDir;
    paths.hasBspline = ~isempty(which('runSpindleSimForOpt_Bspline_5cp'));
else
    paths.gammaOpt = '';
    paths.hasBspline = false;
end

% Sanity check: a couple of the functions we rely on must be visible.
required = {'getDefaultSarcB', 'sarcSimDriverIntrafusal20250627', ...
            'sarc2spindle_20240310', 'integrateAndFire'};
missing = required(cellfun(@(f) isempty(which(f)), required));
if ~isempty(missing)
    error('setupTutorialPaths:missingFunctions', ...
        ['The toolbox was found at\n    %s\nbut these required functions ', ...
         'are not on the path: %s'], toolboxDir, strjoin(missing, ', '));
end
end
