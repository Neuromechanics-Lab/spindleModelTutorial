classdef SpindleLearnApp < SpindleAppBase
% SpindleLearnApp  Interactive Tutorial (Learn) window for the spindle model.
%
%   Overview, Guided walkthrough, and Playground - for understanding the model
%   by exploring it. Open it with launchSpindleTutorialApp (or the launcher
%   menu). This window needs only the core matlabMuscleSpindleModellingTools
%   toolbox, so it is the one compiled into the standalone Learn app.
%
%   Every number it plots comes from the compute/ layer, which calls the real
%   toolbox functions. Shared styling/plot helpers live in SpindleAppBase.

    properties
        tabWalk
        tabPlay
        % Playground handles
        ctrl        = struct();   % parameter controls, keyed by sanitized name
        ctrlDefault = struct();   % their starting values (for the Reset button)
        ctrlCaption = struct();   % each slider's caption label + handle
        pgAxes      = struct();   % playground axes
        pgScrub                    % cross-bridge scrubber slider
        pgScrubLabel
        pgStatus
        pgLiveChk
        lastOut     = [];          % cached forward-sim output for the scrubber
        mtCache     = [];          % cached extrafusal MTU result (reused across runs)
        mtSig       = [];          % signature of params that produced mtCache
        distHandles = [];          % persistent area handles for the scrubber
        % Guided walkthrough handles
        gwPlotPanel
        gwText
        gwTitle
        gwStep      = 1;
        gwSteps     = {};
        gwProgress
        gwPrevBtn
        gwNextBtn
        gwOut       = [];          % cached walkthrough sim (preset is fixed)
    end

    methods
        function obj = SpindleLearnApp()
            obj.makeFigure('Muscle Spindle Model - Interactive Tutorial (Learn)');
            obj.gwSteps = obj.defineWalkthroughSteps();
            obj.buildOverviewTab(1);
            obj.buildWalkthroughTab(2);
            obj.buildPlaygroundTab(3);
            % The walkthrough and playground each run a full simulation; do that
            % lazily the first time their tab is opened so startup stays instant.
            obj.TabGroup.SelectionChangedFcn = @(s,e) obj.onTabChanged();
        end

        function onTabChanged(obj)
            sel = obj.TabGroup.SelectedTab;
            if sel == obj.tabWalk && isempty(obj.gwOut)
                obj.showWalkthroughStep(obj.gwStep);
            elseif sel == obj.tabPlay && isempty(obj.lastOut)
                obj.runPlayground();
            end
        end

        % ---- Overview ---------------------------------------------------
        function buildOverviewTab(obj, n)
            tab = uitab(obj.TabGroup, 'Title', sprintf('%d. Overview', n));
            g = uigridlayout(tab, [1 1]);
            h = uihtml(g);
            h.HTMLSource = obj.overviewHTML();
        end

        % ---- Guided walkthrough ----------------------------------------
        function buildWalkthroughTab(obj, n)
            s = obj.S;
            tab = uitab(obj.TabGroup, 'Title', sprintf('%d. Guided walkthrough', n), 'BackgroundColor', s.canvasDoc);
            obj.tabWalk = tab;
            g = uigridlayout(tab, [2 2]);
            g.RowHeight    = {'1x', 44};
            g.ColumnWidth  = {'1.05x', '1.25x'};
            g.Padding = [14 14 14 14]; g.ColumnSpacing = 14; g.RowSpacing = 10;
            g.BackgroundColor = s.canvasDoc;

            % Left: narrative (a clean card)
            txtPanel = uipanel(g, 'BorderType', 'line', 'BackgroundColor', s.canvasDoc);
            txtPanel.Layout.Row = 1; txtPanel.Layout.Column = 1;
            try
                txtPanel.BorderColor = s.cardEdge;
            catch
            end
            tg = uigridlayout(txtPanel, [2 1]);
            tg.RowHeight = {'fit', '1x'}; tg.Padding = [14 14 14 14]; tg.RowSpacing = 10;
            tg.BackgroundColor = s.canvasDoc;
            obj.gwTitle = uilabel(tg, 'Text', '', 'FontSize', 16, 'FontWeight', 'bold', ...
                'FontColor', s.navy, 'WordWrap', 'on');
            obj.gwText  = uitextarea(tg, 'Editable', 'off', 'FontSize', 13.5, ...
                'BackgroundColor', s.canvasDoc, 'FontColor', [0.15 0.15 0.18]);

            % Right: a plot panel rebuilt per step (variable number of stacked panels)
            obj.gwPlotPanel = uipanel(g, 'BorderType', 'none', 'BackgroundColor', s.canvasDoc);
            obj.gwPlotPanel.Layout.Row = 1; obj.gwPlotPanel.Layout.Column = 2;

            % Bottom: navigation
            nav = uigridlayout(g, [1 4]);
            nav.Layout.Row = 2; nav.Layout.Column = [1 2];
            nav.ColumnWidth = {110, '1x', 110, 130};
            nav.Padding = [0 0 0 0]; nav.BackgroundColor = s.canvasDoc;
            obj.gwPrevBtn = uibutton(nav, 'Text', '< Prev', 'FontWeight', 'bold', ...
                'BackgroundColor', [0.93 0.94 0.96], 'FontColor', s.navy, ...
                'ButtonPushedFcn', @(src,e) obj.walkStep(-1));
            obj.gwProgress = uilabel(nav, 'Text', '', 'HorizontalAlignment', 'center', ...
                'FontWeight', 'bold', 'FontColor', s.muted);
            obj.gwNextBtn = uibutton(nav, 'Text', 'Next >', 'FontWeight', 'bold', ...
                'BackgroundColor', s.accent, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(src,e) obj.walkStep(+1));
            uibutton(nav, 'Text', 'Go to Playground', ...
                'BackgroundColor', [0.93 0.94 0.96], 'FontColor', s.navy, ...
                'ButtonPushedFcn', @(src,e) obj.gotoPlayground());

            % Show the first step's text immediately (plots fill on first view).
            step1 = obj.gwSteps{1};
            obj.gwTitle.Text = sprintf('Step 1/%d:  %s', numel(obj.gwSteps), step1.title);
            obj.gwText.Value = [{'(Opening this tab runs a simulation - one moment...)'; ''}; step1.text(:)];
            obj.gwProgress.Text = sprintf('1 / %d', numel(obj.gwSteps));
        end

        function gotoPlayground(obj)
            obj.TabGroup.SelectedTab = obj.tabPlay;
            obj.onTabChanged();   % programmatic selection doesn't fire the callback
        end

        % ---- Playground -------------------------------------------------
        function buildPlaygroundTab(obj, n)
            tab = uitab(obj.TabGroup, 'Title', sprintf('%d. Playground', n), 'BackgroundColor', obj.S.canvasApp);
            obj.tabPlay = tab;
            g = uigridlayout(tab, [1 2]);
            g.ColumnWidth = {340, '1x'};
            g.Padding = [10 10 10 10]; g.ColumnSpacing = 10;
            g.BackgroundColor = obj.S.canvasApp;

            % --- Controls (scrollable) ---
            cpanel = obj.card(g, 'Parameters');
            cpanel.Layout.Column = 1;
            cg = uigridlayout(cpanel, [1 1]); cg.Padding = [4 4 4 4];
            cg.BackgroundColor = obj.S.card;
            nRows = 60;
            sc = uigridlayout(cg, [nRows 1]); sc.Scrollable = 'on';
            sc.RowHeight = repmat({'fit'}, 1, nRows);
            sc.BackgroundColor = obj.S.card;
            row = 1;

            % Run / reset / live-update row
            topRow = uigridlayout(sc, [1 3]); topRow.Layout.Row = row; row = row + 1;
            topRow.ColumnWidth = {'1.3x','0.9x','1x'}; topRow.Padding = [0 0 0 6];
            topRow.ColumnSpacing = 6;
            topRow.BackgroundColor = obj.S.card;
            uibutton(topRow, 'Text', 'Run simulation', 'FontWeight', 'bold', ...
                'BackgroundColor', obj.S.accent, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(s,e) obj.runPlayground());
            rb = uibutton(topRow, 'Text', 'Reset', ...
                'BackgroundColor', [0.93 0.94 0.96], 'FontColor', obj.S.navy, ...
                'ButtonPushedFcn', @(s,e) obj.resetPlayground());
            rb.Tooltip = 'Restore every parameter to its starting value';
            obj.pgLiveChk = uicheckbox(topRow, 'Text', 'Live update', 'Value', true);

            % Length protocol (drives the MTU)
            row = obj.addPanelHeader(sc, row, 'Length protocol (applied to the MTU)');
            obj.ctrl.protocol_type = obj.addDropdownRow(sc, row, 'Type', ...
                {'ramp-hold','sine','triangle'}, 'ramp-hold'); row = row + 1;
            row = obj.addSliderRow(sc, row, 'protocol_amplitude_pct', 'Amplitude (% L0)', 0, 12, 8);
            row = obj.addSliderRow(sc, row, 'protocol_perturbStart', 'Onset (s)', 0.1, 1.2, 0.3);
            row = obj.addSliderRow(sc, row, 'protocol_rampDur', 'Rise time (s) [ramp-hold & triangle]', 0.02, 1.5, 0.8);
            row = obj.addSliderRow(sc, row, 'protocol_freq', 'Frequency (Hz) [sine & triangle]', 0.5, 3, 1);

            % Extrafusal muscle-tendon unit
            row = obj.addPanelHeader(sc, row, 'Extrafusal MTU (\alpha drive + tendon)');
            row = obj.addSliderRow(sc, row, 'mtu_alphaLevel', '\alpha (extrafusal) activation (%)', 0, 100, 35);
            row = obj.addSliderRow(sc, row, 'mtu_tendonStiffness', 'Tendon stiffness', 1000, 20000, 5000);

            % Gamma drive - in % activation, matching the Activation plot
            row = obj.addPanelHeader(sc, row, 'Gamma drive  (% activation)');
            obj.ctrl.gamma_chainMode = obj.addDropdownRow(sc, row, '\gamma-static (chain) mode', ...
                {'constant','sine'}, 'constant'); row = row + 1;
            row = obj.addSliderRow(sc, row, 'gamma_chainOn', 'Chain onset (s)', 0.0, 1.5, 0.3);
            row = obj.addSliderRow(sc, row, 'gamma_chainLevel_pct', 'Chain activation (%) [sine: mean]', 0, 100, 50);
            row = obj.addSliderRow(sc, row, 'gamma_chainAmp_pct', 'Chain sine amplitude (%) [sine]', 0, 50, 20);
            row = obj.addSliderRow(sc, row, 'gamma_chain_freq', 'Chain sine frequency (Hz) [sine]', 0.25, 3, 1.0);
            row = obj.addSliderRow(sc, row, 'gamma_chainPhase_s', 'Chain sine phase (s after onset) [sine]', -1, 1, 0.0);
            row = obj.addSliderRow(sc, row, 'gamma_bagBurst_pct', 'Bag / \gamma-dynamic burst activation (%)', 0, 100, 90);
            row = obj.addSliderRow(sc, row, 'gamma_bagOn', 'Bag burst onset (s)', 0.1, 1.5, 0.3);
            row = obj.addSliderRow(sc, row, 'gamma_bagOff', 'Bag burst offset (s)', 0.4, 2.5, 1.1);

            % Fiber kinetics
            row = obj.addPanelHeader(sc, row, 'Fiber cross-bridge kinetics');
            row = obj.addSliderRow(sc, row, 'bag_f', 'Bag attach rate f', 100, 1200, 600);
            row = obj.addSliderRow(sc, row, 'bag_g', 'Bag detach rate g', 5, 400, 40);
            row = obj.addSliderRow(sc, row, 'chain_f', 'Chain attach rate f', 100, 1000, 400);
            row = obj.addSliderRow(sc, row, 'chain_g', 'Chain detach rate g', 50, 600, 300);
            row = obj.addSliderRow(sc, row, 'bag_k_passive', 'Bag passive stiffness', 10, 300, 90);
            row = obj.addSliderRow(sc, row, 'chain_k_passive', 'Chain passive stiffness', 50, 500, 250);

            % Transduction
            row = obj.addPanelHeader(sc, row, 'Ia transduction (force + yank -> Ia)');
            row = obj.addSliderRow(sc, row, 'trans_kFc', 'Static gain kFc', 0, 3, 0.6);
            row = obj.addSliderRow(sc, row, 'trans_kFb', 'Dynamic force gain kFb', 0, 3, 1.1);
            row = obj.addSliderRow(sc, row, 'trans_kYb', 'Yank gain kYb', 0, 1, 0.1);
            row = obj.addSliderRow(sc, row, 'trans_threshold', 'Firing threshold', 0, 2, 0);
            obj.ctrl.trans_occlusion = obj.addCheckboxRow(sc, row, 'Branch occlusion'); row = row + 1;

            % Sim time
            row = obj.addPanelHeader(sc, row, 'Simulation');
            row = obj.addSliderRow(sc, row, 'sim_tEnd', 'Duration (s)', 1, 4, 2.0);

            obj.pgStatus = uilabel(sc, 'Text', '', 'FontColor', [0.6 0 0]);
            obj.pgStatus.Layout.Row = row; row = row + 1; %#ok<NASGU>

            % Dropdowns that also toggle which sliders are relevant.
            obj.ctrl.protocol_type.ValueChangedFcn   = @(s,e) obj.onProtocolType();
            obj.ctrl.gamma_chainMode.ValueChangedFcn = @(s,e) obj.onChainMode();
            obj.updateProtocolEnable();
            obj.updateChainModeEnable();

            % --- Plots (each panel shows ONE variable type = one y-axis). Panels
            % are badged INPUT / INTERMEDIATE / OUTPUT to show the pipeline flow. ---
            ppanel = obj.card(g); ppanel.Layout.Column = 2;
            pg = uigridlayout(ppanel, [3 2]);
            pg.RowHeight = {'1x','1x','1x'}; pg.RowSpacing = 6; pg.ColumnSpacing = 10;
            pg.BackgroundColor = obj.S.card;
            obj.pgAxes.length     = uiaxes(pg); obj.pgAxes.length.Layout.Row = 1;     obj.pgAxes.length.Layout.Column = 1;
            obj.pgAxes.activation = uiaxes(pg); obj.pgAxes.activation.Layout.Row = 1;  obj.pgAxes.activation.Layout.Column = 2;
            obj.pgAxes.force      = uiaxes(pg); obj.pgAxes.force.Layout.Row  = 2;      obj.pgAxes.force.Layout.Column  = 1;
            obj.pgAxes.rp         = uiaxes(pg); obj.pgAxes.rp.Layout.Row     = 2;      obj.pgAxes.rp.Layout.Column     = 2;
            obj.pgAxes.firing     = uiaxes(pg); obj.pgAxes.firing.Layout.Row = 3;      obj.pgAxes.firing.Layout.Column = 1;

            % Cross-bridge distribution + scrubber in the bottom-right cell
            distBox = uigridlayout(pg, [2 1]); distBox.Layout.Row = 3; distBox.Layout.Column = 2;
            distBox.RowHeight = {'1x', 46}; distBox.RowSpacing = 2; distBox.Padding = [0 0 0 0];
            distBox.BackgroundColor = obj.S.card;
            obj.pgAxes.dist = uiaxes(distBox); obj.pgAxes.dist.Layout.Row = 1;
            scRow = uigridlayout(distBox, [2 1]); scRow.Layout.Row = 2;
            scRow.RowHeight = {16, 22}; scRow.RowSpacing = 0; scRow.Padding = [0 0 0 0];
            scRow.BackgroundColor = obj.S.card;
            obj.pgScrubLabel = uilabel(scRow, 'Text', ...
                'Cross-bridge distribution (drag to scrub through the simulation):', ...
                'FontColor', obj.S.muted, 'FontSize', 11);
            obj.pgScrub = uislider(scRow, 'Limits', [0 2.5], 'Value', 0.5, ...
                'MajorTicks', [], 'MinorTicks', [], ...
                'ValueChangingFcn', @(s,e) obj.updateDistPlot(e.Value));
        end

        % ================================================================
        %  SMALL UI HELPERS (playground controls)
        % ================================================================
        function row = addPanelHeader(obj, parent, row, txt)
            l = uilabel(parent, 'Text', upper(txt), 'FontWeight', 'bold', ...
                'FontSize', 11, 'FontColor', obj.S.navy);
            l.Layout.Row = row; row = row + 1;
        end

        function row = addSliderRow(obj, parent, row, key, label, lo, hi, val)
            % The starting value comes from defaultTutorialParams whenever that
            % struct has a matching field, so the sliders cannot drift away from
            % the compute layer's defaults (they had). `val` is only the fallback
            % - used by the kinetics sliders, whose params default to [] meaning
            % "keep the toolbox value", and so have no number to read.
            val = obj.paramDefault(key, val);
            rowGrid = uigridlayout(parent, [2 1]);
            rowGrid.Layout.Row = row; rowGrid.RowHeight = {18, 26};
            rowGrid.Padding = [0 0 0 2]; rowGrid.RowSpacing = 0;
            cap = uilabel(rowGrid, 'Text', sprintf('%s = %.4g', label, val), ...
                'FontSize', 12, 'FontColor', [0.2 0.2 0.24]);
            s = uislider(rowGrid, 'Limits', [lo hi], 'Value', val, ...
                'MajorTicks', [], 'MinorTicks', []);
            s.ValueChangingFcn = @(src,e) set(cap, 'Text', sprintf('%s = %.4g', label, e.Value));
            s.ValueChangedFcn  = @(src,e) obj.onParamChanged();
            obj.ctrl.(key) = s;
            % Remember the starting value + its caption so Reset can restore both.
            obj.ctrlDefault.(key) = val;
            obj.ctrlCaption.(key) = struct('label', label, 'handle', cap);
            row = row + 1;
        end

        function v = paramDefault(~, key, fallback)
            % Slider keys are '<group>_<field>', matching defaultTutorialParams'
            % nested layout (e.g. protocol_amplitude_pct -> p.protocol.amplitude_pct).
            persistent p
            if isempty(p), p = defaultTutorialParams(); end
            v = fallback;
            u = find(key == '_', 1);
            if isempty(u), return; end
            grp = key(1:u-1); fld = key(u+1:end);
            if isfield(p, grp) && isfield(p.(grp), fld) && ~isempty(p.(grp).(fld))
                v = p.(grp).(fld);
            end
        end

        function dd = addDropdownRow(obj, parent, row, label, items, val)
            rowGrid = uigridlayout(parent, [1 2]);
            rowGrid.Layout.Row = row; rowGrid.ColumnWidth = {'1x','1.2x'};
            rowGrid.Padding = [0 0 0 0];
            uilabel(rowGrid, 'Text', label, 'FontSize', 12);
            dd = uidropdown(rowGrid, 'Items', items, 'Value', val, ...
                'ValueChangedFcn', @(src,e) obj.onParamChanged());
        end

        function cb = addCheckboxRow(obj, parent, row, label)
            cb = uicheckbox(parent, 'Text', label, 'Value', false, ...
                'ValueChangedFcn', @(src,e) obj.onParamChanged());
            cb.Layout.Row = row;
        end

        function resetPlayground(obj)
            % Restore every control to the value it had when the tab was built,
            % then re-run once so the plots match the controls again.
            for f = fieldnames(obj.ctrlDefault)'
                key = f{1};
                obj.ctrl.(key).Value = obj.ctrlDefault.(key);
                % refresh the "label = value" caption next to the slider
                if isfield(obj.ctrlCaption, key)
                    c = obj.ctrlCaption.(key);
                    if isgraphics(c.handle)
                        c.handle.Text = sprintf('%s = %.4g', c.label, obj.ctrlDefault.(key));
                    end
                end
            end
            % Non-slider controls
            obj.ctrl.protocol_type.Value   = 'ramp-hold';
            obj.ctrl.gamma_chainMode.Value = 'constant';
            obj.ctrl.trans_occlusion.Value = false;
            obj.updateProtocolEnable();
            obj.updateChainModeEnable();
            obj.runPlayground();
        end

        % ================================================================
        %  PLAYGROUND LOGIC
        % ================================================================
        function onParamChanged(obj)
            if obj.pgLiveChk.Value
                obj.runPlayground();
            end
        end

        function onProtocolType(obj)
            obj.updateProtocolEnable();
            obj.onParamChanged();
        end

        function onChainMode(obj)
            obj.updateChainModeEnable();
            obj.onParamChanged();
        end

        function updateProtocolEnable(obj)
            % Rise time applies to ramp-hold & triangle; frequency to sine & triangle.
            switch obj.ctrl.protocol_type.Value
                case 'ramp-hold', ramp = true;  freq = false;
                case 'sine',      ramp = false; freq = true;
                case 'triangle',  ramp = true;  freq = true;
                otherwise,        ramp = true;  freq = true;
            end
            obj.setEnable(obj.ctrl.protocol_rampDur, ramp);
            obj.setEnable(obj.ctrl.protocol_freq, freq);
        end

        function updateChainModeEnable(obj)
            isSine = strcmp(obj.ctrl.gamma_chainMode.Value, 'sine');
            obj.setEnable(obj.ctrl.gamma_chainAmp_pct, isSine);
            obj.setEnable(obj.ctrl.gamma_chain_freq, isSine);
            obj.setEnable(obj.ctrl.gamma_chainPhase_s, isSine);
        end

        function p = gatherParams(obj)
            p = defaultTutorialParams();
            p.protocol.type          = obj.ctrl.protocol_type.Value;
            p.protocol.amplitude_pct = obj.ctrl.protocol_amplitude_pct.Value;
            p.protocol.perturbStart  = obj.ctrl.protocol_perturbStart.Value;
            p.protocol.rampDur       = obj.ctrl.protocol_rampDur.Value;
            p.protocol.freq          = obj.ctrl.protocol_freq.Value;

            p.mtu.alphaLevel      = obj.ctrl.mtu_alphaLevel.Value;
            p.mtu.tendonStiffness = obj.ctrl.mtu_tendonStiffness.Value;

            p.gamma.chainMode      = obj.ctrl.gamma_chainMode.Value;
            p.gamma.chainOn        = obj.ctrl.gamma_chainOn.Value;
            p.gamma.chainLevel_pct = obj.ctrl.gamma_chainLevel_pct.Value;
            p.gamma.chainAmp_pct   = obj.ctrl.gamma_chainAmp_pct.Value;
            p.gamma.chain_freq     = obj.ctrl.gamma_chain_freq.Value;
            p.gamma.chainPhase_s   = obj.ctrl.gamma_chainPhase_s.Value;
            p.gamma.bagBurst_pct   = obj.ctrl.gamma_bagBurst_pct.Value;
            p.gamma.bagOn          = obj.ctrl.gamma_bagOn.Value;
            p.gamma.bagOff         = obj.ctrl.gamma_bagOff.Value;

            p.bag.f         = obj.ctrl.bag_f.Value;
            p.bag.g         = obj.ctrl.bag_g.Value;
            p.bag.k_passive = obj.ctrl.bag_k_passive.Value;
            p.chain.f         = obj.ctrl.chain_f.Value;
            p.chain.g         = obj.ctrl.chain_g.Value;
            p.chain.k_passive = obj.ctrl.chain_k_passive.Value;

            p.trans.kFc       = obj.ctrl.trans_kFc.Value;
            p.trans.kFb       = obj.ctrl.trans_kFb.Value;
            p.trans.kYb       = obj.ctrl.trans_kYb.Value;
            p.trans.threshold = obj.ctrl.trans_threshold.Value;
            p.trans.occlusion = obj.ctrl.trans_occlusion.Value;

            p.sim.tEnd = obj.ctrl.sim_tEnd.Value;
        end

        function sig = mtuSignature(~, p)
            % Fields that determine the extrafusal MTU result. If unchanged, the
            % (expensive) MTU can be reused across runs.
            sig = {p.sim.dt, p.sim.tEnd, p.protocol.type, p.protocol.L0, ...
                   p.protocol.amplitude_pct, p.protocol.perturbStart, ...
                   p.protocol.rampDur, p.protocol.freq, p.mtu.enabled, ...
                   p.mtu.tendonStiffness, p.mtu.alphaMode, p.mtu.alphaLevel, ...
                   p.mtu.alphaAmp, p.mtu.alphaFreq, p.mtu.alphaPhase};
        end

        function runPlayground(obj)
            obj.setBusy(true);
            try
                p = obj.gatherParams();
                % Reuse the cached MTU unless a length/MTU parameter changed.
                sig = obj.mtuSignature(p);
                if ~isempty(obj.mtCache) && isequal(sig, obj.mtSig)
                    obj.pgStatus.Text = 'Running (MTU cached)...'; drawnow;
                    out = tutorialForwardSim(p, obj.mtCache);
                else
                    obj.pgStatus.Text = 'Running MTU + fibers...'; drawnow;
                    out = tutorialForwardSim(p);
                    obj.mtCache = out.mt;
                    obj.mtSig   = sig;
                end
                obj.lastOut = out;
                obj.plotPlayground(out);
                obj.pgScrub.Limits = [out.t(1) out.t(end)];
                if obj.pgScrub.Value < out.t(1) || obj.pgScrub.Value > out.t(end)
                    obj.pgScrub.Value = out.t(1) + 0.4 * (out.t(end) - out.t(1));
                end
                obj.distHandles = [];   % force a rebuild for the new sim
                obj.updateDistPlot(obj.pgScrub.Value);
                if out.mt.ok
                    obj.pgStatus.Text = '';
                else
                    obj.pgStatus.Text = out.mt.message;
                end
            catch ME
                obj.pgStatus.Text = ['Error: ' ME.message];
            end
            obj.setBusy(false);
        end

        function plotPlayground(obj, out)
            cla(obj.pgAxes.length);     obj.axLength(obj.pgAxes.length, out);
            cla(obj.pgAxes.activation); obj.axActivation(obj.pgAxes.activation, out);
            cla(obj.pgAxes.force);      obj.axForce(obj.pgAxes.force, out);      xlabel(obj.pgAxes.force, 'time (s)');
            cla(obj.pgAxes.rp);         obj.axReceptor(obj.pgAxes.rp, out);      xlabel(obj.pgAxes.rp, 'time (s)');
            cla(obj.pgAxes.firing);     obj.axFiring(obj.pgAxes.firing, out);    xlabel(obj.pgAxes.firing, 'time (s)');
            obj.beautify(obj.pgAxes.length.Parent);
        end

        function updateDistPlot(obj, tScrub)
            % Update the cross-bridge distribution. Called live from the scrubber's
            % ValueChangingFcn, so it updates YData of persistent patches (fast)
            % instead of redrawing the whole axes each time.
            if isempty(obj.lastOut), return; end
            out = obj.lastOut;
            [~, idx] = min(abs(out.t - tScrub));
            ax = obj.pgAxes.dist;
            yB = out.bag.bin_pops(:, idx);
            yC = out.chain.bin_pops(:, idx);

            s = obj.S;
            if isempty(obj.distHandles) || ~all(isgraphics(obj.distHandles))
                cla(ax);
                hB = area(ax, out.x_bins, yB, 'FaceColor', s.bag, ...
                    'FaceAlpha', 0.45, 'EdgeColor', s.bag, 'LineWidth', 1.2);
                hold(ax, 'on');
                hC = area(ax, out.x_bins, yC, 'FaceColor', s.chain, ...
                    'FaceAlpha', 0.45, 'EdgeColor', s.chain, 'LineWidth', 1.2);
                xline(ax, 0, ':', 'Color', s.muted);
                hold(ax, 'off');
                xlabel(ax, 'cross-bridge strain x (nm)'); ylabel(ax, 'bound fraction');
                legend(ax, {'bag','chain'}, 'Location', 'best', 'FontSize', 8);
                obj.distHandles = [hB hC];
                obj.beautify(ax.Parent);
                obj.tagAxes(ax, 'intermediate');
            else
                obj.distHandles(1).YData = yB;
                obj.distHandles(2).YData = yC;
            end
            ymax = max([yB; yC; 1e-3]);
            ylim(ax, [0 1.1 * ymax]);
            title(ax, sprintf('Cross-bridge distribution @ t = %.3f s', out.t(idx)), 'Color', s.navy);
            obj.pgScrubLabel.Text = sprintf('Cross-bridge distribution time = %.3f s (drag to scrub)', out.t(idx));
        end

        % ================================================================
        %  GUIDED WALKTHROUGH LOGIC
        % ================================================================
        function steps = defineWalkthroughSteps(~)
            steps = {};
            steps{end+1} = struct('kind', 'forces', ...
                'title', 'Inputs to the model: length and activation', ...
                'text', {{'The model has two kinds of INPUT (green badges): the LENGTH applied to the', ...
                'muscle-tendon unit (top panel) and the ACTIVATION of the muscle fibers (middle', ...
                'panel). We apply a slow ramp-and-hold stretch; the fascicle length it produces is', ...
                'what the spindle fibers actually feel.', '', ...
                'Three activations drive the model: alpha (the extrafusal muscle), and the two', ...
                'fusimotor drives - chain (gamma-static) and bag (gamma-dynamic). Activation is shown', ...
                'as % of maximum (the model works internally in pCa).', '', ...
                'Each intrafusal fiber then resists the stretch with a FORCE (bottom panel). The BAG', ...
                'fiber (orange) gives a large, transient force at the moment of stretch - it is', ...
                'sensitive to how FAST length changes - while the CHAIN fiber (blue) holds a steadier', ...
                'force that tracks how MUCH it is stretched.'}});
            steps{end+1} = struct('kind', 'distribution', ...
                'title', 'Where force comes from: the cross-bridge distribution', ...
                'text', {{'Active force is the sum, over all attached myosin heads, of each head''s strain.', ...
                'The model tracks the DISTRIBUTION of bound cross-bridges across strain x. The three', ...
                'snapshots (bottom) show the bag-fiber distribution at:', '', ...
                '  - PRE-stretch: a modest population centred near x = 0.', ...
                '  - EARLY stretch: the whole distribution is dragged to positive x (force rises fast).', ...
                '  - POST-stretch (hold): kinetics relax it toward a new steady state (force adapts).', '', ...
                'Stretch SHIFTS the distribution; attachment/detachment kinetics bring it back.'}});
            steps{end+1} = struct('kind', 'receptor', ...
                'title', 'From fiber force (and yank) to the receptor potential', ...
                'text', {{'The Ia afferent wraps around the fibers and senses their force. The model converts', ...
                'force into a receptor potential r with two components:', '', ...
                '  r_s (static, blue)    = gain x CHAIN force', ...
                '  r_d (dynamic, orange) = gain x BAG force  +  gain x BAG YANK', '', ...
                '"YANK" is the time-derivative of force, dF/dt (third panel). The bag force rises', ...
                'sharply during the ramp, so its yank SPIKES - and that spike drives the big transient', ...
                'in r_d.', '', ...
                'Total r = r_s + r_d (black, bottom panel).'}});
            steps{end+1} = struct('kind', 'firing', ...
                'title', 'From receptor potential to firing', ...
                'text', {{'The receptor potential is turned into afferent SPIKES by an integrate-and-fire', ...
                'process (integrateAndFire): r is integrated over time, and a spike is emitted each', ...
                'time the integral crosses threshold.', '', ...
                'The top panel is the receptor potential r; the bottom panel is the predicted Ia', ...
                'firing (instantaneous firing rate). Notice the burst of firing at stretch onset,', ...
                'driven by the yank-dominated r_d, followed by a maintained rate set by r_s.', '', ...
                'This firing is what a recording electrode on the Ia afferent would measure.'}});
            steps{end+1} = struct('kind', 'summary', ...
                'title', 'Putting it together', ...
                'text', {{'You have now seen the whole pipeline, top to bottom:', '', ...
                '   INPUTS: length + activation  ->  bag & chain forces  ->  receptor potential', ...
                '        (r_s + r_d)  ->  OUTPUT: predicted Ia firing.', '', ...
                'Head to the PLAYGROUND to change any parameter - the stretch, the extrafusal muscle', ...
                'and tendon, the gamma drive, the fiber kinetics, the transduction gains - and watch', ...
                'all of these update, with a scrubber to step the cross-bridge distribution through', ...
                'time. To fit the model to data, open the ANALYSIS TOOLKIT window (Gamma optimization', ...
                '+ Your data) from the launcher.'}});
        end

        function p = walkthroughPreset(~)
            % A single, clear preset for the whole tour. Gamma turns on BEFORE the
            % stretch, so there is an activated-but-unstretched baseline to show as
            % the "pre-stretch" cross-bridge distribution.
            p = defaultTutorialParams();
            p.sim.tEnd              = 2.4;
            p.protocol.type         = 'ramp-hold';
            p.protocol.amplitude_pct = 8;
            p.protocol.perturbStart = 0.6;
            p.protocol.rampDur      = 1.0;
            p.gamma.bagBurst_pct    = 92;    % % activation
            p.gamma.bagOn           = 0.2;
            p.gamma.bagOff          = 2.3;
            p.gamma.chainLevel_pct  = 50;
            p.gamma.chainOn         = 0.2;
        end

        function walkStep(obj, delta)
            newStep = min(max(obj.gwStep + delta, 1), numel(obj.gwSteps));
            obj.showWalkthroughStep(newStep);
        end

        function showWalkthroughStep(obj, k)
            obj.gwStep = k;
            step = obj.gwSteps{k};
            obj.gwTitle.Text = sprintf('Step %d/%d:  %s', k, numel(obj.gwSteps), step.title);
            obj.gwText.Value = step.text;
            obj.gwProgress.Text = sprintf('%d / %d', k, numel(obj.gwSteps));
            % Grey out navigation at the ends of the tour.
            obj.setEnable(obj.gwPrevBtn, k > 1);
            obj.setEnable(obj.gwNextBtn, k < numel(obj.gwSteps));

            % The preset is the same for every step, so simulate once and reuse.
            if isempty(obj.gwOut)
                obj.setBusy(true); drawnow;
                obj.gwOut = tutorialForwardSim(obj.walkthroughPreset());
                obj.setBusy(false);
            end
            out = obj.gwOut;

            delete(obj.gwPlotPanel.Children);   % rebuild the plot area for this step
            drawnow;   % ensure the plot panel has its final size before we lay axes into it
            switch step.kind
                case 'forces',       obj.renderWalkForces(out);
                case 'distribution', obj.renderWalkDistribution(out);
                case 'receptor',     obj.renderWalkReceptor(out);
                case 'firing',       obj.renderWalkFiring(out);
                case 'summary',      obj.renderWalkSummary(out);
            end
        end

        function grid = walkGrid(obj, nRows)
            grid = uigridlayout(obj.gwPlotPanel, [nRows 1]);
            grid.RowHeight = repmat({'1x'}, 1, nRows);
            grid.ColumnWidth = {'1x'};
            grid.Padding = [4 4 4 4]; grid.RowSpacing = 8;
            grid.BackgroundColor = obj.S.canvasDoc;
        end

        function renderWalkForces(obj, out)
            grid = obj.walkGrid(3);
            obj.axLength(obj.axInGrid(grid, 1), out);
            obj.axActivation(obj.axInGrid(grid, 2), out);
            ax = obj.axInGrid(grid, 3); obj.axForce(ax, out); xlabel(ax, 'time (s)');
            obj.beautify(obj.gwPlotPanel);
        end

        function renderWalkDistribution(obj, out)
            s = obj.S;
            grid = uigridlayout(obj.gwPlotPanel, [3 3]);
            grid.Padding = [4 4 4 4]; grid.RowSpacing = 8;
            grid.RowHeight = {'1x','1x','1.15x'};

            axL = uiaxes(grid); axL.Layout.Row = 1; axL.Layout.Column = [1 3]; obj.axLength(axL, out);
            axF = uiaxes(grid); axF.Layout.Row = 2; axF.Layout.Column = [1 3]; obj.axForce(axF, out);
            xlabel(axF, 'time (s)');

            % Snapshot times: pre-stretch, early stretch (peak bag yank), hold.
            dt = out.t(2) - out.t(1);
            yank = [0, diff(out.bag.hs_force) / dt];
            pStart = out.params.protocol.perturbStart;
            preIdx = find(out.t >= pStart - 0.05, 1, 'first');
            if isempty(preIdx), preIdx = 1; end
            % "Early stretch" = just after stretch onset. (max(yank) alone can land
            % on the gamma-dynamic activation transient, which precedes the stretch.)
            earlyIdx = find(out.t >= pStart + 0.04, 1, 'first');
            if isempty(earlyIdx), [~, earlyIdx] = max(yank); end
            postIdx = numel(out.t);
            idxs = [preIdx earlyIdx postIdx];
            tags = {'pre','early','post'};
            labels = {'pre-stretch','early stretch','post-stretch (hold)'};

            % Color-coded cursors on length & force panels mark each snapshot time.
            for c = 1:3
                for ax = [axL axF]
                    xl = xline(ax, out.t(idxs(c)), '-', tags{c}, 'Color', s.snap(c,:), ...
                        'LineWidth', 1.4, 'FontSize', 8, ...
                        'LabelVerticalAlignment', 'top', 'LabelHorizontalAlignment', 'center');
                    xl.Annotation.LegendInformation.IconDisplayStyle = 'off';  % keep out of legend
                end
            end

            ymax = max([out.bag.bin_pops(:); out.chain.bin_pops(:); 1e-3]);
            snapAxes = gobjects(1,3);
            for c = 1:3
                ax = uiaxes(grid); ax.Layout.Row = 3; ax.Layout.Column = c;
                snapAxes(c) = ax; idx = idxs(c);
                area(ax, out.x_bins, out.bag.bin_pops(:, idx), 'FaceColor', s.bag, ...
                    'FaceAlpha', 0.45, 'EdgeColor', s.bag, 'LineWidth', 1.1); hold(ax, 'on');
                area(ax, out.x_bins, out.chain.bin_pops(:, idx), 'FaceColor', s.chain, ...
                    'FaceAlpha', 0.45, 'EdgeColor', s.chain, 'LineWidth', 1.1);
                xline(ax, 0, ':', 'Color', s.muted); hold(ax, 'off');
                ylim(ax, [0 1.1 * ymax]);
                title(ax, sprintf('%s (t=%.2fs)', labels{c}, out.t(idx)));
                xlabel(ax, 'strain x (nm)');
                if c == 1, ylabel(ax, 'bound fraction'); end
            end

            obj.beautify(obj.gwPlotPanel);
            % Re-color the snapshot titles + frames to match their cursor (after
            % beautify, which would otherwise force every title to navy).
            for c = 1:3
                snapAxes(c).Title.Color = s.snap(c,:);
                snapAxes(c).XColor = s.snap(c,:); snapAxes(c).YColor = s.snap(c,:);
            end
        end

        function renderWalkReceptor(obj, out)
            grid = obj.walkGrid(4);
            obj.axLength(obj.axInGrid(grid, 1), out);
            obj.axForce(obj.axInGrid(grid, 2), out);
            % Yank (dF/dt) of the bag fiber
            dt = out.t(2) - out.t(1);
            yank = [0, diff(out.bag.hs_force) / dt];
            ax = obj.axInGrid(grid, 3);
            area(ax, out.t, yank, 'FaceColor', obj.S.yank, 'FaceAlpha', 0.18, ...
                'EdgeColor', obj.S.yank, 'LineWidth', 1.3);
            yline(ax, 0, ':', 'Color', obj.S.muted);
            ylabel(ax, 'dF/dt'); title(ax, 'Bag yank (dF/dt) - drives the dynamic response');
            obj.padY(ax, yank); xlim(ax, [out.t(1) out.t(end)]);
            ax = obj.axInGrid(grid, 4); obj.axReceptor(ax, out); xlabel(ax, 'time (s)');
            obj.beautify(obj.gwPlotPanel);
        end

        function renderWalkFiring(obj, out)
            grid = obj.walkGrid(2);
            obj.axReceptor(obj.axInGrid(grid, 1), out);
            ax = obj.axInGrid(grid, 2); obj.axFiring(ax, out);
            xlabel(ax, 'time (s)');
            obj.beautify(obj.gwPlotPanel);
        end

        function renderWalkSummary(obj, out)
            grid = obj.walkGrid(5);
            obj.axLength(obj.axInGrid(grid, 1), out);
            obj.axActivation(obj.axInGrid(grid, 2), out);
            obj.axForce(obj.axInGrid(grid, 3), out);
            obj.axReceptor(obj.axInGrid(grid, 4), out);
            ax = obj.axInGrid(grid, 5); obj.axFiring(ax, out);
            xlabel(ax, 'time (s)');
            obj.beautify(obj.gwPlotPanel);
        end
    end

    methods (Static)
        function s = overviewHTML()
            fig = SpindleAppBase.imgTag('spindleModelFig.png', ...
                'display:block;max-width:660px;width:100%;height:auto;margin:12px auto;border:1px solid #d6e0ee;border-radius:8px;');
            s = [ ...
'<html><head><style>', ...
'body{font-family:-apple-system,"Segoe UI",Helvetica,Arial,sans-serif;color:#222;margin:24px;line-height:1.5;}', ...
'h1{color:#1b4a7a;font-size:22px;margin-bottom:2px;} h2{color:#1b4a7a;font-size:16px;margin-top:22px;}', ...
'.sub{color:#666;margin-top:0;} .box{background:#f4f7fb;border:1px solid #d6e0ee;border-radius:8px;padding:10px 14px;margin:8px 0;}', ...
'.pipe{display:flex;align-items:center;flex-wrap:wrap;gap:6px;font-size:13px;margin:10px 0;}', ...
'.stage{background:#1b4a7a;color:#fff;border-radius:6px;padding:8px 12px;font-weight:600;}', ...
'.arrow{color:#1b4a7a;font-size:20px;font-weight:700;} code{background:#eef;padding:1px 4px;border-radius:3px;}', ...
'ul{margin-top:4px;}</style></head><body>', ...
'<h1>The Muscle Spindle Model &mdash; Interactive Tutorial</h1>', ...
'<p class="sub">A hands-on tour of the biophysical, cross-bridge-based muscle spindle model.</p>', ...
'<div class="box">A muscle spindle is a stretch sensor embedded in muscle. This model predicts its ', ...
'Ia afferent signal: a length change applied to the <b>extrafusal muscle-tendon unit</b> (driven by ', ...
'&alpha; motor neurons, in series with a compliant tendon) sets the <b>fascicle length</b> that the ', ...
'<b>intrafusal fibers</b> inherit. Fusimotor (&gamma;) drive plus that length act on the fibers, whose ', ...
'<b>cross-bridges</b> generate force; that force (plus its rate of change, &ldquo;yank&rdquo;) is ', ...
'transduced into the afferent&rsquo;s receptor potential.</div>', ...
'<h2>The biophysical model</h2>', ...
fig, ...
'<h2>The pipeline (at a glance)</h2>', ...
'<div class="pipe">', ...
'<span class="stage">length&nbsp;+&nbsp;&alpha;<br>(extrafusal MTU)</span><span class="arrow">&rarr;</span>', ...
'<span class="stage">fascicle<br>length</span><span class="arrow">&rarr;</span>', ...
'<span class="stage">+&nbsp;&gamma; drive:<br>bag &amp; chain forces</span><span class="arrow">&rarr;</span>', ...
'<span class="stage">receptor<br>potential r</span><span class="arrow">&rarr;</span>', ...
'<span class="stage">Ia firing</span></div>', ...
'<h2>Two fibers, two roles</h2>', ...
'<ul><li><b>Bag fiber</b> (driven by &gamma;-dynamic): fast kinetics &rarr; large transient force and ', ...
'<b>yank</b> &rarr; the velocity-sensitive <i>dynamic</i> response.</li>', ...
'<li><b>Chain fiber</b> (driven by &gamma;-static): steadier force &rarr; the length-sensitive ', ...
'<i>static</i> response.</li></ul>', ...
'<h2>This window: learn the model</h2>', ...
'<ul>', ...
'<li><b>Guided walkthrough</b> &mdash; a narrated, five-step tour: inputs (length + activation) &rarr; ', ...
'cross-bridge distribution &rarr; receptor potential + yank &rarr; firing &rarr; the whole model.</li>', ...
'<li><b>Playground</b> &mdash; move any parameter (stretch, extrafusal &alpha; + tendon, &gamma; drive, ', ...
'fiber kinetics, transduction) and watch activation, fiber forces, the receptor potential, firing, and the ', ...
'cross-bridge distribution update. Drag the scrubber to step through the distribution in time.</li>', ...
'</ul>', ...
'<h2>The Analysis Toolkit (separate window)</h2>', ...
'<div class="box">Fitting the model to data lives in its own <b>Analysis Toolkit</b> window (open it from the ', ...
'launcher, or run <code>launchSpindleToolkit</code>):', ...
'<ul>', ...
'<li><b>Gamma optimization</b> &mdash; recover a known &gamma;-static B-spline drive from a simulated Ia ', ...
'(the workflow behind <code>gammaDriveOptimization</code>).</li>', ...
'<li><b>Your data</b> &mdash; run the model on your OWN inputs: length + activations &rarr; firing, or ', ...
'length + recorded Ia firing &rarr; the &gamma; drive that reproduces it.</li>', ...
'</ul></div>', ...
'<div class="box"><b>Under the hood:</b> the code generating everything here is the biophysical ', ...
'muscle spindle model from ', ...
'<a href="https://doi.org/10.64898/2026.07.03.736206">Simha et al. (2026, bioRxiv)</a>.</div>', ...
'<h2>References</h2>', ...
'<ul style="font-size:13px;">', ...
'<li>Simha SN, Ting LH (2024). Intrafusal cross-bridge dynamics shape history-dependent muscle ', ...
'spindle responses to stretch. <i>Experimental Physiology</i> 109(1):112&ndash;124. ', ...
'doi:<a href="https://doi.org/10.1113/EP090767">10.1113/EP090767</a></li>', ...
'<li>Simha S, Sawicki G, Cope T, Ting L (2026). The mammalian muscle spindle as a tunable ', ...
'feedback controller in locomotion. <i>bioRxiv</i> 2026.07.03.736206 (preprint). ', ...
'doi:<a href="https://doi.org/10.64898/2026.07.03.736206">10.64898/2026.07.03.736206</a></li>', ...
'<li>Blum KP, Campbell KS, Horslen BC, Nardelli P, Housley SN, Cope TC, Ting LH (2020). ', ...
'Diverse and complex muscle spindle afferent firing properties emerge from multiscale muscle ', ...
'mechanics. <i>eLife</i> 9:e55177. doi:<a href="https://doi.org/10.7554/eLife.55177">10.7554/eLife.55177</a></li>', ...
'</ul>', ...
'</body></html>'];
        end
    end
end
