function app = launchSpindleTutorialApp()
% launchSpindleTutorialApp  Open the Interactive Tutorial (Learn) window directly.
%
%   Overview, Guided walkthrough, and Playground - for understanding the model.
%   Skips the launcher menu. See also launchSpindleTutorial, launchSpindleToolkit.

setupTutorialPaths();
a = SpindleLearnApp();
if nargout > 0, app = a; end
end
