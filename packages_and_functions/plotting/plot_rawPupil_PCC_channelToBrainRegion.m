% ======================================================================
%  plot_rawPupil_PCC_channelToBrainRegion_v2.m
%
%  Same as plot_rawPupil_PCC_channelToBrainRegion.m, but STEP 1 now
%  uses the name-keyed <M|N>_channel_area_map.mat (built by
%  build_channel_area_map.m) instead of positional matching against
%  ChanAreas directly - same fix already applied to
%  channelToBrainRegion_v2.m for the GLM data. This means sessions like
%  N0110/N0113 (one trailing untracked channel) are no longer skipped
%  wholesale - only that one channel is marked Unassigned, and every
%  other channel's real PCC/pValue is kept.
% ======================================================================

% ---------------------------- CONFIG ---------------------------------
M_PCC_FILE = "Z:\users\Jeremiah\M\M_pupil_aperiodicExp_PCC.mat";
N_PCC_FILE = "Z:\users\Jeremiah\N\N_pupil_aperiodicExp_PCC.mat";

M_AREAMAP_FILE = "Z:\users\Jeremiah\M\M_channel_area_map.mat";
N_AREAMAP_FILE = "Z:\users\Jeremiah\N\N_channel_area_map.mat";

PCC_FIELD = 'rawPupil_to_aperiodicExp_PCC';   % must match pupil_aperiodic_correlation.m
AREA_NAMES = {'ACC', 'OFC'};                  % add more region names here as needed

ALPHA = 0.05;
POOL_MONKEYS = false;           % true: combine M and N into one pooled dataset per area
OUTPUT_FOLDER = "Z:\users\Jeremiah\figures";
FIG_BG_COLOR = 'k';             % 'w' = white, or e.g. [0.94 0.94 0.94] for MATLAB default gray
% -----------------------------------------------------------------------

if ~exist(OUTPUT_FOLDER, 'dir')
    mkdir(OUTPUT_FOLDER);
end

% ========================================================================
%  STEP 1 - ORGANIZE BY BRAIN REGION (name-keyed, via area map)
% ========================================================================

M_raw = load(M_PCC_FILE);
M = M_raw.M;
N_raw = load(N_PCC_FILE);
N = N_raw.N;

Monkeys = struct();
Monkeys.M = M;
Monkeys.N = N;
monkeyNames = fieldnames(Monkeys);

AreaMaps = struct();
AreaMaps.M = load(M_AREAMAP_FILE);
AreaMaps.M = AreaMaps.M.AreaMap;
AreaMaps.N = load(N_AREAMAP_FILE);
AreaMaps.N = AreaMaps.N.AreaMap;

for i = 1:2
    monkeyLetter = monkeyNames{i};
    monkey = Monkeys.(monkeyLetter);
    AreaMap = AreaMaps.(monkeyLetter);

    sessionKeys = fieldnames(monkey);

    for s = 1:numel(sessionKeys)
        key = sessionKeys{s};
        session = monkey.(key);

        if ~isfield(session, PCC_FIELD)
            warning('%s (%s): no %s field found. Skipping session.', monkeyLetter, key, PCC_FIELD);
            continue
        end

        if ~isfield(AreaMap, key)
            warning('%s (%s): no entry in channel area map. Skipping session.', monkeyLetter, key);
            continue
        end
        sessionMap = AreaMap.(key);

        for a = 1:numel(AREA_NAMES)
            areaName = AREA_NAMES{a};
            if ~isfield(sessionMap, areaName)
                continue
            end
            channelList = sessionMap.(areaName);

            brainArea = struct();
            brainArea.PCC = struct();
            brainArea.PCC.coefficient = [];
            brainArea.PCC.pValue = [];

            % driven by the TRUE channel list for this area (from the
            % area map), not by which channels happened to have a PCC
            % entry - a channel missing from PCC results (e.g. trial
            % count mismatch upstream) still gets one NaN-padded slot
            for c = 1:numel(channelList)
                chName = channelList{c};

                % channel_name in pupil_aperiodic_correlation.m is used
                % AS-IS (not sanitized via makeValidName), so match
                % directly against the PCC_FIELD struct's fieldnames.
                if isfield(session.(PCC_FIELD), chName)
                    chanEntry = session.(PCC_FIELD).(chName);
                    if isfield(chanEntry, 'PCC') && isfield(chanEntry, 'pValue')
                        pccVal = chanEntry.PCC;
                        pVal   = chanEntry.pValue;
                    else
                        pccVal = NaN;
                        pVal   = NaN;
                    end
                else
                    pccVal = NaN;
                    pVal   = NaN;
                end

                brainArea.PCC.coefficient(end+1) = pccVal;
                brainArea.PCC.pValue(end+1) = pVal;
            end

            brainArea.ChannelNames = channelList;
            session.(areaName) = brainArea;
        end

        monkey.(key) = session;
    end
    Monkeys.(monkeyLetter) = monkey;
end

M = Monkeys.M;
N = Monkeys.N;
% (region-organized M/N kept in memory only - not written back to disk)


% ========================================================================
%  STEP 2 - PLOT ACC VS OFC (unchanged from original)
% ========================================================================

if POOL_MONKEYS
    monkeyGroups = struct('label', {'M+N'}, 'data', {{M, N}});
else
    monkeyGroups = struct('label', {'M', 'N'}, 'data', {{M}, {N}});
end

areaColors = lines(numel(AREA_NAMES));
areaColors(strcmp(AREA_NAMES, 'OFC'), :) = [0.55 0.20 0.75];   % override OFC to purple

figHandles = gobjects(1, 0);

for g = 1:numel(monkeyGroups)
    groupLabel = monkeyGroups(g).label;
    monkeyStructs = monkeyGroups(g).data;

    areaData = struct('name', {}, 'coef', {}, 'pValue', {}, 'color', {});
    for a = 1:numel(AREA_NAMES)
        [coefVec, pVec] = gather_values(monkeyStructs, AREA_NAMES{a});
        areaData(a).name = AREA_NAMES{a};
        areaData(a).coef = coefVec;
        areaData(a).pValue = pVec;
        areaData(a).color = areaColors(a, :);
    end

    base_title = sprintf('rawPupil to aperiodicExp PCC (%s)', groupLabel);

    fh1 = make_scatter_plot(areaData, ALPHA, [base_title ' scatter'], FIG_BG_COLOR);
    figHandles(end+1) = fh1; %#ok<AGROW>

    fh2 = make_histogram_plot(areaData, ALPHA, [base_title ' histogram'], FIG_BG_COLOR);
    figHandles(end+1) = fh2; %#ok<AGROW>
end

% ----------------------------------------------------------------------
% Save every figure created above, as both .png and .fig
% ----------------------------------------------------------------------
for i = 1:numel(figHandles)
    fh = figHandles(i);
    figName = get(fh, 'Name');
    safeName = matlab.lang.makeValidName(figName);

    png_path = fullfile(OUTPUT_FOLDER, [safeName '.png']);
    fig_path = fullfile(OUTPUT_FOLDER, [safeName '.fig']);

    exportgraphics(fh, png_path, 'Resolution', 200);
    savefig(fh, fig_path);
end

fprintf('Saved %d figures to %s\n', numel(figHandles), OUTPUT_FOLDER);


% ======================================================================
%  gather_values - pools the PCC/pValue pair for one brain area, across
%  every session in every monkey struct passed in. NaN entries (channels
%  whose correlation was skipped upstream, e.g. <3 valid trial pairs)
%  are dropped here rather than plotted.
% ======================================================================
function [coefOut, pOut] = gather_values(monkeyStructs, areaName)
    coefOut = [];
    pOut = [];

    for m = 1:numel(monkeyStructs)
        monkey = monkeyStructs{m};
        sessionNames = fieldnames(monkey);

        for s = 1:numel(sessionNames)
            session = monkey.(sessionNames{s});

            if ~isfield(session, areaName) || ~isfield(session.(areaName), 'PCC')
                continue
            end

            coefVec = session.(areaName).PCC.coefficient;
            pVec    = session.(areaName).PCC.pValue;

            coefOut = [coefOut, coefVec]; %#ok<AGROW>
            pOut    = [pOut, pVec];       %#ok<AGROW>
        end
    end

    validMask = ~isnan(coefOut) & ~isnan(pOut);
    coefOut = coefOut(validMask);
    pOut    = pOut(validMask);
end


% ======================================================================
%  make_scatter_plot - one region per x-position (in AREA_NAMES order),
%  one jittered dot per channel-session, colored red if significant
%  (p < alpha), gray otherwise. Generalizes to any number of regions.
% ======================================================================
function fh = make_scatter_plot(areaData, alpha, plot_title, bgColor)
    fh = figure('Name', plot_title, 'Color', bgColor);
    hold on

    jitterWidth = 0.15;
    nAreas = numel(areaData);
    statsStrs = cell(1, nAreas);

    for a = 1:nAreas
        plot_group(a, areaData(a).coef, areaData(a).pValue, alpha, jitterWidth);
        nA = numel(areaData(a).coef);
        pctSig = 100 * mean(areaData(a).pValue < alpha);
        statsStrs{a} = sprintf('%s: n=%d, %.1f%% sig', areaData(a).name, nA, pctSig);
    end

    xlim([0.5, nAreas + 0.5]);
    set(gca, 'XTick', 1:nAreas, 'XTickLabel', {areaData.name});
    ylabel('Pearson correlation coefficient (PCC)');
    yline(0, 'k:');

    title({strrep(plot_title, '_', ' '), strjoin(statsStrs, ' | ')});
    legend({sprintf('p < %.2f', alpha), sprintf('p \\geq %.2f', alpha)}, 'Location', 'best');

    hold off
end

function plot_group(xPos, coefVec, pVec, alpha, jitterWidth)
    n = numel(coefVec);
    if n == 0
        return
    end

    jitter = (rand(1, n) - 0.5) * 2 * jitterWidth;
    xVals = xPos + jitter;
    sigMask = pVec < alpha;

    scatter(xVals(~sigMask), coefVec(~sigMask), 25, [0.6 0.6 0.6], 'filled', ...
        'MarkerFaceAlpha', 0.5, 'HandleVisibility', 'off');
    scatter(xVals(sigMask), coefVec(sigMask), 25, [0.85 0.1 0.1], 'filled', ...
        'MarkerFaceAlpha', 0.7, 'HandleVisibility', 'off');

    if xPos == 1
        scatter(NaN, NaN, 25, [0.85 0.1 0.1], 'filled');
        scatter(NaN, NaN, 25, [0.6 0.6 0.6], 'filled');
    end
end


% ======================================================================
%  make_histogram_plot - ONE figure containing one subplot PER REGION,
%  side by side, sharing the same bin edges and y-axis scale. Within
%  each subplot: the FULL distribution in that region's own base
%  color, and the SIGNIFICANT subset (p < alpha) overlaid in a fixed
%  contrasting highlight color. Generalizes to any number of regions.
% ======================================================================
function fh = make_histogram_plot(areaData, alpha, plot_title, bgColor)
    SIG_COLOR = [0.85 0.05 0.05];   % strong red - fixed across all regions for high contrast

    fh = figure('Name', plot_title, 'Color', bgColor, 'Position', [100 100 1100 420]);

    allVals = [areaData.coef];
    nAreas = numel(areaData);

    tl = tiledlayout(fh, 1, nAreas, 'Padding', 'compact', 'TileSpacing', 'compact');
    title(tl, strrep(plot_title, '_', ' '));

    if isempty(allVals)
        nexttile(tl);
        title('No data');
        return
    end

    nBins = 20;
    edges = linspace(min(allVals), max(allVals), nBins + 1);

    axHandles = gobjects(1, nAreas);

    for a = 1:nAreas
        coefVec = areaData(a).coef;
        pVec = areaData(a).pValue;
        baseColor = areaData(a).color;
        sigMask = pVec < alpha;

        ax = nexttile(tl);
        axHandles(a) = ax;
        hold(ax, 'on');

        histogram(ax, coefVec, edges, 'FaceColor', baseColor, 'FaceAlpha', 0.55, ...
            'EdgeColor', 'none', 'DisplayName', 'all channels');

        if any(sigMask)
            histogram(ax, coefVec(sigMask), edges, 'FaceColor', SIG_COLOR, 'FaceAlpha', 0.95, ...
                'EdgeColor', 'none', 'DisplayName', sprintf('p < %.2f', alpha));
        end

        xline(ax, 0, 'k:', 'HandleVisibility', 'off');
        xlabel(ax, 'PCC');
        ylabel(ax, 'Channel count');

        nA = numel(coefVec);
        pctSig = 100 * mean(sigMask);
        title(ax, sprintf('%s (n=%d, %.1f%% sig)', areaData(a).name, nA, pctSig));

        legend(ax, 'Location', 'best');
        hold(ax, 'off');
    end

    linkaxes(axHandles, 'y');
end