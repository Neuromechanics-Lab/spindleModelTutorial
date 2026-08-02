function app = launchSpindleToolkitGUI()
% launchSpindleToolkitGUI  Open the Analysis Toolkit (Apply) window directly.
%
%   Gamma optimization + Your data - for fitting the model to data. Skips the
%   launcher menu. Needs the sibling gammaDriveOptimization repo (see
%   setupTutorialPaths). See also launchSpindleGUI, launchSpindleTutorialGUI.

setupTutorialPaths();
a = SpindleToolkitApp();
if nargout > 0, app = a; end
end
