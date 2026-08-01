% ======================================================================
%  plot_aperiodic_brain_region_v2.m
%
%  General graphing script for comparing GLM coefficients across an
%  arbitrary set of brain regions (not hardcoded to ACC/OFC - add or
%  remove regions by editing AREA_NAMES below, as long as
%  channelToBrainRegion.m has written matching fields into each
%  session, e.g. session.ACC, session.OFC, session.<NewRegion>, ...).
%
%  Loads M and N directly from disk (the output of
%  channelToBrainRegion.m / ap_reward_glm_analysis.m), so this script
%  can be run standalone without needing M/N already in the workspace.
%
%  Produces, for every combination of:
%    parameter  = {'aperiodic_exponent', 'offset'}
%    predictor  = {'rewardsize', 'choiceornochoice'}
%  TWO figures:
%    1. A scatter/dot plot - one region per x-position, one jittered
%       dot per channel-session, colored red if significant
%       (p < ALPHA), gray otherwise.
%    2. A histogram - one overlaid distribution per region (own color,
%       low alpha), with the SIGNIFICANT subset of that same region's
%       channels overlaid in a darker shade of the same color, on the
%       same bins, to highlight where significant channels fall.
%
%  Each region's stats annotation also reports a one-sample t-test of
%  ALL that region's coefficients against a null mean of 0
%  (ttest(coefficients, 0)) - NOT restricted to the significant
%  subset. Filtering to p<alpha channels before running this test
%  would double-dip on the same selection criterion and bias the
%  group-level result toward significance regardless of the true
%  regional effect, so every valid channel is included.
%
%  All figures are saved to OUTPUT_FOLDER (as .png and .fig) at the end.
% ======================================================================

% ---------------------------- CONFIG ---------------------------------
M_FILE = "Z:\users\Jeremiah\M\M_glm_results.mat";
N_FILE = "Z:\users\Jeremiah\N\N_glm_results.mat";

AREA_NAMES = {'ACC', 'OFC'};   % add more region names here as needed

ALPHA = 0.05;
POOL_MONKEYS = false;           % true: combine M and N into one pooled dataset per area
OUTPUT_FOLDER = "Z:\users\Jeremiah\figures";
FIG_BG_COLOR = 'k';            % 'w' = white, or e.g. [0.94 0.94 0.94] for MATLAB default gray
% -----------------------------------------------------------------------

if ~exist(OUTPUT_FOLDER, 'dir')
    mkdir(OUTPUT_FOLDER);
end

% load() returns a struct field named after the variable that was saved
% (see ap_reward_glm_analysis.m's save(...,'M') / save(...,'N') calls),
% so unwrap immediately to get the real session-keyed struct.
M_raw = load(M_FILE);
N_raw = load(N_FILE);
M = M_raw.M;
N = N_raw.N;

parameters = {'aperiodic_exponent', 'offset'};
predictors = {'rewardsize', 'choiceornochoice'};

if POOL_MONKEYS
    monkeyGroups = struct('label', {'M+N'}, 'data', {{M, N}});
else
    monkeyGroups = struct('label', {'M', 'N'}, 'data', {{M}, {N}});
end

areaColors = lines(numel(AREA_NAMES));
areaColors(strcmp(AREA_NAMES, 'OFC'), :) = [0.55 0.20 0.75];   % override OFC to purple

figHandles = gobjects(1, 0);   % empty graphics-object array

for g = 1:numel(monkeyGroups)
    groupLabel = monkeyGroups(g).label;
    monkeyStructs = monkeyGroups(g).data;

    for p = 1:numel(parameters)
        paramName = parameters{p};

        for r = 1:numel(predictors)
            predName = predictors{r};

            % gather coefficient/pValue vectors for every area, once,
            % and reuse for both plot types
            areaData = struct('name', {}, 'coef', {}, 'pValue', {}, 'color', {});
            for a = 1:numel(AREA_NAMES)
                [coefVec, pVec] = gather_values(monkeyStructs, AREA_NAMES{a}, paramName, predName);
                areaData(a).name = AREA_NAMES{a};
                areaData(a).coef = coefVec;
                areaData(a).pValue = pVec;
                areaData(a).color = areaColors(a, :);
            end

            base_title = sprintf('%s - %s (%s)', paramName, predName, groupLabel);

            fh1 = make_scatter_plot(areaData, ALPHA, [base_title ' scatter'], FIG_BG_COLOR);
            figHandles(end+1) = fh1; %#ok<AGROW>

            fh2 = make_histogram_plot(areaData, ALPHA, [base_title ' histogram'], FIG_BG_COLOR);
            figHandles(end+1) = fh2; %#ok<AGROW>
        end
    end
end

% ----------------------------------------------------------------------
% Save every figure created above, as both .png and .fig, named after
% each figure's 'Name' property (sanitized for use as a filename).
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
%  gather_values - pools a coefficient/pValue pair for one brain area,
%  one aperiodic parameter, one predictor, across every session in
%  every monkey struct passed in. NaN entries (channels whose fit was
%  missing upstream, per the isfield/NaN-padding in
%  channelToBrainRegion.m) are dropped here rather than plotted.
% ======================================================================
function [coefOut, pOut] = gather_values(monkeyStructs, areaName, paramName, predName)
    coefOut = [];
    pOut = [];

    for m = 1:numel(monkeyStructs)
        monkey = monkeyStructs{m};
        sessionNames = fieldnames(monkey);

        for s = 1:numel(sessionNames)
            session = monkey.(sessionNames{s});

            if ~isfield(session, areaName)
                continue
            end
            area = session.(areaName);

            if ~isfield(area, paramName) || ~isfield(area.(paramName), predName)
                continue
            end

            coefVec = area.(paramName).(predName).coefficient;
            pVec    = area.(paramName).(predName).pValue;

            coefOut = [coefOut, coefVec]; %#ok<AGROW>
            pOut    = [pOut, pVec];       %#ok<AGROW>
        end
    end

    validMask = ~isnan(coefOut) & ~isnan(pOut);
    coefOut = coefOut(validMask);
    pOut    = pOut(validMask);
end


% ======================================================================
%  group_ttest_str - one-sample t-test of a region's coefficients
%  against a null mean of 0, using ALL valid channels passed in (never
%  pre-filtered to the significant subset - see header note on why).
%  Returns a short display string; degenerate/empty input is handled
%  gracefully so the plotting functions never error on sparse data.
% ======================================================================
function str = group_ttest_str(coefVec)
    coefVec = coefVec(~isnan(coefVec));
    if numel(coefVec) < 2
        str = 't-test: n/a';
        return
    end
    [~, p, ~, stats] = ttest(coefVec, 0);
    str = sprintf('t(%d)=%.2f, p=%.3g', stats.df, stats.tstat, p);
end


% ======================================================================
%  make_scatter_plot - one region per x-position (in AREA_NAMES order),
%  one jittered dot per channel-session, colored red if significant
%  (p < alpha), gray otherwise. Generalizes to any number of regions.
%  Each region's label also reports a one-sample t-test (vs. 0) over
%  ALL of that region's coefficients.
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
        ttestStr = group_ttest_str(areaData(a).coef);
        statsStrs{a} = sprintf('%s: n=%d, %.1f%% sig, %s', areaData(a).name, nA, pctSig, ttestStr);
    end

    xlim([0.5, nAreas + 0.5]);
    set(gca, 'XTick', 1:nAreas, 'XTickLabel', {areaData.name});
    ylabel('Coefficient');
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
%  side by side, sharing the same bin edges and y-axis scale so they're
%  directly comparable. Within each subplot: the FULL distribution in
%  that region's own base color, and the SIGNIFICANT subset (p < alpha)
%  overlaid in a strongly contrasting fixed highlight color (not a
%  shade of the region's own color, so it reads clearly against every
%  region). Generalizes to any number of regions (colors/names come
%  from areaData; subplot count follows numel(areaData)). Each
%  subplot's title also reports a one-sample t-test (vs. 0) over ALL
%  of that region's coefficients.
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
        xlabel(ax, 'Coefficient');
        ylabel(ax, 'Channel count');

        nA = numel(coefVec);
        pctSig = 100 * mean(sigMask);
        ttestStr = group_ttest_str(coefVec);
        title(ax, sprintf('%s (n=%d, %.1f%% sig)\n%s', areaData(a).name, nA, pctSig, ttestStr));

        legend(ax, 'Location', 'best');
        hold(ax, 'off');
    end

    linkaxes(axHandles, 'y');   % same y-scale across regions for fair visual comparison
end