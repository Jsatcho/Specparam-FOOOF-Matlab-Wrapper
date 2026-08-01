% Load monkey glm data
M = load("Z:\users\Jeremiah\M\M_glm_results.mat");
M = M.M;
N = load("Z:\users\Jeremiah\N\N_glm_results.mat");
N = N.N;
Monkeys = struct();
Monkeys.M = M;
Monkeys.N = N;
monkeyNames = fieldnames(Monkeys);

% Load Channel-Area maps
MChanAreas = load("C:\Users\Jeremiah Satcho\Desktop\NYU_SURP\Jeremiah_Erin_MATLAB\channel_Areas\MChanAreas.mat");
MChanAreas = MChanAreas.areas;
NChanAreas = load("C:\Users\Jeremiah Satcho\Desktop\NYU_SURP\Jeremiah_Erin_MATLAB\channel_Areas\NChanAreas.mat");
NChanAreas = NChanAreas.areas;

ChanAreasByMonkey = struct();
ChanAreasByMonkey.MChanAreas = MChanAreas;
ChanAreasByMonkey.NChanAreas = NChanAreas;
MonkeyChanAreas = fieldnames(ChanAreasByMonkey);

% for each session for a monkey, organize channel data by brain region
for i = 1:2
    monkey = Monkeys.(monkeyNames{i});
    ChanAreas = ChanAreasByMonkey.(MonkeyChanAreas{i});
    sessions = fieldnames(monkey);
    for s = 1:numel(sessions)
        session = monkey.(sessions{s});
        channels = fieldnames(session);
        channels = channels(startsWith(channels, 'AD0'));
        currChanAreas = ChanAreas{s};
        % create ACC & OFC structure

        brainAreas = struct();
        brainAreas.ACC = struct();
        brainAreas.OFC = struct();


        brainAreaNames = fieldnames(brainAreas);
        for ba = 1:numel(brainAreaNames)
            tempBrainArea = struct();
            tempBrainArea.aperiodic_exponent = struct();
            tempBrainArea.aperiodic_exponent.intercept = struct();
            tempBrainArea.aperiodic_exponent.intercept.coefficient = [];
            tempBrainArea.aperiodic_exponent.intercept.pValue = [];
            tempBrainArea.aperiodic_exponent.rewardsize = struct();
            tempBrainArea.aperiodic_exponent.rewardsize.coefficient = [];
            tempBrainArea.aperiodic_exponent.rewardsize.pValue = [];
            tempBrainArea.aperiodic_exponent.choiceornochoice = struct();
            tempBrainArea.aperiodic_exponent.choiceornochoice.coefficient = [];
            tempBrainArea.aperiodic_exponent.choiceornochoice.pValue = [];

            tempBrainArea.offset = struct();
            tempBrainArea.offset.intercept = struct();
            tempBrainArea.offset.intercept.coefficient = [];
            tempBrainArea.offset.intercept.pValue = [];
            tempBrainArea.offset.rewardsize = struct();
            tempBrainArea.offset.rewardsize.coefficient = [];
            tempBrainArea.offset.rewardsize.pValue = [];
            tempBrainArea.offset.choiceornochoice = struct();
            tempBrainArea.offset.choiceornochoice.coefficient = [];
            tempBrainArea.offset.choiceornochoice.pValue = [];

            brainAreas.(brainAreaNames{ba}) = tempBrainArea;
        end


        % process channel data for brain area
        for c = 1:numel(channels)
            fprintf('Session %s: %d channels in GLM results, %d entries in currChanAreas\n', ...
                    sessions{s}, numel(channels), numel(currChanAreas));
                disp(channels)
            if isnan(currChanAreas(c))
                continue;
            elseif currChanAreas(c) == 1 %ACC
                areaName = 'ACC';
            elseif currChanAreas(c) == 5 %OFC
                areaName = 'OFC';
            else
                continue; % area code is neither ACC (1) nor OFC (5) - not tracked
            end

            brainArea = brainAreas.(areaName);

            aperiodic_params = fieldnames(brainArea); % {'aperiodic_exponent','offset'}
            for ap = 1:numel(aperiodic_params)
                paramName = aperiodic_params{ap};

                % Guard against channels where this parameter's fitglm
                % call failed upstream (ap_reward_glm_analysis.m only
                % writes aperiodic_exponent/offset if that specific fit
                % succeeded - a channel can have one without the other).
                % Pad with NaN instead of erroring, so every channel
                % still contributes exactly one entry to every array,
                % keeping counts aligned with currChanAreas.
                if isfield(session.(channels{c}), paramName)
                    srcParam = session.(channels{c}).(paramName);
                    intCoef = srcParam.intercept.coefficient;
                    intP    = srcParam.intercept.pValue;
                    rsCoef  = srcParam.rewardsize.coefficient;
                    rsP     = srcParam.rewardsize.pValue;
                    chCoef  = srcParam.choiceornochoice.coefficient;
                    chP     = srcParam.choiceornochoice.pValue;
                else
                    intCoef = NaN; intP = NaN;
                    rsCoef  = NaN; rsP  = NaN;
                    chCoef  = NaN; chP  = NaN;
                end

                brainArea.(paramName).intercept.coefficient(end+1) = intCoef;
                brainArea.(paramName).intercept.pValue(end+1) = intP;
                brainArea.(paramName).rewardsize.coefficient(end+1) = rsCoef;
                brainArea.(paramName).rewardsize.pValue(end+1) = rsP;
                brainArea.(paramName).choiceornochoice.coefficient(end+1) = chCoef;
                brainArea.(paramName).choiceornochoice.pValue(end+1) = chP;
            end

            brainAreas.(areaName) = brainArea;
        end
        session.ACC = brainAreas.ACC;
        session.OFC = brainAreas.OFC;
        monkey.(sessions{s}) = session;
    end
    Monkeys.(monkeyNames{i}) = monkey;
end
M = Monkeys.M;
N = Monkeys.N;
%%
% backup Original file
copyfile("Z:\users\Jeremiah\M\M_glm_results.mat", "Z:\users\Jeremiah\M\M_glm_results_backup.mat");
copyfile("Z:\users\Jeremiah\N\N_glm_results.mat", "Z:\users\Jeremiah\N\N_glm_results_backup.mat");
% overwrite old file
save("Z:\users\Jeremiah\M\M_glm_results.mat", "M");
save("Z:\users\Jeremiah\N\N_glm_results.mat", "N");


%%Plot ACC vs OFC

% ======================================================================
%  plot_ACC_vs_OFC.m
%
%  Assumes M and N (the outputs of channelToBrainRegion.m) already
%  exist in the workspace, each with per-session .ACC / .OFC structs
%  containing:
%    <area>.aperiodic_exponent.rewardsize.coefficient / .pValue
%    <area>.aperiodic_exponent.choiceornochoice.coefficient / .pValue
%    <area>.offset.rewardsize.coefficient / .pValue
%    <area>.offset.choiceornochoice.coefficient / .pValue
%  each a 1xN vector, one entry per channel in that area for that
%  session (NaN where a channel's fit was missing upstream).
%
%  For each combination of:
%    parameter  = {'aperiodic_exponent', 'offset'}
%    predictor  = {'rewardsize', 'choiceornochoice'}
%  this produces ONE figure with a dot/strip plot: ACC vs OFC on the
%  x-axis, coefficient value on the y-axis, one dot per channel
%  (pooled across all sessions and both monkeys), colored by whether
%  that channel's p-value is significant (p < ALPHA).
%
%  Change ALPHA, or set POOL_MONKEYS = false to plot M and N separately,
%  as needed.
% ======================================================================

ALPHA = 0.05;
POOL_MONKEYS = true;   % true: combine M and N into one pooled dataset per area

parameters = {'aperiodic_exponent', 'offset'};
predictors = {'rewardsize', 'choiceornochoice'};

if POOL_MONKEYS
    monkeyGroups = struct('label', {'M+N'}, 'data', {{M, N}});
else
    monkeyGroups = struct('label', {'M', 'N'}, 'data', {{M}, {N}});
end

for g = 1:numel(monkeyGroups)
    groupLabel = monkeyGroups(g).label;
    monkeyStructs = monkeyGroups(g).data;

    for p = 1:numel(parameters)
        paramName = parameters{p};

        for r = 1:numel(predictors)
            predName = predictors{r};

            [accCoef, accP] = gather_values(monkeyStructs, 'ACC', paramName, predName);
            [ofcCoef, ofcP]  = gather_values(monkeyStructs, 'OFC', paramName, predName);

            plot_title = sprintf('%s - %s (%s)', paramName, predName, groupLabel);
            make_dot_plot(accCoef, accP, ofcCoef, ofcP, ALPHA, plot_title);
        end
    end
end


% ======================================================================
%  gather_values - pools a coefficient/pValue pair for one brain area,
%  one aperiodic parameter, one predictor, across every session in
%  every monkey struct passed in. NaN entries (channels whose fit was
%  missing upstream) are dropped here rather than plotted.
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

    % drop NaN entries (missing upstream fits) - keep coef/p paired
    validMask = ~isnan(coefOut) & ~isnan(pOut);
    coefOut = coefOut(validMask);
    pOut    = pOut(validMask);
end


% ======================================================================
%  make_dot_plot - draws one figure: ACC vs OFC on the x-axis (jittered
%  for visibility), coefficient value on the y-axis, colored by
%  significance (p < alpha). Also prints n and %significant per area
%  in the title/legend.
% ======================================================================
function make_dot_plot(accCoef, accP, ofcCoef, ofcP, alpha, plot_title)
    figure('Name', plot_title);
    hold on

    jitterWidth = 0.15;

    % ACC = x-position 1, OFC = x-position 2
    plot_group(1, accCoef, accP, alpha, jitterWidth);
    plot_group(2, ofcCoef, ofcP, alpha, jitterWidth);

    xlim([0.5 2.5]);
    set(gca, 'XTick', [1 2], 'XTickLabel', {'ACC', 'OFC'});
    ylabel('Coefficient');
    yline(0, 'k:');

    nAcc = numel(accCoef);
    nOfc = numel(ofcCoef);
    pctSigAcc = 100 * mean(accP < alpha);
    pctSigOfc = 100 * mean(ofcP < alpha);

    title({strrep(plot_title, '_', ' '), ...
        sprintf('ACC: n=%d, %.1f%% sig | OFC: n=%d, %.1f%% sig (p<%.2f)', ...
        nAcc, pctSigAcc, nOfc, pctSigOfc, alpha)});

    legend({sprintf('p < %.2f', alpha), sprintf('p \\geq %.2f', alpha)}, ...
        'Location', 'best');

    hold off
end


% ======================================================================
%  plot_group - scatters one area's points at a given x-position, with
%  horizontal jitter, splitting into significant (red) vs
%  non-significant (gray) markers.
% ======================================================================
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

    % dummy points for a clean legend (actual legend built in make_dot_plot)
    if xPos == 1
        scatter(NaN, NaN, 25, [0.85 0.1 0.1], 'filled');
        scatter(NaN, NaN, 25, [0.6 0.6 0.6], 'filled');
    end
end