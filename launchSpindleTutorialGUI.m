function app = launchSpindleTutorialGUI()
% launchSpindleTutorialGUI  Open the Interactive Tutorial (Learn) window directly.
%
%   Overview, Guided walkthrough, and Playground - for understanding the model.
%   Skips the launcher menu. See also launchSpindleGUI, launchSpindleToolkitGUI.

setupTutorialPaths();
a = SpindleLearnApp();
if nargout > 0, app = a; end
end
