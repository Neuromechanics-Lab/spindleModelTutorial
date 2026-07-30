function fig = launchSpindleTutorial()
% launchSpindleTutorial  Launcher for the muscle spindle model apps.
%
%   launchSpindleTutorial() opens a small chooser with two options:
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
%   fig = launchSpindleTutorial() returns the launcher figure. To skip the menu:
%       launchSpindleTutorialApp   % opens the tutorial directly
%       launchSpindleToolkit       % opens the toolkit directly
%
%   Requirements: MATLAB R2020a+, Signal Processing Toolbox, and the sibling
%   matlabMuscleSpindleModellingTools toolbox (see setupTutorialPaths).

setupTutorialPaths();
s = SpindleAppBase.sty();

f = uifigure('Name', 'Muscle Spindle Model', 'Position', [200 250 520 380], ...
    'Color', s.canvasApp, 'Resize', 'off');
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
startWarmup(f);

if nargout > 0, fig = f; end
end


% ======================================================================
function startWarmup(f)
% Run a tiny simulation shortly after the launcher appears. This forces MATLAB
% to just-in-time compile the model functions (the dominant one-time cost) while
% the user is still reading the menu, rather than on their first real run.
tmr = timer('StartDelay', 0.4, 'ExecutionMode', 'singleShot', 'BusyMode', 'drop', ...
    'TimerFcn', @(~,~) doWarmup(f), ...
    'StopFcn',  @(tm,~) delete(tm));
% If the launcher is closed first, stop the timer so its callback can't fire.
f.DeleteFcn = @(~,~) safeStop(tmr);
start(tmr);
end

function doWarmup(~)
% The one-time cold costs are (measured): the compute just-in-time compile (~2s),
% the first uiaxes plot (~4-5s) and the first uihtml render (~3s). Pay them all
% here, on a throwaway off-screen figure, so the real windows feel instant.
try
    p = defaultTutorialParams();
    p.sim.tEnd = 0.5;               % short run: JIT-warms the whole compute pipeline
    out = tutorialForwardSim(p);    % MTU + intrafusal + receptor potential + firing

    wf = uifigure('Visible', 'off');   % warm the graphics rendering path
    cln = onCleanup(@() delete(wf));
    wg = uigridlayout(wf, [2 1]);
    wax = uiaxes(wg); wax.Layout.Row = 1;
    plot(wax, out.t, out.r); area(wax, out.x_bins, out.bag.bin_pops(:, end));  %#ok<*NASGU>
    wh = uihtml(wg); wh.Layout.Row = 2; wh.HTMLSource = '<b>warm</b>';
    drawnow;
    clear cln
catch
    % Warmup is only an optimization; ignore any failure silently.
end
% (Silent by design - the warm-up is an internal speed-up, not something the
% reader needs to know about. Leave the status line blank.)
end

function safeStop(tmr)
try
    if isvalid(tmr), stop(tmr); delete(tmr); end
catch
end
end
