% ======================================================================
%  plot_ttest_heatmap.m
%
%  Heatmap-style summary of group-level t-tests, laid out as:
%
%                       ACC        OFC
%              M    [p-val]    [p-val]
%  Ap.Exp           -----------------------
%  ~RewardSize  N    [p-val]    [p-val]
%              M    [p-val]    [p-val]
%  Ap.Exp           -----------------------
%  ~Choice      N    [p-val]    [p-val]
%              M    [p-val]    [p-val]
%  rawPupil         -----------------------
%  ~Ap.Exp (PCC) N   [p-val]    [p-val]
%
%  The first two blocks (Reward Size, Choice) come from the GLM
%  coefficients (channelToBrainRegion.m / ap_reward_glm_analysis.m
%  output). The third block, added at the bottom the same way, comes
%  from the rawPupil-to-aperiodic-exponent Pearson correlation output
%  (pupil_aperiodic_correlation.m), region-organized via the channel
%  area map exactly as in plot_rawPupil_PCC_channelToBrainRegion_v2.m's
%  STEP 1 (name-keyed matching, so partially-tracked sessions like
%  N0110/N0113 aren't skipped wholesale).
%
%  For every (block, monkey, area) cell, this pulls every channel's
%  coefficient for that combination (across all sessions) and runs a
%  ONE-SAMPLE T-TEST against a null mean of 0 (ttest(coefficients, 0)).
%  This uses ALL valid channels, never just the ones individually
%  significant at the single-channel level - filtering to p<alpha
%  channels first would double-dip on the same selection criterion
%  and bias the group-level test toward significance regardless of
%  the true regional effect.
%
%  Cell color = t-value, drawn with imagesc + a diverging blue/cyan ->
%  purple colormap (5 stops so deep colors saturate well before the
%  extremes), with a borderless colorbar. Cell text = the group-level
%  p-value, always black (readable against the colored cells); all
%  other labels are white (readable against the black figure
%  background).
% ======================================================================

% ---------------------------- CONFIG ---------------------------------
% GLM coefficients (Reward Size / Choice blocks)
GLM_M_FILE = "Z:\users\Jeremiah\M\M_glm_results.mat";
GLM_N_FILE = "Z:\users\Jeremiah\N\N_glm_results.mat";
PARAM_NAME = 'aperiodic_exponent';   % which GLM parameter to summarize

% rawPupil-to-aperiodic-exponent PCC (bottom block)
PCC_M_FILE = "Z:\users\Jeremiah\M\M_pupil_aperiodicExp_PCC.mat";
PCC_N_FILE = "Z:\users\Jeremiah\N\N_pupil_aperiodicExp_PCC.mat";
AREAMAP_M_FILE = "Z:\users\Jeremiah\M\M_channel_area_map.mat";
AREAMAP_N_FILE = "Z:\users\Jeremiah\N\N_channel_area_map.mat";
PCC_FIELD = 'rawPupil_to_aperiodicExp_PCC';   % must match pupil_aperiodic_correlation.m

AREA_NAMES = {'ACC', 'OFC'};        % x-axis (columns), left to right
MONKEY_LABELS = {'M', 'N'};         % row order within each block

% y-axis (rows): one block per row-group below. type 'glm' pulls from
% the GLM coefficient struct using the given predictor field; type
% 'pcc' pulls from the region-organized rawPupil PCC struct built
% below. Add/remove/reorder blocks here - the heatmap follows.
blocks = struct( ...
    'type',  {'glm',                'glm',               'pcc'}, ...
    'field', {'rewardsize',         'choiceornochoice',  ''}, ...
    'label', {'Ap. Exp \sim Reward Size', 'Ap. Exp \sim Choice', 'rawPupil \sim Ap. Exp'});

OUTPUT_FOLDER = "Z:\users\Jeremiah\figures";
FIG_BG_COLOR = 'k';   % black background
PVAL_FORMAT = '%.3g';   % how p-values are printed in each cell
% -----------------------------------------------------------------------

if ~exist(OUTPUT_FOLDER, 'dir')
    mkdir(OUTPUT_FOLDER);
end

% ------------------------------------------------------------------
% Load GLM coefficients (Reward Size / Choice blocks)
% ------------------------------------------------------------------
M_glm_raw = load(GLM_M_FILE);
N_glm_raw = load(GLM_N_FILE);
M_glm = M_glm_raw.M;
N_glm = N_glm_raw.N;
GlmData = struct('M', M_glm, 'N', N_glm);

% ------------------------------------------------------------------
% Load + region-organize the rawPupil PCC data (bottom block), same
% name-keyed area-map approach as
% plot_rawPupil_PCC_channelToBrainRegion_v2.m STEP 1.
% ------------------------------------------------------------------
M_pcc_raw = load(PCC_M_FILE);
N_pcc_raw = load(PCC_N_FILE);
PccRaw = struct('M', M_pcc_raw.M, 'N', N_pcc_raw.N);

AreaMapRaw = struct();
AreaMapRaw.M = load(AREAMAP_M_FILE);
AreaMapRaw.M = AreaMapRaw.M.AreaMap;
AreaMapRaw.N = load(AREAMAP_N_FILE);
AreaMapRaw.N = AreaMapRaw.N.AreaMap;

PccData = struct();
monkeyLettersForPcc = fieldnames(PccRaw);
for i = 1:numel(monkeyLettersForPcc)
    monkeyLetter = monkeyLettersForPcc{i};
    PccData.(monkeyLetter) = organize_pcc_by_region( ...
        PccRaw.(monkeyLetter), AreaMapRaw.(monkeyLetter), PCC_FIELD, AREA_NAMES, monkeyLetter);
end

% ------------------------------------------------------------------
% Build the t-value / p-value grid across all blocks x monkeys x areas
% ------------------------------------------------------------------
nBlocks = numel(blocks);
nMonkeys = numel(MONKEY_LABELS);
nRows = nBlocks * nMonkeys;
nCols = numel(AREA_NAMES);

tMat = nan(nRows, nCols);
pMat = nan(nRows, nCols);
nMat = nan(nRows, nCols);
rowLabels = cell(nRows, 1);
rowGroupLabel = cell(nRows, 1);   % block label, only set on first row of each block

rowIdx = 0;
for b = 1:nBlocks
    for mk = 1:nMonkeys
        rowIdx = rowIdx + 1;
        monkeyLetter = MONKEY_LABELS{mk};

        rowLabels{rowIdx} = monkeyLetter;
        if mk == 1
            rowGroupLabel{rowIdx} = blocks(b).label;
        end

        for c = 1:nCols
            areaName = AREA_NAMES{c};

            switch blocks(b).type
                case 'glm'
                    coefVec = gather_glm_coef(GlmData.(monkeyLetter), areaName, PARAM_NAME, blocks(b).field);
                case 'pcc'
                    coefVec = gather_pcc_coef(PccData.(monkeyLetter), areaName);
                otherwise
                    error('Unknown block type: %s', blocks(b).type);
            end

            if numel(coefVec) < 2
                tMat(rowIdx, c) = NaN;
                pMat(rowIdx, c) = NaN;
            else
                [~, p, ~, stats] = ttest(coefVec, 0);
                tMat(rowIdx, c) = stats.tstat;
                pMat(rowIdx, c) = p;
            end
            nMat(rowIdx, c) = numel(coefVec);
        end
    end
end

fh = make_ttest_heatmap(tMat, pMat, AREA_NAMES, rowLabels, rowGroupLabel, ...
    nMonkeys, PVAL_FORMAT, FIG_BG_COLOR, 'group-level t-test (all channels)');

% ----------------------------------------------------------------------
% Save figure
% ----------------------------------------------------------------------
figName = get(fh, 'Name');
safeName = matlab.lang.makeValidName(figName);
png_path = fullfile(OUTPUT_FOLDER, [safeName '.png']);
fig_path = fullfile(OUTPUT_FOLDER, [safeName '.fig']);

exportgraphics(fh, png_path, 'Resolution', 200);
savefig(fh, fig_path);

fprintf('Saved heatmap to %s\n', OUTPUT_FOLDER);


% ======================================================================
%  organize_pcc_by_region - region-organizes ONE monkey's rawPupil PCC
%  struct using the name-keyed channel area map, exactly matching
%  plot_rawPupil_PCC_channelToBrainRegion_v2.m STEP 1: driven by the
%  TRUE channel list per area (from the area map), so a channel
%  missing from the PCC results still gets one NaN-padded slot rather
%  than silently shrinking the session.
% ======================================================================
function monkeyOut = organize_pcc_by_region(monkeyIn, AreaMap, pccField, areaNames, monkeyLetter)
    monkeyOut = struct();
    sessionKeys = fieldnames(monkeyIn);

    for s = 1:numel(sessionKeys)
        key = sessionKeys{s};
        session = monkeyIn.(key);

        if ~isfield(session, pccField)
            warning('%s (%s): no %s field found. Skipping session.', monkeyLetter, key, pccField);
            continue
        end

        if ~isfield(AreaMap, key)
            warning('%s (%s): no entry in channel area map. Skipping session.', monkeyLetter, key);
            continue
        end
        sessionMap = AreaMap.(key);

        for a = 1:numel(areaNames)
            areaName = areaNames{a};
            if ~isfield(sessionMap, areaName)
                continue
            end
            channelList = sessionMap.(areaName);

            brainArea = struct();
            brainArea.PCC = struct();
            brainArea.PCC.coefficient = [];
            brainArea.PCC.pValue = [];

            for c = 1:numel(channelList)
                chName = channelList{c};

                if isfield(session.(pccField), chName)
                    chanEntry = session.(pccField).(chName);
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

        monkeyOut.(key) = session;
    end
end


% ======================================================================
%  gather_glm_coef - pools a coefficient vector for one monkey struct,
%  one brain area, one GLM parameter, one predictor, across every
%  session. NaN entries (channels whose fit was missing upstream) are
%  dropped.
% ======================================================================
function coefOut = gather_glm_coef(monkeyStruct, areaName, paramName, predName)
    coefOut = [];
    sessionNames = fieldnames(monkeyStruct);

    for s = 1:numel(sessionNames)
        session = monkeyStruct.(sessionNames{s});

        if ~isfield(session, areaName)
            continue
        end
        area = session.(areaName);

        if ~isfield(area, paramName) || ~isfield(area.(paramName), predName)
            continue
        end

        coefVec = area.(paramName).(predName).coefficient;
        coefOut = [coefOut, coefVec]; %#ok<AGROW>
    end

    coefOut = coefOut(~isnan(coefOut));
end


% ======================================================================
%  gather_pcc_coef - pools the PCC coefficient vector for one monkey's
%  region-organized rawPupil struct, one brain area, across every
%  session. NaN entries (channels whose correlation was skipped
%  upstream, e.g. <3 valid trial pairs, or untracked channels) are
%  dropped.
% ======================================================================
function coefOut = gather_pcc_coef(monkeyStruct, areaName)
    coefOut = [];
    sessionNames = fieldnames(monkeyStruct);

    for s = 1:numel(sessionNames)
        session = monkeyStruct.(sessionNames{s});

        if ~isfield(session, areaName) || ~isfield(session.(areaName), 'PCC')
            continue
        end

        coefOut = [coefOut, session.(areaName).PCC.coefficient]; %#ok<AGROW>
    end

    coefOut = coefOut(~isnan(coefOut));
end


% ======================================================================
%  diverging_tval_colormap - blue/cyan for negative t, purple/deep
%  purple for positive t, with a light neutral stop at t=0. Built from
%  5 color stops (dark blue, cyan, near-white, purple, dark purple)
%  rather than a simple 2-point fade, so the color reaches its deepest,
%  most saturated blue/purple well before the ends of the range and
%  then plateaus, instead of only maxing out at the single most
%  extreme t-value. Used with a symmetric caxis so the exact middle
%  row of the colormap lands on t=0.
% ======================================================================
function cmap = diverging_tval_colormap(nSteps)
    if nargin < 1
        nSteps = 256;
    end

    % 5 color stops, placed so the deepest blue/purple is reached well
    % before the ends of the range (at 15%/85%) rather than only at
    % the very extremes - the colormap "saturates faster" and then
    % plateaus at full color for the rest of the range.
    stopPositions = [0, 0.15, 0.5, 0.85, 1];

    darkBlue   = [0.05 0.05 0.65];
    cyan       = [0.10 0.75 0.80];
    neutral    = [0.97 0.97 0.97];
    purple     = [0.55 0.10 0.75];
    darkPurple = [0.35 0.02 0.55];

    stopColors = [darkBlue; cyan; neutral; purple; darkPurple];

    x = linspace(0, 1, nSteps)';
    cmap = zeros(nSteps, 3);
    for ch = 1:3
        cmap(:, ch) = interp1(stopPositions, stopColors(:, ch), x, 'linear');
    end
end


% ======================================================================
%  make_ttest_heatmap - imagesc of the t-value matrix with a diverging
%  blue/cyan-to-purple colormap and a borderless colorbar, p-values
%  annotated in black text on every cell, no grid lines between cells,
%  and a divider between row-blocks drawn in the background color (so
%  it reads as a gap rather than a border). All non-p-value text is
%  white, readable against the black figure background.
% ======================================================================
function fh = make_ttest_heatmap(tMat, pMat, colLabels, rowLabels, rowGroupLabel, ...
        nMonkeysPerGroup, pvalFormat, bgColor, plotTitle)

    [nRows, nCols] = size(tMat);
    tMax = max(abs(tMat(:)), [], 'omitnan');
    if isempty(tMax) || tMax == 0
        tMax = 1;
    end

    TEXT_COLOR = [1 1 1];   % white text/labels, readable against black background

    fh = figure('Name', matlab.lang.makeValidName(plotTitle), 'Color', bgColor, ...
        'Position', [100 100 780 220 + 90*nRows]);
    ax = axes('Parent', fh);
    hold(ax, 'on');

    % --- main heatmap ---
    imagesc(ax, tMat, [-tMax, tMax]);
    colormap(ax, diverging_tval_colormap(256));
    set(ax, 'Color', bgColor);

    % (no divider between row-blocks - all rows sit flush/touching)

    % --- p-value text on every cell, always black (cells are colored,
    %     not the black figure background, so black stays readable) ---
    PVAL_TEXT_COLOR = [0 0 0];
    for r = 1:nRows
        for c = 1:nCols
            p = pMat(r, c);
            if isnan(p)
                cellStr = 'n/a';
            else
                cellStr = sprintf(['p = ' pvalFormat], p);
            end
            text(ax, c, r, cellStr, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', 'Color', PVAL_TEXT_COLOR, ...
                'FontSize', 10, 'FontWeight', 'bold');
        end
    end

    axis(ax, 'equal');
    xlim(ax, [0.5, nCols + 0.5]);
    ylim(ax, [0.5, nRows + 0.5]);
    set(ax, 'YDir', 'reverse');
    set(ax, 'XTick', 1:nCols, 'XTickLabel', colLabels, 'XAxisLocation', 'top', ...
        'FontSize', 12, 'FontWeight', 'bold');
    set(ax, 'YTick', 1:nRows, 'YTickLabel', rowLabels);
    set(ax, 'XColor', TEXT_COLOR, 'YColor', TEXT_COLOR);
    box(ax, 'off');

    title(ax, strrep(plotTitle, '_', ' '), 'Color', TEXT_COLOR, 'FontSize', 13);

    % --- row-block labels to the left of the monkey-letter rows ---
    for r = 1:nRows
        if ~isempty(rowGroupLabel{r})
            yCenter = r + (nMonkeysPerGroup - 1) / 2;
            text(ax, 0.5 - 0.15*nCols, yCenter, rowGroupLabel{r}, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
                'Color', TEXT_COLOR, 'FontSize', 12, 'FontWeight', 'bold', ...
                'Interpreter', 'tex');
        end
    end

    % --- colorbar, no outline/border ---
    cb = colorbar(ax);
    cb.Label.String = 'Coefficient T-value';
    cb.Label.Color = TEXT_COLOR;
    cb.Color = TEXT_COLOR;
    cb.Label.FontSize = 11;
    cb.Label.FontWeight = 'bold';
    cb.Box = 'off';

    hold(ax, 'off');
end