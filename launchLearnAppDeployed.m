function launchLearnAppDeployed()
% launchLearnAppDeployed  Entry point for the STANDALONE (compiled) Learn app.
%
%   This is the function MATLAB Compiler builds into a double-clickable app
%   (see build/buildLearnApp.m). It opens the Interactive Tutorial (Learn)
%   window - Overview, Guided walkthrough, Playground - and keeps the process
%   alive until the window is closed.
%
%   NOT the same as launchSpindleTutorialGUI, which is for running from the
%   MATLAB prompt. This one differs in the two ways a compiled app needs:
%     - it guards setupTutorialPaths with ~isdeployed (paths are baked into the
%       bundle, so calling it in a deployed app would be wrong), and
%     - it uiwait()s, without which a double-clicked app opens its window and
%       exits immediately.
%
%   It is deliberately NOT named after the SpindleLearnApp class it opens:
%   spindleLearnApp.m vs SpindleLearnApp.m differed only by one capital, which
%   read as a duplicate and would collide outright on a case-insensitive
%   filesystem if the two ever shared a folder.
%
%   In development it also sets up the path, so you can test the exact deployed
%   entry point by running `launchLearnAppDeployed` in MATLAB.

if ~isdeployed
    setupTutorialPaths();          % bundled automatically when compiled
end

app = SpindleLearnApp();

% The window opens on the Overview, so pay the one-time warm-up cost (~7s,
% see SpindleAppBase.doWarmup) while the user reads it, not on their first
% walkthrough step.
SpindleAppBase.startWarmup(app.UIFigure);

% Keep the (compiled) process running until the user closes the window.
try
    uiwait(app.UIFigure);
catch
    % If the figure is already gone, just return.
end
end
