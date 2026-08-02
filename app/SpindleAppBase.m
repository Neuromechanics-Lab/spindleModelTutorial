classdef SpindleAppBase < handle
% SpindleAppBase  Shared infrastructure for the muscle spindle model apps.
%
%   Base class for SpindleLearnApp (the Interactive Tutorial) and
%   SpindleToolkitApp (the Analysis Toolkit). It holds the pieces both windows
%   share: the figure/tab scaffolding, the palette + styling helpers, and the
%   per-signal plot helpers (length, activation, force, receptor potential,
%   firing). Keeping these here lets the two apps stay visually identical while
%   each bundles only its own tabs (so the compiled Learn app stays minimal).

    properties
        S            % shared style/palette struct (see sty())
        UIFigure
        TabGroup
    end

    properties (Access = private)
        inResize = false;   % re-entrancy guard for onFigureResized
    end

    methods
        function makeFigure(obj, name)
            % Create the app window + tab group, and load the shared palette.
            obj.S = SpindleAppBase.sty();
            obj.UIFigure = uifigure('Name', name, ...
                'Position', [80 80 1240 820], 'Color', [1 1 1]);
            outer = uigridlayout(obj.UIFigure, [1 1]);
            outer.Padding = [6 6 6 6];
            obj.TabGroup = uitabgroup(outer);
            % Panels follow the window when it is resized, but a uiaxes inside
            % one does not always follow with them - maximising leaves the axes
            % at its old size, so it overflows its panel and the title and top of
            % the plot box are cut off. Re-fit every axes whenever the window
            % changes size.
            % A LISTENER, not SizeChangedFcn: that callback is silently ignored
            % while AutoResizeChildren is 'on' (MATLAB warns and never calls it),
            % and turning AutoResizeChildren off would break the grid layout that
            % does the actual resizing. The event fires either way.
            addlistener(obj.UIFigure, 'SizeChanged', @(~,~) obj.onFigureResized());
        end

        function onFigureResized(obj)
            % Re-assert "axes exactly fills its panel" for every axes in the
            % window. Guarded against re-entry: fillPanel toggles the axes units
            % to force a layout pass, and we must not have that re-trigger us.
            if obj.inResize, return; end
            obj.inResize = true;
            try
                axl = findobj(obj.UIFigure, 'Type', 'axes');
                for i = 1:numel(axl)
                    if isa(axl(i).Parent, 'matlab.ui.container.Panel')
                        SpindleAppBase.fillPanel(axl(i).Parent, axl(i));
                    end
                end
            catch
                % Layout polish only - never let it break the window.
            end
            obj.inResize = false;
        end

        % ================================================================
        %  SHARED STYLING
        % ================================================================
        function beautify(obj, container)
            % Apply consistent styling to every axes under a container: unified
            % font, light gridlines, navy titles, clean (box-off) frame, and
            % tidy legends. Called at the end of each plotting routine so the
            % whole app reads as one coherent figure system.
            s = obj.S;
            axl = findobj(container, 'Type', 'axes');
            for i = 1:numel(axl)
                ax = axl(i);
                try %#ok<TRYNC>
                    set(ax, 'FontName', s.font, 'FontSize', 10, 'Box', 'off', ...
                        'Layer', 'top', 'Color', 'none', ...
                        'XColor', s.axisTxt, 'YColor', s.axisTxt, ...
                        'GridColor', s.grid, 'GridAlpha', 1, ...
                        'TitleFontWeight', 'bold');
                    grid(ax, 'on');
                    if ~isempty(ax.Title)
                        ax.Title.Color = s.navy;
                        ax.Title.FontSize = 11;
                    end
                    ax.XLabel.Color = s.axisTxt;
                    ax.YLabel.Color = s.axisTxt;
                    lg = ax.Legend;
                    if ~isempty(lg)
                        lg.Box = 'off'; lg.FontSize = s.legendFont; lg.TextColor = s.axisTxt;
                        % A legend inside a uigridlayout becomes an extra grid
                        % child. It usually reports a plain LayoutOptions (no
                        % Row/Column), so it cannot be pinned - hence the isa
                        % guard, and hence: never mix uiaxes and other widgets
                        % in one grid, give the axes a grid of their own.
                        if isa(ax.Parent, 'matlab.ui.container.GridLayout') && ...
                           isa(lg.Layout, 'matlab.ui.layout.GridLayoutOptions')
                            lg.Layout.Row = ax.Layout.Row;
                            lg.Layout.Column = ax.Layout.Column;
                        end
                    end
                end
            end
        end

        function tagAxes(obj, ax, kind)
            % Draw a small colored badge in the top-left of an axes marking it as
            % an INPUT, INTERMEDIATE, or OUTPUT of the model pipeline.
            s = obj.S;
            switch lower(kind)
                case 'input',        c = s.tagInput;  txt = ' INPUT ';
                case 'output',       c = s.tagOutput; txt = ' OUTPUT ';
                otherwise,           c = s.tagInter;  txt = ' INTERMEDIATE ';
            end
            text(ax, 0.015, 0.97, txt, 'Units', 'normalized', ...
                'FontSize', 7.5, 'FontWeight', 'bold', 'Color', [1 1 1], ...
                'BackgroundColor', c, 'Margin', 1, ...
                'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
                'Clipping', 'off');
        end

        function pnl = card(obj, parent, titleStr)
            % A white "card" panel for the app-style tabs.
            s = obj.S;
            if nargin < 3, titleStr = ''; end
            pnl = uipanel(parent, 'BackgroundColor', s.card, ...
                'BorderType', 'line', 'ForegroundColor', s.navy, ...
                'FontWeight', 'bold', 'Title', titleStr);
            try
                pnl.BorderColor = s.cardEdge;
            catch
            end
        end

        function padY(~, ax, data)
            % Set y-limits ~8% beyond the data so traces do not sit on the edge.
            data = data(isfinite(data));
            if isempty(data), return; end
            lo = min(data); hi = max(data);
            if hi <= lo, hi = lo + 1; end
            m = 0.08 * (hi - lo);
            ylim(ax, [lo - m, hi + m]);
        end

        function setEnable(~, h, tf)
            if tf, h.Enable = 'on'; else, h.Enable = 'off'; end
        end

        function setBusy(obj, busy)
            if busy, c = 'watch'; else, c = 'arrow'; end
            try
                obj.UIFigure.Pointer = c;
            catch
            end
        end

        function ax = axInPanel(obj, gridParent, row, col)
            % One axes, alone in its own uipanel. A legend created for an axes
            % that sits DIRECTLY in a uigridlayout becomes an extra grid child
            % whose Layout has no Row/Column, so it cannot be pinned - the grid
            % then grows rows and every axes in it collapses to nothing. Wrapping
            % each axes in a panel keeps its legend inside that panel, so the
            % grid's child count is fixed for the life of the window.
            % (For uiaxes, Position INCLUDES the labels/margins, so [0 0 1 1]
            % fills the panel without clipping them.)
            if nargin < 4, col = 1; end
            p = uipanel(gridParent, 'BorderType', 'none', 'BackgroundColor', obj.S.card);
            p.Layout.Row = row; p.Layout.Column = col;
            % Normalized units + the panel's own AutoResizeChildren handle window
            % resizes. What they do NOT handle is a panel that changes size
            % because a render un-hid it or changed its row height - the axes
            % keeps its old size and the plot fills a fraction of the panel. Each
            % render therefore calls refitAxes() afterwards.
            % (A SizeChangedFcn here would be dead code: MATLAB disables it while
            % AutoResizeChildren is 'on', and warns once per panel.)
            ax = uiaxes(p, 'Units', 'normalized', 'Position', [0 0 1 1]);
        end

        function refitAxes(~, axList)
            % Re-fit every axes to its panel. Call after a render that changed
            % which panels are visible or how tall their rows are: the panel
            % resizes, but the axes inside does not always follow on its own.
            drawnow;
            for k = 1:numel(axList)
                if isvalid(axList(k))
                    SpindleAppBase.fillPanel(axList(k).Parent, axList(k));
                end
            end
        end

        function ax = axInGrid(obj, grid, row)
            % Create an axes explicitly placed at a grid row (auto-flow placement
            % in uigridlayout is unreliable, so always set the layout).
            ax = obj.axInPanel(grid, row, 1);
        end

        % ================================================================
        %  PER-SIGNAL PLOT HELPERS (shared by both apps)
        % ================================================================
        function axLength(obj, ax, out)
            s = obj.S;
            plot(ax, out.t, out.mt.mtuCmd, ':', 'Color', s.muted, 'LineWidth', s.lwThin); hold(ax, 'on');
            plot(ax, out.t, out.L, 'Color', s.total, 'LineWidth', s.lw); hold(ax, 'off');
            ylabel(ax, 'length (nm)'); title(ax, 'Length');
            legend(ax, {'MTU command','fascicle'}, 'Location', 'best');
            obj.padY(ax, [out.mt.mtuCmd(:); out.L(:)]); xlim(ax, [out.t(1) out.t(end)]);
            obj.tagAxes(ax, 'input');
        end

        function axActivation(obj, ax, out)
            s = obj.S;
            plot(ax, out.t, 100*out.actAlpha, 'Color', s.alpha, 'LineWidth', s.lw); hold(ax, 'on');
            plot(ax, out.t, 100*out.actC, 'Color', s.chain, 'LineWidth', s.lw);
            plot(ax, out.t, 100*out.actB, 'Color', s.bag, 'LineWidth', s.lw); hold(ax, 'off');
            ylabel(ax, 'activation (%)'); title(ax, 'Activation');
            % Naming convention throughout the apps and docs: the anatomical name
            % first, the Greek drive it carries in brackets.
            legend(ax, {'extrafusal (\alpha)','chain (\gamma-static)','bag (\gamma-dynamic)'}, ...
                'Location', 'best');
            obj.padY(ax, 100*[out.actAlpha(:); out.actC(:); out.actB(:)]); xlim(ax, [out.t(1) out.t(end)]);
            obj.tagAxes(ax, 'input');
        end

        function axForce(obj, ax, out)
            s = obj.S;
            plot(ax, out.t, out.bag.hs_force, 'Color', s.bag, 'LineWidth', s.lw);
            hold(ax, 'on');
            plot(ax, out.t, out.chain.hs_force, 'Color', s.chain, 'LineWidth', s.lw);
            hold(ax, 'off');
            ylabel(ax, 'force (N m^{-2})'); title(ax, 'Fiber force');
            legend(ax, {'bag','chain'}, 'Location', 'best');
            obj.padY(ax, [out.bag.hs_force(:); out.chain.hs_force(:)]); xlim(ax, [out.t(1) out.t(end)]);
            obj.tagAxes(ax, 'intermediate');
        end

        function axReceptor(obj, ax, out)
            s = obj.S;
            plot(ax, out.r_t, out.rs, 'Color', s.chain, 'LineWidth', s.lwThin); hold(ax, 'on');
            plot(ax, out.r_t, out.rd, 'Color', s.bag, 'LineWidth', s.lwThin);
            plot(ax, out.r_t, out.r, 'Color', s.total, 'LineWidth', s.lwThick); hold(ax, 'off');
            ylabel(ax, 'r (a.u.)'); title(ax, 'Ia receptor potential');
            legend(ax, {'r_s (static)','r_d (dynamic)','r (total)'}, 'Location', 'best');
            obj.padY(ax, [out.rs(:); out.rd(:); out.r(:)]); xlim(ax, [out.t(1) out.t(end)]);
            obj.tagAxes(ax, 'output');
        end

        function axFiring(obj, ax, out)
            % Used in exactly ONE place: the guided walkthrough's "from receptor
            % potential to spikes" step, which shows what the toolbox spike
            % generator does and why its output is time-step-limited. Every other
            % panel in both windows stops at the receptor potential (see
            % docs/04_receptor_potential.md). Matches the plot in
            % examples/spikesFromReceptorPotential.m.
            s = obj.S;
            if ~isempty(out.t_firing)
                % Draw the rate as a STAIRCASE, not stems: a second of firing at
                % 200 spikes/s is 200 stems, which merge into a solid block and
                % hide the very shape the panel exists to show. Stairs is also the
                % honest picture - 1/ISI is constant between spikes, and the rate
                % really is quantised to 1/(k*dt).
                % Staircase for the shape (1/ISI really is constant between
                % spikes and quantised to 1/(k*dt)), plus a marker per spike so
                % you can see the individual spikes. Stems were the original
                % look, but at 200 spikes/s they merge into a solid block.
                stairs(ax, out.t_firing, out.IFR, 'Color', s.green, ...
                    'LineWidth', s.lwThin);
                hold(ax, 'on');
                msz = 5; if numel(out.t_firing) > 300, msz = 3; end
                plot(ax, out.t_firing, out.IFR, 'o', 'LineStyle', 'none', ...
                    'Color', s.green, 'MarkerFaceColor', s.green, 'MarkerSize', msz);
                hold(ax, 'off');
            end
            ylabel(ax, 'Ia firing (spikes/s)'); title(ax, 'Predicted Ia firing');
            xlim(ax, [out.t(1) out.t(end)]);
            if ~isempty(out.IFR), obj.padY(ax, [0; out.IFR(:)]); end
            obj.tagAxes(ax, 'output');
        end
    end

    methods (Static)
        function fillPanel(pnl, ax)
            % Make ax exactly fill pnl, in pixels. For uiaxes, Position INCLUDES
            % the labels and margins, so [0 0 w h] fills without clipping them.
            if ~isvalid(pnl) || ~isvalid(ax), return; end
            % Re-assert the fill. Normalized units track the panel on most resize
            % paths but not all - maximising the window left the axes at their old
            % size - so this runs again from SizeChangedFcn. Do NOT compute a
            % pixel size here: both pnl.Position and getpixelposition report
            % mid-layout values inside this callback.
            % Toggling the units forces MATLAB to recompute the layout. Simply
            % re-assigning the same normalized Position is a no-op, which is why
            % an axes whose panel had just been un-hidden stayed at its old size.
            ax.Units = 'pixels';
            ax.Units = 'normalized';
            ax.Position = [0 0 1 1];
        end

        function s = sty()
            % Shared palette + typography. Softened, slightly desaturated colors
            % on warm off-white canvases with white cards. bag = warm terracotta,
            % chain = soft steel blue (kept everywhere); muted navy for headings.
            % Helvetica is not a real Windows font; MATLAB substitutes it and
            % the result is noticeably heavier than the Mac rendering.
            if ispc, s.font = 'Segoe UI'; else, s.font = 'Helvetica'; end
            s.bag       = [0.84 0.42 0.24];   % bag fiber / dynamic (soft terracotta)
            s.chain     = [0.24 0.52 0.72];   % chain fiber / static (soft blue)
            s.total     = [0.26 0.28 0.34];   % total / r (dark slate, not black)
            s.yank      = [0.52 0.32 0.55];   % yank (dF/dt) (soft plum)
            s.green     = [0.28 0.56 0.46];   % firing (soft teal-green)
            s.alpha     = [0.62 0.44 0.16];   % alpha (extrafusal) drive (soft ochre)
            s.navy      = [0.18 0.34 0.50];   % headings / titles (muted navy)
            s.accent    = [0.24 0.46 0.66];   % primary control accent
            s.grid      = [0.92 0.93 0.95];   % gridlines (very light)
            s.axisTxt   = [0.40 0.41 0.46];   % axis text / labels
            s.muted     = [0.52 0.53 0.58];   % secondary text
            s.canvasDoc = [1 1 1];            % explanation sections: white
            s.canvasApp = [0.965 0.963 0.960];% app sections: warm off-white
            s.card      = [1 1 1];            % white cards
            s.cardEdge  = [0.90 0.91 0.93];   % card border (soft)
            % line weights + legend text (a touch bolder/bigger everywhere)
            s.lwThin    = 1.8;
            s.lw        = 2.2;
            s.lwThick   = 2.8;
            s.legendFont = 10;
            % input / intermediate / output badge colors
            s.tagInput  = [0.28 0.56 0.46];   % green
            s.tagInter  = [0.58 0.60 0.66];   % grey
            s.tagOutput = [0.80 0.50 0.16];   % amber
            % three snapshot colors: pre / early / post stretch
            s.snap = [0.52 0.53 0.58; 0.80 0.36 0.28; 0.24 0.54 0.46];
        end

        function f = resolveAsset(name)
            % Locate a bundled asset (e.g. a figure) in dev AND in a compiled app.
            % Dev: repo/data/<name>; deployed: the file is extracted under ctfroot.
            here  = fileparts(mfilename('fullpath'));         % app/ folder
            cands = { fullfile(fileparts(here), 'data', name) };
            if isdeployed
                cands{end+1} = fullfile(ctfroot, 'data', name);
                cands{end+1} = fullfile(ctfroot, name);
            end
            for i = 1:numel(cands)
                if isfile(cands{i}), f = cands{i}; return; end
            end
            roots = {here}; if isdeployed, roots{end+1} = ctfroot; end
            for k = 1:numel(roots)
                d = dir(fullfile(roots{k}, '**', name));
                if ~isempty(d), f = fullfile(d(1).folder, d(1).name); return; end
            end
            error('SpindleAppBase:asset', 'Asset not found: %s', name);
        end

        function tag = imgTag(name, styleStr)
            % Build a self-contained <img> tag (base64 data URI) for a bundled
            % image, so it embeds in uihtml and compiles with no external file ref.
            if nargin < 2, styleStr = 'max-width:100%;height:auto;'; end
            try
                fid = fopen(SpindleAppBase.resolveAsset(name), 'r');
                bytes = fread(fid, Inf, '*uint8'); fclose(fid);
                b64 = matlab.net.base64encode(bytes);
                tag = ['<img src="data:image/png;base64,' b64 '" style="' styleStr '">'];
            catch
                tag = '';   % asset missing -> just omit the image
            end
        end
    end
end
