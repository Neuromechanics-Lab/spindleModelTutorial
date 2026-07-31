classdef SpindleToolkitApp < SpindleAppBase
% SpindleToolkitApp  Analysis Toolkit (Apply) window for the spindle model.
%
%   Gamma optimization + Your data - for fitting the model to data. Open it with
%   launchSpindleToolkit (or the launcher menu). Needs the sibling
%   gammaDriveOptimization repo for the B-spline optimization.
%
%   Shared styling/plot helpers live in SpindleAppBase.

    properties
        % Optimization handles
        optCtrl     = struct();
        optAxFit
        optAxCost
        optCostLine                % live-updated line on optAxCost
        optGammaLines = struct();  % persistent target/recovered drive lines
        optFitLines   = struct();  % persistent target/initial/optimized Ia lines
        optAxGammaS
        optAxGammaD
        optRunBtn
        optTable
        optStatus
        optResult   = [];
        % Your-data handles
        udData      = [];
        udInfo
        udStatus
        udFwdBtn
        udOptBtn
        udFitTarget                % 'what to fit' dropdown
        udSolver                   % solver dropdown
        udGammaStatic              % gamma-static model dropdown
        udCycle                    % cycle period (periodic mode only)
        udSaveBtn
        udPlotPanel
        udResAx     = [];          % persistent result axes (5; optimize uses 3)
        udLastRes   = [];          % last run's results (for Save)
        udLastKind  = '';          % 'forward' | 'optimize'
    end

    properties (Access = private)
        optCostIters = [];
        optCostVals  = [];
    end

    methods
        function obj = SpindleToolkitApp()
            obj.makeFigure('Muscle Spindle Model - Analysis Toolkit (Apply)');
            obj.buildOptimizationTab(1);
            obj.buildUserDataTab(2);
        end

        % ---- Optimization ----------------------------------------------
        function buildOptimizationTab(obj, n)
            tab = uitab(obj.TabGroup, 'Title', sprintf('%d. Gamma optimization', n), 'BackgroundColor', obj.S.canvasApp);
            g = uigridlayout(tab, [1 2]);
            g.ColumnWidth = {330, '1x'};
            g.Padding = [10 10 10 10]; g.ColumnSpacing = 10;
            g.BackgroundColor = obj.S.canvasApp;

            % Controls
            cpanel = obj.card(g, 'Optimization setup'); cpanel.Layout.Column = 1;
            cg = uigridlayout(cpanel, [14 2]);
            cg.RowHeight = repmat({'fit'}, 1, 14);
            cg.ColumnWidth = {'1.3x','1x'};
            cg.BackgroundColor = obj.S.card;

            r = 1;
            lbl = uilabel(cg, 'Text', ['Recover fusimotor (gamma) drive from a simulated Ia, using the ' ...
                'manuscript B-spline pipeline (runSpindleSimForOpt_Bspline_5cp). A sinusoidal gait-cycle ' ...
                'MTU drives the fascicle; the fit recovers the gamma-static waveform (5 B-spline control ' ...
                'points), the bag burst magnitude, and the waveform phase - 7 parameters in all.'], ...
                'WordWrap', 'on');
            lbl.Layout.Row = r; lbl.Layout.Column = [1 2]; r = r + 1;

            hdr = uilabel(cg, 'Text', 'TRUE drive (makes the target)', 'FontWeight', 'bold');
            hdr.Layout.Row = r; hdr.Layout.Column = [1 2]; r = r + 1;
            % Chain (gamma-static) is a 5-point waveform, so offer shapes rather
            % than five separate boxes. Change it to ask "can a DIFFERENT shape
            % still be recovered?" - the interesting question here.
            l = uilabel(cg, 'Text', 'gamma-static shape (chain)');
            l.Layout.Row = r; l.Layout.Column = 1;
            obj.optCtrl.trueShape = uidropdown(cg, 'Items', obj.chainShapeNames(), ...
                'Value', 'manuscript default');
            obj.optCtrl.trueShape.Layout.Row = r; obj.optCtrl.trueShape.Layout.Column = 2;
            obj.optCtrl.trueShape.Tooltip = ['The true gamma-static waveform to recover. ' ...
                'Try a different shape to see whether the fit still finds it.'];
            obj.optCtrl.trueShape.ValueChangedFcn = @(s,e) obj.previewTrueDrive();
            r = r + 1;
            obj.optCtrl.trueBag = obj.addOptSpinner(cg, r, ...
                'gamma-dynamic burst (% act.)', 0, 100, 10); r = r + 1;
            obj.optCtrl.trueBag.ValueChangedFcn = @(s,e) obj.previewTrueDrive();

            hdr = uilabel(cg, 'Text', 'INITIAL guess (starts the search)', 'FontWeight', 'bold');
            hdr.Layout.Row = r; hdr.Layout.Column = [1 2]; r = r + 1;
            obj.optCtrl.x0Bag = obj.addOptSpinner(cg, r, ...
                'gamma-dynamic burst (% act.)', 0, 100, 38); r = r + 1;

            obj.optCtrl.tEnd    = obj.addOptSpinner(cg, r, 'Sim duration (s)', 1.0, 3.0, 1.9); r = r + 1;
            obj.optCtrl.tEnd.ValueChangedFcn = @(s,e) obj.previewTrueDrive();
            obj.optCtrl.maxIter = obj.addOptSpinner(cg, r, 'Max iterations', 5, 60, 25); r = r + 1;

            % Parallel is worth a lot here: patternsearch polls 2N points per
            % iteration and they run independently, taking a default fit from
            % ~4 min to ~1.5 min on 8 cores. On by default when the toolbox is
            % present (the first run pays a one-off ~45 s pool startup).
            hasPar = ~isempty(ver('parallel')) && license('test', 'Distrib_Computing_Toolbox');
            obj.optCtrl.parallel = uicheckbox(cg, ...
                'Text', 'Use parallel (~2.6x faster; first run starts a pool)', ...
                'Value', hasPar, 'Enable', matlab.lang.OnOffSwitchState(hasPar));
            if ~hasPar
                obj.optCtrl.parallel.Tooltip = 'Needs the Parallel Computing Toolbox.';
            end
            obj.optCtrl.parallel.Layout.Row = r; obj.optCtrl.parallel.Layout.Column = [1 2]; r = r + 1;

            b1 = uibutton(cg, 'Text', 'Run optimization', 'FontWeight', 'bold', ...
                'BackgroundColor', obj.S.accent, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(s,e) obj.runOptimization());
            b1.Layout.Row = r; b1.Layout.Column = [1 2]; r = r + 1;
            obj.optRunBtn = b1;

            obj.optStatus = uilabel(cg, 'Text', 'Ready.', 'WordWrap', 'on', 'FontColor', obj.S.muted);
            obj.optStatus.Layout.Row = r; obj.optStatus.Layout.Column = [1 2]; r = r + 1;

            note = uilabel(cg, 'Text', ['The target is self-generated, so the true drive is ' ...
                'known - drawn dashed on the left, and redrawn as you change these settings. ' ...
                'A fit takes ~1.5 min with parallel on, ~4 min without.' newline newline ...
                'This is a hard optimization, and the manuscript runs it at TWO levels for that ' ...
                'reason: an outer grid over burst timing, with a full fit at every node. The demo ' ...
                'runs a single pass with timing fixed.' newline newline ...
                'See docs/07_differences_from_manuscript.md.'], 'WordWrap', 'on', ...
                'FontAngle', 'italic', 'FontColor', obj.S.muted);
            note.Layout.Row = r; note.Layout.Column = [1 2];

            % If the B-spline functions are not on the path, disable the tab.
            if isempty(which('runSpindleSimForOpt_Bspline_5cp'))
                b1.Enable = 'off';
                obj.optStatus.Text = ['gammaDriveOptimization not found on the path, so this tab is ' ...
                    'disabled. Clone it as a sibling folder (or set GAMMA_OPT_DIR) and relaunch.'];
                obj.optStatus.FontColor = [0.6 0 0];
            end

            % Plots + table
            ppanel = obj.card(g); ppanel.Layout.Column = 2;
            % Keep the table OUT of the axes grid. Sharing one grid between
            % uiaxes and a uitable renders the axes blank once plotting adds
            % legends (which become extra, unpinnable grid children). Two nested
            % grids keep the axes in a grid of their own, as the playground does.
            outer = uigridlayout(ppanel, [2 1]);
            outer.RowHeight = {'1x', 110};
            outer.RowSpacing = 8; outer.Padding = [0 0 0 0];
            outer.BackgroundColor = obj.S.card;
            pg = uigridlayout(outer, [2 2]);
            pg.Layout.Row = 1; pg.Layout.Column = 1;
            pg.RowHeight = {'1x','1x'}; pg.Padding = [0 0 0 0];
            pg.RowSpacing = 8; pg.ColumnSpacing = 10; pg.BackgroundColor = obj.S.card;
            % LEFT column = the drive you are trying to recover (target drawn
            % live as the controls change); RIGHT column = how well the fit did.
            % Reading left-to-right is then cause -> effect.
            obj.optAxGammaS = obj.axInPanel(pg, 1, 1);
            obj.optAxGammaD = obj.axInPanel(pg, 2, 1);
            obj.optAxFit    = obj.axInPanel(pg, 1, 2);
            obj.optAxCost   = obj.axInPanel(pg, 2, 2);
            obj.optTable  = uitable(outer, 'ColumnName', {'Parameter','True','Initial','Recovered','% of error closed'});
            obj.optTable.Layout.Row = 2; obj.optTable.Layout.Column = 1;
            title(obj.optAxCost,   'Cost vs iteration');
            xlabel(obj.optAxCost, 'iteration'); ylabel(obj.optAxCost, 'mean-normalized RMSE');
            % Build the cost line ONCE and update its data each iteration. Doing
            % cla + beautify + drawnow every iteration corrupts the uifigure
            % render tree and blanks every axes on the tab (all three together
            % are needed to trigger it), so never rebuild this plot in the loop.
            obj.optCostLine = plot(obj.optAxCost, NaN, NaN, '-o', 'LineWidth', 1.6, ...
                'Color', obj.S.accent, 'MarkerFaceColor', obj.S.accent, 'MarkerSize', 4);
            ax = obj.optAxFit;
            obj.optFitLines.target = plot(ax, NaN, NaN, 'Color', obj.S.total, 'LineWidth', 2);
            hold(ax, 'on');
            obj.optFitLines.init = plot(ax, NaN, NaN, '--', 'Color', obj.S.bag, 'LineWidth', 1.2);
            obj.optFitLines.opt  = plot(ax, NaN, NaN, '-', 'Color', obj.S.green, 'LineWidth', 1.6);
            hold(ax, 'off');
            title(ax, 'Target Ia vs model fit  (press Run optimization)');
            xlabel(ax, 'time (s)'); ylabel(ax, 'r (a.u.)');
            legend(ax, {'target (truth)','initial guess','optimized fit'}, ...
                'Location', 'best', 'FontSize', 8);

            % Same trick for the two drive panels: build every line ONCE, then
            % only push data into it. The target lines are refreshed on every
            % control change, so rebuilding them would hit exactly the cla +
            % beautify + drawnow combination that blanks the tab.
            s = obj.S; grey = [0.35 0.35 0.4];
            ax = obj.optAxGammaS;
            obj.optGammaLines.sTrue  = plot(ax, NaN, NaN, '--', 'Color', grey, 'LineWidth', 1.5);
            hold(ax, 'on');
            obj.optGammaLines.sTrueCP = plot(ax, NaN, NaN, 'o', 'MarkerSize', 7, ...
                'LineStyle', 'none', 'MarkerFaceColor', [0.6 0.6 0.6], 'MarkerEdgeColor', grey);
            obj.optGammaLines.sOpt   = plot(ax, NaN, NaN, '-', 'Color', s.chain, 'LineWidth', 1.8);
            obj.optGammaLines.sOptCP = plot(ax, NaN, NaN, 'o', 'MarkerSize', 7, ...
                'LineStyle', 'none', 'Color', s.chain, 'MarkerFaceColor', s.chain);
            hold(ax, 'off');
            title(ax, '\gamma-static (chain): target vs recovered');
            xlabel(ax, 'time (s)'); ylabel(ax, 'activation (%)'); ylim(ax, [0 100]);
            legend(ax, {'target','target CP','recovered','recovered CP'}, ...
                'Location', 'best', 'FontSize', 8);

            ax = obj.optAxGammaD;
            obj.optGammaLines.dTrue = plot(ax, NaN, NaN, '--', 'Color', grey, 'LineWidth', 1.5);
            hold(ax, 'on');
            obj.optGammaLines.dOpt  = plot(ax, NaN, NaN, '-', 'Color', s.bag, 'LineWidth', 1.8);
            hold(ax, 'off');
            title(ax, '\gamma-dynamic (bag burst): target vs recovered');
            xlabel(ax, 'time (s)'); ylabel(ax, 'activation (%)'); ylim(ax, [0 100]);
            legend(ax, {'target','recovered'}, 'Location', 'best', 'FontSize', 8);

            obj.beautify(ppanel);
            obj.previewTrueDrive();
            obj.refitAxes([obj.optAxGammaS obj.optAxGammaD obj.optAxFit obj.optAxCost]);
        end

        function previewTrueDrive(obj)
            % Draw the TRUE drive the user has just dialled in, before any fit.
            % Cheap: tutorialOptDemo's preview mode skips the MTU solve and the
            % optimizer, so this is safe to run straight from a control callback.
            if isempty(which('runSpindleSimForOpt_Bspline_5cp')), return; end
            try
                ac = loadActivationCurve();
                opts = struct('previewOnly', true, ...
                    'trueBagPca', ac.actToPcaB(obj.pctToFrac(obj.optCtrl.trueBag.Value)), ...
                    'trueCP',     ac.actToPcaC(obj.pctToFrac( ...
                                      obj.chainShapeByName(obj.optCtrl.trueShape.Value))), ...
                    'tEnd',       obj.optCtrl.tEnd.Value);
                gT = tutorialOptDemo(opts).gammaTrue;
                pcaC2pct = @(v) 100 * min(max(ac.pCaToActC(v), 0), 1);
                pcaB2pct = @(v) 100 * min(max(ac.pCaToActB(v), 0), 1);
                L = obj.optGammaLines;
                set(L.sTrue,   'XData', gT.t, 'YData', pcaC2pct(gT.chainPca));
                set(L.sTrueCP, 'XData', gT.controlTimes, 'YData', pcaC2pct(gT.controlPca));
                set(L.dTrue,   'XData', gT.t, 'YData', pcaB2pct(gT.bagPca));
                % A previous run's recovered traces no longer match this target.
                set([L.sOpt L.sOptCP L.dOpt], 'XData', NaN, 'YData', NaN);
                xlim(obj.optAxGammaS, [gT.t(1) gT.t(end)]);
                xlim(obj.optAxGammaD, [gT.t(1) gT.t(end)]);
            catch ME
                obj.optStatus.Text = ['Could not preview the target drive: ' ME.message];
            end
        end

        function names = chainShapeNames(~)
            s = SpindleToolkitApp.chainShapes();
            names = fieldnames(s)';
            names = cellfun(@(f) s.(f).name, names, 'UniformOutput', false);
        end

        function cp = chainShapeByName(~, nm)
            % Look up a preset's 5 control points, in % activation.
            s = SpindleToolkitApp.chainShapes();
            for f = fieldnames(s)'
                if strcmp(s.(f{1}).name, nm), cp = s.(f{1}).cp_pct; return; end
            end
            cp = s.manuscript.cp_pct;
        end

        function spn = addOptSpinner(~, parent, row, label, lo, hi, val)
            l = uilabel(parent, 'Text', label); l.Layout.Row = row; l.Layout.Column = 1;
            spn = uispinner(parent, 'Limits', [lo hi], 'Value', val, 'Step', 0.1);
            spn.Layout.Row = row; spn.Layout.Column = 2;
        end

        function f = pctToFrac(~, v)
            % % activation -> the [0 1] fraction the activation curve expects.
            f = min(max(v / 100, 0), 1);
        end

        function runOptimization(obj)
            obj.optStatus.Text = 'Setting up target + MTU...';
            obj.setBusy(true);
            obj.optRunBtn.Enable = 'off';
            drawnow;
            try
                % The GUI speaks % activation (as the rest of the tutorial does);
                % the optimizer fits pCa natively, exactly as the manuscript
                % does. Convert at this boundary only.
                ac = loadActivationCurve();
                pct2pcaB = @(v) ac.actToPcaB(obj.pctToFrac(v));
                pct2pcaC = @(v) ac.actToPcaC(obj.pctToFrac(v));

                opts = struct();
                opts.trueBagPca  = pct2pcaB(obj.optCtrl.trueBag.Value);
                opts.bag0        = pct2pcaB(obj.optCtrl.x0Bag.Value);
                opts.trueCP      = pct2pcaC(obj.chainShapeByName(obj.optCtrl.trueShape.Value));
                opts.tEnd        = obj.optCtrl.tEnd.Value;
                opts.maxIter     = round(obj.optCtrl.maxIter.Value);
                opts.useParallel = obj.optCtrl.parallel.Value;

                % Prime the cost plot; live-update via iterFcn.
                set(obj.optCostLine, 'XData', NaN, 'YData', NaN);
                obj.optCostIters = [];
                obj.optCostVals  = [];
                opts.iterFcn = @(info) obj.onOptIter(info);

                res = tutorialOptDemo(opts);
                obj.optResult = res;
                obj.plotOptResult(res);
                obj.optStatus.Text = sprintf('Done. Cost %.3g -> %.3g. Median recovery %.0f%%.', ...
                    res.fval0, res.fvalOpt, median(res.recoveryPct));
            catch ME
                obj.optStatus.Text = ['Error: ' ME.message];
            end
            obj.optRunBtn.Enable = 'on';
            obj.setBusy(false);
        end

        function onOptIter(obj, info)
            obj.optCostIters(end+1) = info.iter;
            obj.optCostVals(end+1)  = info.fval;
            set(obj.optCostLine, 'XData', obj.optCostIters, 'YData', obj.optCostVals);
            obj.optStatus.Text = sprintf('Optimizing... iter %d, cost %.4g', info.iter, info.fval);
            drawnow;
        end

        function plotOptResult(obj, res)
            % Ia fit (lines built at construction - only their data changes)
            ax = obj.optAxFit;
            set(obj.optFitLines.target, 'XData', res.t, 'YData', res.target);
            set(obj.optFitLines.init,   'XData', res.t, 'YData', res.fit0);
            set(obj.optFitLines.opt,    'XData', res.t, 'YData', res.fitOpt);
            title(ax, 'Target Ia vs model fit');
            obj.padY(ax, [res.target(:); res.fit0(:); res.fitOpt(:)]);
            xlim(ax, [res.t(1) res.t(end)]);

            % Everything is shown in % activation, to match the rest of the
            % tutorial. The fit itself ran in pCa (the model's own variable).
            ac = loadActivationCurve();
            pcaC2pct = @(v) 100 * min(max(ac.pCaToActC(v), 0), 1);
            pcaB2pct = @(v) 100 * min(max(ac.pCaToActB(v), 0), 1);

            % Drive panels: the target is already drawn (previewTrueDrive), so
            % only push data into the existing lines - see the note where they
            % are built. Re-setting the target too keeps it honest if the run
            % used values the preview never saw.
            gT = res.gammaTrue; gO = res.gammaOpt;
            L = obj.optGammaLines;
            set(L.sTrue,   'XData', gT.t, 'YData', pcaC2pct(gT.chainPca));
            set(L.sTrueCP, 'XData', gT.controlTimes, 'YData', pcaC2pct(gT.controlPca));
            set(L.sOpt,    'XData', gO.t, 'YData', pcaC2pct(gO.chainPca));
            set(L.sOptCP,  'XData', gO.controlTimes, 'YData', pcaC2pct(gO.controlPca));
            set(L.dTrue,   'XData', gT.t, 'YData', pcaB2pct(gT.bagPca));
            set(L.dOpt,    'XData', gO.t, 'YData', pcaB2pct(gO.bagPca));
            xlim(obj.optAxGammaS, [gT.t(1) gT.t(end)]);
            xlim(obj.optAxGammaD, [gT.t(1) gT.t(end)]);

            % Table (all 7 fitted parameters), converted to the displayed units:
            % activation % for the drive levels, seconds for the phase. Recovery
            % is then recomputed in those same units so the row reads honestly.
            labels = {'Bag burst (% act.)', 'Chain CP1 @0% (% act.)', ...
                      'Chain CP2 @20% (% act.)', 'Chain CP3 @40% (% act.)', ...
                      'Chain CP4 @60% (% act.)', 'Chain CP5 @80% (% act.)', ...
                      'Waveform phase (s)'};
            data = cell(numel(res.names), 5);
            for i = 1:numel(res.names)
                switch res.names{i}
                    case 'bagPca',                  cv = pcaB2pct;
                    case {'cp1','cp2','cp3','cp4','cp5'}, cv = pcaC2pct;
                    otherwise,                      cv = @(v) v;   % phase, in seconds
                end
                tv = cv(res.xTrue(i)); iv = cv(res.x0(i)); ov = cv(res.xOpt(i));
                data{i,1} = labels{i};
                data{i,2} = round(tv, 2);
                data{i,3} = round(iv, 2);
                data{i,4} = round(ov, 2);
                % Fraction of the INITIAL error closed: 0% = never moved.
                if abs(iv - tv) < 1e-9
                    data{i,5} = NaN;      % started at the answer: nothing to close
                else
                    data{i,5} = round(100 * (1 - abs(ov - tv) / abs(iv - tv)), 1);
                end
            end
            obj.optTable.Data = data;
            obj.beautify(obj.optAxFit.Parent.Parent);   % the axes grid, not its panel
            obj.refitAxes([obj.optAxGammaS obj.optAxGammaD obj.optAxFit obj.optAxCost]);
        end

        % ================================================================
        %  YOUR DATA  (bring-your-own inputs)
        % ================================================================
        function buildUserDataTab(obj, n)
            s = obj.S;
            tab = uitab(obj.TabGroup, 'Title', sprintf('%d. Your data', n), 'BackgroundColor', s.canvasApp);
            g = uigridlayout(tab, [1 2]);
            g.ColumnWidth = {360, '1x'}; g.Padding = [10 10 10 10]; g.ColumnSpacing = 10;
            g.BackgroundColor = s.canvasApp;

            % Left: instructions + controls
            cpanel = obj.card(g, 'Bring your own inputs'); cpanel.Layout.Column = 1;
            cg = uigridlayout(cpanel, [10 1]);
            cg.RowHeight = {'fit','fit','fit','fit','fit','fit','fit','fit','fit','1x'};
            cg.Padding = [12 12 12 12]; cg.RowSpacing = 8; cg.BackgroundColor = s.card;

            h = uihtml(cg); h.HTMLSource = obj.userDataHTML();  h.Layout.Row = 1;

            b1 = uibutton(cg, 'Text', 'Load .mat file...', 'FontWeight', 'bold', ...
                'BackgroundColor', s.accent, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(src,e) obj.onLoadUserData());
            b1.Layout.Row = 2;
            b2 = uibutton(cg, 'Text', 'Load built-in example', ...
                'BackgroundColor', [0.93 0.94 0.96], 'FontColor', s.navy, ...
                'ButtonPushedFcn', @(src,e) obj.onLoadExample());
            b2.Layout.Row = 3;

            obj.udInfo = uilabel(cg, 'Text', 'No data loaded.', 'WordWrap', 'on', ...
                'FontColor', s.axisTxt);
            obj.udInfo.Layout.Row = 4;

            obj.udFwdBtn = uibutton(cg, 'Text', 'Run forward  ->  receptor potential', 'FontWeight', 'bold', ...
                'Enable', 'off', 'BackgroundColor', s.tagInput, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(src,e) obj.runUserForward());
            obj.udFwdBtn.Layout.Row = 5;
            % What the optimizer compares. Default is the receptor potential:
            % the cost is mean-normalized (each trace divided by its own mean),
            % so only shape is compared and the units difference cancels.
            fitRow = uigridlayout(cg, [4 2]);
            fitRow.Layout.Row = 6;
            fitRow.ColumnWidth = {'1.1x','1x'}; fitRow.RowHeight = repmat({'fit'}, 1, 4);
            fitRow.Padding = [0 0 0 0]; fitRow.RowSpacing = 6;
            fitRow.BackgroundColor = s.card;
            uilabel(fitRow, 'Text', 'Optimize by fitting');
            obj.udFitTarget = uidropdown(fitRow, ...
                'Items', {'receptor potential (recommended)', 'firing rate'}, ...
                'Value', 'receptor potential (recommended)');
            uilabel(fitRow, 'Text', 'Solver');
            obj.udSolver = uidropdown(fitRow, ...
                'Items', {'fmincon (default)', 'patternsearch (manuscript)'}, ...
                'Value', 'fmincon (default)');
            obj.udSolver.Tooltip = ['fmincon converges better on this fit and is the default, ' ...
                'though it is SLOWER (measured on the built-in example: fmincon 147 s to cost ' ...
                '0.101, patternsearch 49 s to 0.243 at the same iteration count - patternsearch ' ...
                'is quicker per fit but needs more iterations here). ' ...
                'patternsearch is what the manuscript uses - derivative-free, so it copes better ' ...
                'with a stepped cost (which is what you get in firing mode) - and is worth trying ' ...
                'if a fit looks like it stalled.'];

            % How gamma-STATIC is modelled. The free B-spline is the general
            % answer - it can be a constant, a ramp, or any smooth shape - so it
            % is the default. The periodic variant is the manuscript's, and is
            % the better model when the protocol really is cyclic, because 5
            % numbers then describe every cycle. It needs a cycle period, which
            % the tutorial will not guess.
            uilabel(fitRow, 'Text', '\gamma-static model');
            obj.udGammaStatic = uidropdown(fitRow, 'Items', ...
                {'B-spline, free (any protocol)', 'B-spline, periodic (gait/cyclic)', ...
                 'constant level'}, 'Value', 'B-spline, free (any protocol)');
            obj.udGammaStatic.Tooltip = ['Free: 5 control points across the trial, no ' ...
                'periodicity assumed - covers constant and ramp as special cases. ' ...
                'Periodic: one cycle tiled, as the manuscript does for gait. ' ...
                'Constant: a single level (4 parameters instead of 8, so fastest).'];
            obj.udGammaStatic.ValueChangedFcn = @(s2,e) obj.onGammaStaticMode();

            uilabel(fitRow, 'Text', 'Cycle period (s)');
            obj.udCycle = uispinner(fitRow, 'Limits', [0.05 10], 'Value', 0.64, ...
                'Step', 0.01, 'Enable', 'off');
            obj.udCycle.Tooltip = 'Seconds per cycle. Used only by the periodic B-spline.';
            obj.udFitTarget.Tooltip = ['Receptor potential: the model''s r is fitted to your ' ...
                'recorded rate. The cost is mean-normalized, so only shape matters and the ' ...
                'units cancel. Firing rate: pushes the model through the spike generator ' ...
                'first, which saturates at 250 spikes/s at dt = 1 ms.'];

            note = uilabel(cg, 'Text', ['FITTED: the gamma-static drive (5 B-spline control ' ...
                'points, or a single level in constant mode), the gamma-dynamic burst magnitude, ' ...
                'and the burst ONSET and OFFSET times - 8 parameters, or 4 in constant mode. ' ...
                'Burst timing is fitted here, unlike the Gamma optimization tab where it is held ' ...
                'fixed.' newline newline ...
                'The cost compares SHAPE - each trace divided by its own mean - so the model''s ' ...
                'receptor potential can be fitted directly to your recorded firing. Simha et al. ' ...
                'find this gives similar answers either way, and it keeps the spike generator''s ' ...
                '250 spikes/s ceiling out of the objective. Details in docs/06_your_data.md.'], ...
                'WordWrap', 'on', ...
                'FontAngle', 'italic', 'FontColor', s.muted, 'FontSize', 11);
            note.Layout.Row = 7;

            obj.udOptBtn = uibutton(cg, 'Text', 'Optimize gamma  ->  drive', 'FontWeight', 'bold', ...
                'Enable', 'off', 'BackgroundColor', s.tagOutput, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(src,e) obj.runUserOptimize());
            obj.udOptBtn.Layout.Row = 8;

            obj.udSaveBtn = uibutton(cg, 'Text', 'Save results...', ...
                'Enable', 'off', 'BackgroundColor', [0.93 0.94 0.96], 'FontColor', s.navy, ...
                'ButtonPushedFcn', @(src,e) obj.saveUserRun());
            obj.udSaveBtn.Layout.Row = 9;
            obj.udSaveBtn.Tooltip = 'Write the last run to a .mat (everything) and a .csv (time series)';

            obj.udStatus = uilabel(cg, 'Text', 'Ready.', 'WordWrap', 'on', 'FontColor', s.muted);
            obj.udStatus.Layout.Row = 10;

            % Right: results. Build the 5 result axes ONCE (persistent, always
            % visible) - the same pattern the Gamma-optimization tab uses. Freshly
            % building a grid of axes per run can render collapsed the first time;
            % persistent axes in an always-visible panel avoid that entirely.
            % Forward runs use all 5 axes; optimize runs use the first 3.
            obj.udPlotPanel = obj.card(g); obj.udPlotPanel.Layout.Column = 2;
            rg = uigridlayout(obj.udPlotPanel, [5 1]);
            rg.RowHeight = repmat({'1x'}, 1, 5); rg.ColumnWidth = {'1x'};
            rg.Padding = [8 8 8 8]; rg.RowSpacing = 8; rg.BackgroundColor = s.card;
            obj.udResAx = gobjects(1, 5);
            for i = 1:5, obj.udResAx(i) = obj.axInGrid(rg, i); end
            title(obj.udResAx(1), 'Load a file or the built-in example, then choose an action', ...
                'Color', s.muted);
        end

        function onLoadUserData(obj)
            [f, pth] = uigetfile({'*.mat','MAT-files (*.mat)'}, 'Select your data file');
            if isequal(f, 0), return; end
            obj.setBusy(true);
            try
                obj.udData = loadUserData(fullfile(pth, f));
                obj.afterLoad();
            catch ME
                obj.udData = [];
                obj.udInfo.Text = 'No data loaded.';
                obj.udFwdBtn.Enable = 'off'; obj.udOptBtn.Enable = 'off';
                obj.udStatus.Text = ['Could not load: ' ME.message];
            end
            obj.setBusy(false);
        end

        function onLoadExample(obj)
            obj.setBusy(true); obj.udStatus.Text = 'Building example...'; drawnow;
            try
                obj.udData = exampleUserData();
                obj.afterLoad();
            catch ME
                obj.udStatus.Text = ['Example failed: ' ME.message];
            end
            obj.setBusy(false);
        end

        function afterLoad(obj)
            d = obj.udData;
            [~, nm, ext] = fileparts(d.file);
            lenKind = 'MTU length'; if d.hasFascicle, lenKind = 'fascicle length'; end
            avail = {};
            if d.availForward,  avail{end+1} = 'forward (->receptor potential)'; end
            if d.availOptimize, avail{end+1} = 'optimize (->gamma)'; end
            obj.udInfo.Text = sprintf(['Loaded %s%s\n%d samples, dt = %.4g s, %s.\n' ...
                'Available: %s.'], nm, ext, d.n, d.dt, lenKind, strjoin(avail, ', '));
            obj.setEnable(obj.udFwdBtn, d.availForward);
            obj.setEnable(obj.udOptBtn, d.availOptimize);
            obj.udStatus.Text = 'Data loaded. Choose an action.';
        end

        function runUserForward(obj)
            if isempty(obj.udData), return; end
            obj.setBusy(true); obj.udStatus.Text = 'Running forward simulation...'; drawnow;
            try
                out = runForwardFromData(obj.udData);
                obj.renderUserForward(out);
                obj.udLastRes = out; obj.udLastKind = 'forward';
                obj.setEnable(obj.udSaveBtn, true);
                obj.udStatus.Text = 'Forward run complete. "Save results..." to export.';
            catch ME
                obj.udStatus.Text = ['Error: ' ME.message];
            end
            obj.setBusy(false);
        end

        function clearUDAxes(~, a)
            % Fully reset each result axes: clear content, drop any legend, and
            % restore auto-scaling (so stale limits/legends don't carry over when
            % switching between forward and optimize views).
            for i = 1:numel(a)
                cla(a(i), 'reset');
                if ~isempty(a(i).Legend), delete(a(i).Legend); end
            end
        end

        function renderUserForward(obj, out)
            a = obj.udResAx;
            obj.clearUDAxes(a);
            % Four panels, ending at the RECEPTOR POTENTIAL - the model's output.
            % Spikes are left to examples/spikesFromReceptorPotential.m; see the
            % walkthrough step "From receptor potential to spikes" for why.
            for i = 1:4, a(i).Visible = 'on'; end
            a(5).Visible = 'off';
            a(1).Parent.Parent.RowHeight = {'1x','1x','1x','1x',0};   % panel -> grid
            obj.axLength(a(1), out);
            obj.axActivation(a(2), out);
            obj.axForce(a(3), out);
            obj.axReceptor(a(4), out); xlabel(a(4), 'time (s)');
            obj.beautify(obj.udPlotPanel);
            obj.refitAxes(a);
        end

        function runUserOptimize(obj)
            if isempty(obj.udData), return; end
            obj.setBusy(true); obj.udOptBtn.Enable = 'off'; obj.udFwdBtn.Enable = 'off';
            obj.udStatus.Text = 'Optimizing gamma to match your recording (~2 min)...'; drawnow;
            try
                % Run first (status-only live updates), THEN build + plot the
                % results synchronously so the axes lay out reliably.
                if startsWith(obj.udFitTarget.Value, 'receptor')
                    ft = 'receptor';
                else
                    ft = 'firing';
                end
                if startsWith(obj.udSolver.Value, 'patternsearch')
                    sv = 'patternsearch';
                else
                    sv = 'fmincon';
                end
                switch obj.udGammaStatic.Value
                    case 'B-spline, periodic (gait/cyclic)', gs = 'bspline-periodic';
                    case 'constant level',                   gs = 'constant';
                    otherwise,                               gs = 'bspline-free';
                end
                res = runOptFromData(obj.udData, struct('maxIter', 20, ...
                    'fitTarget', ft, 'solver', sv, 'gammaStatic', gs, ...
                    'cyclePeriod', obj.udCycle.Value, ...
                    'iterFcn', @(info) obj.onUserOptIter(info)));
                obj.renderUserOptimize(res);
                obj.udLastRes = res; obj.udLastKind = 'optimize';
                obj.setEnable(obj.udSaveBtn, true);
                obj.udStatus.Text = sprintf(['Optimize complete. Cost %.3g -> %.3g. ' ...
                    '"Save results..." to export.'], res.fval0, res.fvalOpt);
            catch ME
                obj.udStatus.Text = ['Error: ' ME.message];
            end
            obj.setEnable(obj.udFwdBtn, obj.udData.availForward);
            obj.setEnable(obj.udOptBtn, obj.udData.availOptimize);
            obj.setBusy(false);
        end

        function renderUserOptimize(obj, res)
            a = obj.udResAx;
            obj.clearUDAxes(a);
            for i = 1:4, a(i).Visible = 'on'; end
            a(5).Visible = 'off';                          % optimize uses 4 panels
            a(1).Parent.Parent.RowHeight = {'1x','1x','1x','1x', 0};  % panel -> grid

            % Fit vs target. Both traces are shown MEAN-NORMALIZED, because that
            % is what the cost actually minimized - drawing them in raw units
            % would imply an absolute match that was never fitted.
            nrm = @(v) v(:)' / mean(v(isfinite(v)));
            axFit = a(1);
            plot(axFit, res.t, nrm(res.target), 'Color', obj.S.muted, 'LineWidth', obj.S.lw); hold(axFit, 'on');
            plot(axFit, res.t, nrm(res.fit0), '--', 'Color', obj.S.tagOutput, 'LineWidth', obj.S.lwThin);
            plot(axFit, res.t, nrm(res.fitOpt), 'Color', obj.S.green, 'LineWidth', obj.S.lw); hold(axFit, 'off');
            if strcmp(res.fitTarget, 'receptor')
                title(axFit, 'Your Ia firing vs model receptor potential (shape)');
                legend(axFit, {'your firing','initial guess (r)','optimized fit (r)'}, 'Location', 'best');
            else
                title(axFit, 'Your Ia firing vs model firing (shape)');
                legend(axFit, {'your firing','initial guess','optimized fit'}, 'Location', 'best');
            end
            ylabel(axFit, 'mean-normalized');
            obj.padY(axFit, [nrm(res.target)'; nrm(res.fitOpt)']); xlim(axFit, [res.t(1) res.t(end)]);
            obj.tagAxes(axFit, 'output');

            % The INPUTS the fit was given: your MTU length (and the fascicle the
            % model derives from it), then the activations - alpha as supplied,
            % chain and bag as RECOVERED. Both reuse the shared panel helpers, so
            % these read identically to the forward run and the Playground.
            obj.axLength(a(2), res.outOpt);

            % Activation in % - the same units the rest of the tutorial uses.
            % res.outOpt already carries the recovered gamma as actC/actB,
            % because it was re-simulated at the solution.
            obj.axActivation(a(3), res.outOpt);
            title(a(3), 'Activation:  \alpha as given,  \gamma RECOVERED');

            % Cost vs iteration (from the recorded history)
            axCost = a(4);
            if ~isempty(res.history)
                plot(axCost, [res.history.iter], [res.history.fval], '-o', ...
                    'LineWidth', 1.8, 'Color', obj.S.accent);
            end
            title(axCost, 'Cost vs iteration'); xlabel(axCost, 'iteration');
            ylabel(axCost, 'mean-normalized RMSE'); grid(axCost, 'on');

            obj.beautify(obj.udPlotPanel);
            obj.refitAxes(a);
        end

        function onGammaStaticMode(obj)
            % Cycle period only means anything for the periodic B-spline.
            obj.setEnable(obj.udCycle, ...
                strcmp(obj.udGammaStatic.Value, 'B-spline, periodic (gait/cyclic)'));
        end

        function saveUserRun(obj)
            % Export the last Your-data run: a .mat with everything and a .csv
            % of the time series.
            if isempty(obj.udLastRes)
                obj.udStatus.Text = 'Nothing to save yet - run forward or optimize first.';
                return
            end
            defName = sprintf('spindleResults_%s', obj.udLastKind);
            [f, pth] = uiputfile({'*.mat','Results (.mat + .csv)'}, ...
                'Save results as', defName);
            if isequal(f, 0), return; end
            obj.setBusy(true);
            try
                [~, stem] = fileparts(f);
                files = saveUserResults(fullfile(pth, stem), obj.udLastRes, obj.udLastKind);
                [~, n1, e1] = fileparts(files{1});
                [~, n2, e2] = fileparts(files{2});
                obj.udStatus.Text = sprintf('Saved %s%s and %s%s to %s', n1, e1, n2, e2, pth);
            catch ME
                obj.udStatus.Text = ['Could not save: ' ME.message];
            end
            obj.setBusy(false);
        end

        function onUserOptIter(obj, info)
            obj.udStatus.Text = sprintf('Optimizing... iter %d, cost %.4g', info.iter, info.fval);
            drawnow;
        end
    end

    methods (Static)
        function s = chainShapes()
            % Preset TRUE gamma-static waveforms, as the 5 B-spline control
            % points at 0/20/40/60/80% of the gait cycle, in % ACTIVATION.
            % "manuscript default" is the waveform used elsewhere in the tutorial
            % (equivalent to pCa [6.8 5.6 6.0 6.6 7.2]).
            s.manuscript = struct('name', 'manuscript default', 'cp_pct', [10 77 49 14  3]);
            s.flat       = struct('name', 'flat (constant)',    'cp_pct', [50 50 50 50 50]);
            s.single     = struct('name', 'single peak',        'cp_pct', [10 20 80 25 10]);
            s.double     = struct('name', 'double peak',        'cp_pct', [75 20 70 20 45]);
            s.ramp       = struct('name', 'ramp up',            'cp_pct', [ 5 25 45 65 85]);
        end

        function s = userDataHTML()
            s = [ ...
'<html><head><style>', ...
'body{font-family:-apple-system,"Segoe UI",Helvetica,Arial,sans-serif;color:#333;margin:2px;font-size:12.5px;line-height:1.45;}', ...
'code{background:#eef2f8;padding:0 3px;border-radius:3px;font-size:11.5px;}', ...
'b{color:#2c4a68;} .k{color:#3a7a5a;} ul{margin:4px 0 6px 0;padding-left:18px;} li{margin:2px 0;}', ...
'</style></head><body>', ...
'Run the model on <b>your own</b> data. Save a <code>.mat</code> with these variables ', ...
'(all the same length as <code>t</code>):', ...
'<ul>', ...
'<li><code>t</code> - time (s), ~1 ms step</li>', ...
'<li><code>mtuLength</code> <i>or</i> <code>fascicleLength</code> - length (nm)</li>', ...
'<li><code>alphaAct</code> - &alpha; activation (0-1 or %)  <i>opt.</i></li>', ...
'<li class="k"><code>chainAct</code>, <code>bagAct</code> - &gamma; activations &rarr; for a FORWARD run</li>', ...
'<li class="k"><code>targetFiring</code> - Ia rate (spikes/s) &rarr; to OPTIMIZE &gamma;</li>', ...
'</ul>', ...
'<b>Forward:</b> length + activations &rarr; forces and the Ia receptor potential.<br>', ...
'<b>Optimize:</b> length + your recorded Ia firing &rarr; the &gamma; drive that reproduces it. ', ...
'The cost is mean-normalized (shape only), so the model&rsquo;s receptor potential can be fitted ', ...
'directly to your firing rate; a switch lets you fit model firing instead.', ...
'</body></html>'];
        end
    end
end
