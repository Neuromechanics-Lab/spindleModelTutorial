function spindleLearnApp()
% spindleLearnApp  Entry point for the standalone "Learn" application.
%
%   This is the function MATLAB Compiler builds into a double-clickable app
%   (see build/buildLearnApp.m). It opens the Interactive Tutorial (Learn)
%   window - Overview, Guided walkthrough, Playground - and keeps the process
%   alive until the window is closed.
%
%   In development (not compiled) it also sets up the MATLAB path, so you can
%   test the exact deployed entry point by running `spindleLearnApp` in MATLAB.

if ~isdeployed
    setupTutorialPaths();          % bundled automatically when compiled
end

app = SpindleLearnApp();

% Keep the (compiled) process running until the user closes the window.
try
    uiwait(app.UIFigure);
catch
    % If the figure is already gone, just return.
end
end
