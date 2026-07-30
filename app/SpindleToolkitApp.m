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
                'MTU drives the fascicle; the fit recovers the gamma-static B-spline (5 control points), ' ...
                'the bag burst magnitude, and its phase.'], 'WordWrap', 'on');
            lbl.Layout.Row = r; lbl.Layout.Column = [1 2]; r = r + 1;

            hdr = uilabel(cg, 'Text', 'TRUE bag burst (make the target)', 'FontWeight', 'bold');
            hdr.Layout.Row = r; hdr.Layout.Column = [1 2]; r = r + 1;
            obj.optCtrl.trueBag = obj.addOptSpinner(cg, r, 'Bag burst pCa (true)', 4.5, 9, 5.5); r = r + 1;

            hdr = uilabel(cg, 'Text', 'INITIAL guess (start the search)', 'FontWeight', 'bold');
            hdr.Layout.Row = r; hdr.Layout.Column = [1 2]; r = r + 1;
            obj.optCtrl.x0Bag = obj.addOptSpinner(cg, r, 'Bag burst pCa (guess)', 4.5, 9, 7.0); r = r + 1;

            obj.optCtrl.tEnd    = obj.addOptSpinner(cg, r, 'Sim duration (s)', 1.0, 3.0, 1.9); r = r + 1;
            obj.optCtrl.maxIter = obj.addOptSpinner(cg, r, 'Max iterations', 5, 40, 12); r = r + 1;

            obj.optCtrl.parallel = uicheckbox(cg, 'Text', 'Use parallel (faster; starts a pool)', 'Value', false);
            obj.optCtrl.parallel.Layout.Row = r; obj.optCtrl.parallel.Layout.Column = [1 2]; r = r + 1;

            b1 = uibutton(cg, 'Text', 'Run optimization', 'FontWeight', 'bold', ...
                'BackgroundColor', obj.S.accent, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(s,e) obj.runOptimization());
            b1.Layout.Row = r; b1.Layout.Column = [1 2]; r = r + 1;
            obj.optRunBtn = b1;

            obj.optStatus = uilabel(cg, 'Text', 'Ready.', 'WordWrap', 'on', 'FontColor', obj.S.muted);
            obj.optStatus.Layout.Row = r; obj.optStatus.Layout.Column = [1 2]; r = r + 1;

            note = uilabel(cg, 'Text', ['The target is self-generated, so the true gamma waveform is known ' ...
                'and drawn dashed on the right. Burst TIMING is held fixed (the manuscript optimizes it in ' ...
                'an outer grid); it is hard to identify from a sharp transient. Each objective evaluation ' ...
                'runs the full model, so a fit takes ~1-2 min.'], 'WordWrap', 'on', ...
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
            pg = uigridlayout(ppanel, [3 2]); pg.RowHeight = {'1x','1x', 110};
            pg.RowSpacing = 8; pg.ColumnSpacing = 10; pg.BackgroundColor = obj.S.card;
            obj.optAxFit   = uiaxes(pg); obj.optAxFit.Layout.Row = 1;   obj.optAxFit.Layout.Column = 1;
            obj.optAxGammaS = uiaxes(pg); obj.optAxGammaS.Layout.Row = 1; obj.optAxGammaS.Layout.Column = 2;
            obj.optAxCost  = uiaxes(pg); obj.optAxCost.Layout.Row = 2;  obj.optAxCost.Layout.Column = 1;
            obj.optAxGammaD = uiaxes(pg); obj.optAxGammaD.Layout.Row = 2; obj.optAxGammaD.Layout.Column = 2;
            obj.optTable  = uitable(pg, 'ColumnName', {'Parameter','True','Initial','Recovered','Recovery %'});
            obj.optTable.Layout.Row = 3; obj.optTable.Layout.Column = [1 2];
            title(obj.optAxFit,    'Target Ia vs model fit  (press Run optimization)');
            title(obj.optAxCost,   'Cost vs iteration');
            title(obj.optAxGammaS, 'Recovered \gamma-static (chain)');
            title(obj.optAxGammaD, 'Recovered \gamma-dynamic (bag burst)');
            obj.beautify(ppanel);
        end

        function spn = addOptSpinner(~, parent, row, label, lo, hi, val)
            l = uilabel(parent, 'Text', label); l.Layout.Row = row; l.Layout.Column = 1;
            spn = uispinner(parent, 'Limits', [lo hi], 'Value', val, 'Step', 0.1);
            spn.Layout.Row = row; spn.Layout.Column = 2;
        end

        function runOptimization(obj)
            obj.optStatus.Text = 'Setting up target + MTU...';
            obj.setBusy(true);
            obj.optRunBtn.Enable = 'off';
            drawnow;
            try
                opts = struct();
                opts.trueBagPca  = obj.optCtrl.trueBag.Value;
                opts.bag0        = obj.optCtrl.x0Bag.Value;
                opts.tEnd        = obj.optCtrl.tEnd.Value;
                opts.maxIter     = round(obj.optCtrl.maxIter.Value);
                opts.useParallel = obj.optCtrl.parallel.Value;

                % Prime the cost plot; live-update via iterFcn.
                cla(obj.optAxCost);
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
            ax = obj.optAxCost; cla(ax);
            plot(ax, obj.optCostIters, obj.optCostVals, '-o', 'LineWidth', 1.6, ...
                'Color', obj.S.accent, 'MarkerFaceColor', obj.S.accent, 'MarkerSize', 4);
            title(ax, 'Cost vs iteration'); xlabel(ax, 'iteration'); ylabel(ax, 'RMSE cost');
            obj.beautify(ax.Parent);
            obj.optStatus.Text = sprintf('Optimizing... iter %d, cost %.4g', info.iter, info.fval);
            drawnow;
        end

        function plotOptResult(obj, res)
            s = obj.S; grey = [0.35 0.35 0.4];

            % Ia fit
            ax = obj.optAxFit; cla(ax);
            plot(ax, res.t, res.target, 'Color', s.total, 'LineWidth', 2); hold(ax, 'on');
            plot(ax, res.t, res.fit0, '--', 'Color', s.bag, 'LineWidth', 1.2);
            plot(ax, res.t, res.fitOpt, '-', 'Color', s.green, 'LineWidth', 1.6);
            hold(ax, 'off');
            title(ax, 'Target Ia vs model fit');
            xlabel(ax, 'time (s)'); ylabel(ax, 'r (a.u.)');
            legend(ax, {'target (truth)','initial guess','optimized fit'}, 'Location', 'best', 'FontSize', 8);
            obj.padY(ax, [res.target(:); res.fit0(:); res.fitOpt(:)]);

            % Recovered gamma-static (chain) waveform + control points
            gT = res.gammaTrue; gO = res.gammaOpt;
            ax = obj.optAxGammaS; cla(ax);
            plot(ax, gT.t, gT.chainPca, '--', 'Color', grey, 'LineWidth', 1.5); hold(ax, 'on');
            plot(ax, gO.t, gO.chainPca, '-', 'Color', s.chain, 'LineWidth', 1.8);
            plot(ax, gT.controlTimes, gT.controlPca, 'o', 'MarkerSize', 7, ...
                'MarkerFaceColor', [0.6 0.6 0.6], 'MarkerEdgeColor', grey);
            plot(ax, gO.controlTimes, gO.controlPca, 'o', 'MarkerSize', 7, ...
                'Color', s.chain, 'MarkerFaceColor', s.chain);
            hold(ax, 'off'); set(ax, 'YDir', 'reverse');
            title(ax, 'Recovered \gamma-static (chain)');
            xlabel(ax, 'time (s)'); ylabel(ax, 'pCa');
            legend(ax, {'true','recovered','true CP','recovered CP'}, 'Location', 'best', 'FontSize', 8);

            % Recovered gamma-dynamic (bag burst)
            ax = obj.optAxGammaD; cla(ax);
            plot(ax, gT.t, gT.bagPca, '--', 'Color', grey, 'LineWidth', 1.5); hold(ax, 'on');
            plot(ax, gO.t, gO.bagPca, '-', 'Color', s.bag, 'LineWidth', 1.8);
            hold(ax, 'off'); set(ax, 'YDir', 'reverse');
            title(ax, 'Recovered \gamma-dynamic (bag burst)');
            xlabel(ax, 'time (s)'); ylabel(ax, 'pCa');
            legend(ax, {'true','recovered'}, 'Location', 'best', 'FontSize', 8);

            % Table (all fitted parameters)
            data = cell(numel(res.names), 5);
            for i = 1:numel(res.names)
                data{i,1} = res.labels{i};
                data{i,2} = round(res.xTrue(i), 3);
                data{i,3} = round(res.x0(i), 3);
                data{i,4} = round(res.xOpt(i), 3);
                data{i,5} = round(res.recoveryPct(i), 1);
            end
            obj.optTable.Data = data;
            obj.beautify(obj.optAxFit.Parent);
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
            cg = uigridlayout(cpanel, [9 1]);
            cg.RowHeight = {'fit','fit','fit','fit','fit','fit','fit','fit','1x'};
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

            obj.udFwdBtn = uibutton(cg, 'Text', 'Run forward  ->  firing', 'FontWeight', 'bold', ...
                'Enable', 'off', 'BackgroundColor', s.tagInput, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(src,e) obj.runUserForward());
            obj.udFwdBtn.Layout.Row = 5;
            obj.udOptBtn = uibutton(cg, 'Text', 'Optimize gamma  ->  drive', 'FontWeight', 'bold', ...
                'Enable', 'off', 'BackgroundColor', s.tagOutput, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(src,e) obj.runUserOptimize());
            obj.udOptBtn.Layout.Row = 6;

            obj.udSaveBtn = uibutton(cg, 'Text', 'Save results...', ...
                'Enable', 'off', 'BackgroundColor', [0.93 0.94 0.96], 'FontColor', s.navy, ...
                'ButtonPushedFcn', @(src,e) obj.saveUserRun());
            obj.udSaveBtn.Layout.Row = 7;
            obj.udSaveBtn.Tooltip = 'Write the last run to a .mat (everything) and a .csv (time series)';

            obj.udStatus = uilabel(cg, 'Text', 'Ready.', 'WordWrap', 'on', 'FontColor', s.muted);
            obj.udStatus.Layout.Row = 8;

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
            if d.availForward,  avail{end+1} = 'forward (->firing)'; end
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
            for i = 1:5, a(i).Visible = 'on'; end
            a(1).Parent.RowHeight = repmat({'1x'}, 1, 5);
            obj.axLength(a(1), out);
            obj.axActivation(a(2), out);
            obj.axForce(a(3), out);
            obj.axReceptor(a(4), out);
            obj.axFiring(a(5), out); xlabel(a(5), 'time (s)');
            % Overlay the user's own firing on the firing panel, if present.
            if isfield(out, 'targetFiring') && ~isempty(out.targetFiring)
                hold(a(5), 'on');
                plot(a(5), out.t, out.targetFiring, '--', 'Color', obj.S.muted, 'LineWidth', 1.6);
                hold(a(5), 'off');
            end
            obj.beautify(obj.udPlotPanel);
        end

        function runUserOptimize(obj)
            if isempty(obj.udData), return; end
            obj.setBusy(true); obj.udOptBtn.Enable = 'off'; obj.udFwdBtn.Enable = 'off';
            obj.udStatus.Text = 'Optimizing gamma to match your firing (~1-2 min)...'; drawnow;
            try
                % Run first (status-only live updates), THEN build + plot the
                % results synchronously so the axes lay out reliably.
                res = runOptFromData(obj.udData, struct('maxIter', 20, ...
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
            for i = 1:3, a(i).Visible = 'on'; end
            a(4).Visible = 'off'; a(5).Visible = 'off';   % optimize uses 3 panels
            a(1).Parent.RowHeight = {'1x','1x','1x', 0, 0}; % collapse the unused rows

            % Fit vs target firing
            axFit = a(1);
            plot(axFit, res.t, res.target, 'Color', obj.S.muted, 'LineWidth', obj.S.lw); hold(axFit, 'on');
            plot(axFit, res.t, res.fit0, '--', 'Color', obj.S.tagOutput, 'LineWidth', obj.S.lwThin);
            plot(axFit, res.t, res.fitOpt, 'Color', obj.S.green, 'LineWidth', obj.S.lw); hold(axFit, 'off');
            title(axFit, 'Your Ia firing vs model fit'); ylabel(axFit, 'firing (spikes/s)');
            legend(axFit, {'your firing','initial guess','optimized fit'}, 'Location', 'best');
            obj.padY(axFit, [res.target(:); res.fitOpt(:)]); xlim(axFit, [res.t(1) res.t(end)]);
            obj.tagAxes(axFit, 'output');

            % Recovered gamma drive (pCa)
            g = res.gammaOpt; axGamma = a(2);
            plot(axGamma, g.t, g.chainPca, 'Color', obj.S.chain, 'LineWidth', obj.S.lw); hold(axGamma, 'on');
            plot(axGamma, g.t, g.bagPca, 'Color', obj.S.bag, 'LineWidth', obj.S.lw); hold(axGamma, 'off');
            set(axGamma, 'YDir', 'reverse'); ylim(axGamma, [4.3 9.2]);
            title(axGamma, 'Recovered \gamma drive'); ylabel(axGamma, 'pCa');
            legend(axGamma, {'chain (\gamma-static)','bag (\gamma-dynamic)'}, 'Location', 'best');
            xlim(axGamma, [g.t(1) g.t(end)]); xlabel(axGamma, 'time (s)');
            obj.tagAxes(axGamma, 'input');

            % Cost vs iteration (from the recorded history)
            axCost = a(3);
            if ~isempty(res.history)
                plot(axCost, [res.history.iter], [res.history.fval], '-o', ...
                    'LineWidth', 1.8, 'Color', obj.S.accent);
            end
            title(axCost, 'Cost vs iteration'); xlabel(axCost, 'iteration');
            ylabel(axCost, 'RMSE (spikes/s)'); grid(axCost, 'on');

            obj.beautify(obj.udPlotPanel);
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
'<b>Forward:</b> length + activations &rarr; forces, receptor potential, firing.<br>', ...
'<b>Optimize:</b> length + your firing &rarr; the &gamma; drive that reproduces it.', ...
'</body></html>'];
        end
    end
end
