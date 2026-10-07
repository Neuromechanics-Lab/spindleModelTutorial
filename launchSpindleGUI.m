function fig = launchSpindleGUI()
% launchSpindleGUI  Launcher for the muscle spindle model apps.
%
%   This is the ENTRY POINT: it opens a small chooser, and the two windows it
%   offers have their own launchers (launchSpindleTutorialGUI,
%   launchSpindleToolkitGUI) if you want to skip the menu.
%
%   launchSpindleGUI() opens a small chooser with two options:
%
%     * Interactive Tutorial (Learn) - Overview, Guided walkthrough, Playground.
%       Understand the model by exploring it. Needs only the core toolbox.
%
%     * Analysis Toolkit (Apply) - Gamma optimization + Your data. Fit the model
%       to data. Also needs the sibling gammaDriveOptimization repo.
%
%   While the launcher is open, it quietly WARMS UP the model in the background
%   (a tiny throwaway simulation) so MATLAB's one-time just-in-time compilation
%   happens while you read the menu -- the first real simulation is then quick.
%
%   fig = launchSpindleGUI() returns the launcher figure. To skip the menu:
%       launchSpindleTutorialGUI   % opens the tutorial directly
%       launchSpindleToolkitGUI    % opens the toolkit directly
%
%   Requirements: MATLAB R2020a+, Signal Processing Toolbox, and the sibling
%   matlabMuscleSpindleModellingTools toolbox (see setupTutorialPaths).

setupTutorialPaths();
s = SpindleAppBase.sty();

f = uifigure('Name', 'Muscle Spindle Model', 'Position', SpindleAppBase.fitToScreen(520, 380), ...
    'Color', s.canvasApp, 'Resize', 'off');
SpindleAppBase.lockLightTheme(f);
g = uigridlayout(f, [4 1]);
g.RowHeight = {'fit', 'fit', '1x', '1x'};
g.Padding = [24 20 24 18]; g.RowSpacing = 12; g.BackgroundColor = s.canvasApp;

t = uilabel(g, 'Text', 'Muscle Spindle Model', 'FontSize', 20, 'FontWeight', 'bold', ...
    'FontColor', s.navy);
t.Layout.Row = 1;
sub = uilabel(g, 'Text', 'Choose an app to open:', 'FontSize', 13, 'FontColor', s.muted);
sub.Layout.Row = 2;

b1 = uibutton(g, 'Text', 'Interactive Tutorial  (Learn)', ...
    'FontSize', 15, 'FontWeight', 'bold', 'FontColor', [1 1 1], ...
    'BackgroundColor', s.accent, 'ButtonPushedFcn', @(src,e) SpindleLearnApp());
b1.Layout.Row = 3;
b1.Tooltip = 'Overview, Guided walkthrough, Playground - understand the model.';

b2 = uibutton(g, 'Text', 'Analysis Toolkit  (Apply)', ...
    'FontSize', 15, 'FontWeight', 'bold', 'FontColor', [1 1 1], ...
    'BackgroundColor', s.tagOutput, 'ButtonPushedFcn', @(src,e) SpindleToolkitApp());
b2.Layout.Row = 4;
b2.Tooltip = 'Gamma optimization + Your data - fit the model to data.';

% Warm the model up in the background so the first real simulation is fast.
% This is silent: an internal speed-up, not something the reader needs to see.
SpindleAppBase.startWarmup(f);

if nargout > 0, fig = f; end
end
