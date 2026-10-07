function results = buildLearnApp()
% buildLearnApp  Compile the "Learn" window into a standalone desktop app.
%
%   Produces a double-clickable application (no MATLAB license needed to RUN it,
%   only the free MATLAB Runtime) from launchLearnAppDeployed.m. Run this once, on each
%   operating system you want to ship (the output is platform-specific: build on
%   macOS -> Mac app, on Windows -> .exe).
%
%   Prerequisites (one-time):
%     * MATLAB Compiler add-on installed (Home tab -> Add-Ons -> Get Add-Ons ->
%       search "MATLAB Compiler"). You are licensed for it; it just needs
%       installing. Check with:  exist('mcc')   (should be 2).
%     * The sibling matlabMuscleSpindleModellingTools on disk (so the model
%       functions get bundled). gammaDriveOptimization is NOT required for the
%       Learn app, but if present it is harmlessly bundled too.
%
%   Usage:
%     cd(fullfile(<repo>, 'build')); buildLearnApp;
%   Output goes to  <repo>/build/SpindleTutorialLearn/  including an installer
%   that can fetch/include the MATLAB Runtime for end users.

if isempty(which('compiler.build.standaloneApplication')) && ~exist('mcc', 'file')
    error('buildLearnApp:noCompiler', ...
        ['MATLAB Compiler is not installed. Install the "MATLAB Compiler" ', ...
         'add-on (you are licensed for it), then re-run buildLearnApp.']);
end

here = fileparts(mfilename('fullpath'));
root = fileparts(here);                     % repo root
addpath(root);                               % so setupTutorialPaths is visible
setupTutorialPaths();                        % put the toolbox on the path so deps trace

% The Learn app filters fiber forces inside sarc2spindle, so Signal Processing
% must be INSTALLED at build time. Without it mcc still produces an executable,
% but one that dies at runtime on the user's machine - check up front instead.
needed = {'butter', 'Signal Processing Toolbox'; ...
          'filtfilt', 'Signal Processing Toolbox'};
absent = needed(cellfun(@(f) isempty(which(f)), needed(:,1)), 2);
if ~isempty(absent)
    error('buildLearnApp:missingToolbox', ...
        ['Cannot build: %s is licensed but not installed.\n', ...
         'Install it via Home tab -> Add-Ons -> Get Add-Ons (sign in to your\n', ...
         'MathWorks account), then re-run buildLearnApp.'], ...
        strjoin(unique(absent), ', '));
end

% A Mac build is native only to the architecture of the MATLAB that compiles it.
% Before R2023b MATLAB was Intel-only ('maci64'), so its apps run under Rosetta
% on Apple silicon - slowly. Build from an Apple silicon MATLAB ('maca64').
if strcmp(computer('arch'), 'maci64')
    warning('buildLearnApp:intelMac', ...
        ['This MATLAB is Intel (maci64): the app will run under Rosetta, slowly, ', ...
         'on Apple silicon Macs. Build from MATLAB R2023b+ for Apple silicon ', ...
         '(computer(''arch'') = ''maca64'') instead.']);
end

entry   = fullfile(root, 'launchLearnAppDeployed.m');
dataMat = fullfile(root, 'data', 'ActCurveSim120240819.mat');
figPng  = fullfile(root, 'data', 'spindleModelFig.png');
% Output is platform-specific (a Mac .app vs a Windows .exe), so keep each
% platform's build in its own folder - run this script once per OS.
if ispc,        plat = 'win';
elseif ismac,   plat = 'mac';
else,           plat = 'linux';
end
outDir  = fullfile(root, 'build', ['SpindleTutorialLearn_' plat]);
if ~isfolder(outDir), mkdir(outDir); end

fprintf('Compiling %s\n  -> %s\n', entry, outDir);

% On Windows, standaloneApplication makes a console program, which opens a
% command window behind the app for as long as it runs. A windowed app has none.
if ispc
    buildFcn = @compiler.build.standaloneWindowsApplication;
else
    buildFcn = @compiler.build.standaloneApplication;
end
results = buildFcn(entry, ...
    'ExecutableName',    'SpindleTutorial', ...
    'OutputDir',         outDir, ...
    'AdditionalFiles',   {dataMat, figPng}, ... % activation curve + overview figure
    'AutoDetectDataFiles', 'on', ...
    'Verbose',           'on');

fprintf('\nStandalone app built. Packaging an installer for distribution...\n');

% Package an installer end users double-click. 'web' delivery keeps the
% installer small and downloads the (free) MATLAB Runtime at install time; use
% 'installer' instead to embed the Runtime for a fully offline (large) download.
compiler.package.installer(results, ...
    'InstallerName',   'SpindleTutorialInstaller', ...
    'ApplicationName', 'Spindle Tutorial', ...
    'AuthorCompany',   'Neuromechanics Lab, Emory University', ...
    'RuntimeDelivery', 'web', ...
    'OutputDir',       fullfile(outDir, 'installer'));

if ispc,        appName = 'SpindleTutorial.exe';
elseif ismac,   appName = 'SpindleTutorial.app';
else,           appName = 'SpindleTutorial';
end
fprintf('\nDone. Artifacts:\n');
fprintf('  standalone app : %s\n', fullfile(outDir, appName));
fprintf('  installer      : %s\n', fullfile(outDir, 'installer'));

% ---- Equivalent one-liner using the older mcc interface -----------------
% mcc -m launchLearnAppDeployed.m -a data/ActCurveSim120240819.mat -d build/SpindleTutorialLearn
end
