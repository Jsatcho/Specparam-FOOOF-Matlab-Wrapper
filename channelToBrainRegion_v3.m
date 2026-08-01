% ======================================================================
%  channelToBrainRegion_v3.m
%
%  Same as channelToBrainRegion_v2.m (name-keyed lookup against
%  <M|N>_channel_area_map.mat, driven by the TRUE channel list per area
%  rather than by which channels survived GLM fitting), extended to
%  also carry the two newer predictors - 'initialbar' and 'playedtr' -
%  added in ap_reward_glm_analysis_v2.m through into brainArea, in
%  addition to the existing intercept/rewardsize/choiceornochoice.
%
%  Without this, session.ACC/.OFC only ever had 3 of the 5 predictor
%  fields that extract_coef_struct actually produces upstream, so
%  plot_aperiodic_brain_region_v3.m's 'initialbar'/'playedtr' plots
%  would come back empty (gather_values' isfield check silently skips
%  missing fields rather than erroring).
% ======================================================================

% Load monkey glm data
M = load("Z:\users\Jeremiah\M\M_pupil_playedtr_initialbar_glm_results.mat");
M = M.M;
N = load("Z:\users\Jeremiah\N\N_pupil_playedtr_initialbar_glm_results.mat");
N = N.N;
Monkeys = struct();
Monkeys.M = M;
Monkeys.N = N;
monkeyNames = fieldnames(Monkeys);

% Load the name-keyed area maps (built by build_channel_area_map.m)
AreaMaps = struct();
AreaMaps.M = load("Z:\users\Jeremiah\M\M_channel_area_map.mat");
AreaMaps.M = AreaMaps.M.AreaMap;
AreaMaps.N = load("Z:\users\Jeremiah\N\N_channel_area_map.mat");
AreaMaps.N = AreaMaps.N.AreaMap;

for i = 1:2
    monkeyLetter = monkeyNames{i};
    monkey = Monkeys.(monkeyLetter);
    AreaMap = AreaMaps.(monkeyLetter);

    sessionKeys = fieldnames(monkey);

    for s = 1:numel(sessionKeys)
        key = sessionKeys{s};
        session = monkey.(key);

        if ~isfield(AreaMap, key)
            warning('%s (%s): no entry in channel area map. Skipping session.', monkeyLetter, key);
            continue
        end
        sessionMap = AreaMap.(key);

        % ---- init ACC/OFC output structs (same shape as before) ----
        brainAreas = struct();
        brainAreas.ACC = init_brain_area_struct();
        brainAreas.OFC = init_brain_area_struct();

        areaChannelLists = struct('ACC', {sessionMap.ACC}, 'OFC', {sessionMap.OFC});
        brainAreaNames = fieldnames(areaChannelLists);

        for ba = 1:numel(brainAreaNames)
            areaName = brainAreaNames{ba};
            channelList = areaChannelLists.(areaName);
            brainArea = brainAreas.(areaName);

            % ---- driven by the TRUE channel list for this area,
            % ---- not by which channels happened to survive GLM fitting ----
            for c = 1:numel(channelList)
                chName = channelList{c};
                validChannel = matlab.lang.makeValidName(chName);

                if isfield(session, validChannel)
                    channelResult = session.(validChannel);
                else
                    channelResult = struct();   % channel's fitglm failed entirely upstream
                end

                paramNames = fieldnames(brainArea);   % {'aperiodic_exponent','offset'}
                for ap = 1:numel(paramNames)
                    paramName = paramNames{ap};

                    if isfield(channelResult, paramName)
                        srcParam = channelResult.(paramName);
                        intCoef = srcParam.intercept.coefficient;
                        intP    = srcParam.intercept.pValue;
                        avgpCoef  = srcParam.avgpupil.coefficient;
                        avgpP     = srcParam.avgpupil.pValue;
                        ibCoef  = srcParam.initialbar.coefficient;
                        ibP     = srcParam.initialbar.pValue;
                        ptCoef  = srcParam.playedtr.coefficient;
                        ptP     = srcParam.playedtr.pValue;
                    else
                        intCoef = NaN; intP = NaN;
                        avgpCoef  = NaN; avgpP  = NaN;
                        ibCoef  = NaN; ibP  = NaN;
                        ptCoef  = NaN; ptP  = NaN;
                    end

                    brainArea.(paramName).intercept.coefficient(end+1) = intCoef;
                    brainArea.(paramName).intercept.pValue(end+1) = intP;
                    brainArea.(paramName).avgpupil.coefficient(end+1) = avgpCoef;
                    brainArea.(paramName).avgpupil.pValue(end+1) = avgpP;
                    brainArea.(paramName).initialbar.coefficient(end+1) = ibCoef;
                    brainArea.(paramName).initialbar.pValue(end+1) = ibP;
                    brainArea.(paramName).playedtr.coefficient(end+1) = ptCoef;
                    brainArea.(paramName).playedtr.pValue(end+1) = ptP;
                end
            end

            % keep the channel name list alongside the coefficients, so
            % every array index is traceable back to a channel name
            brainArea.ChannelNames = channelList;
            brainAreas.(areaName) = brainArea;
        end

        session.ACC = brainAreas.ACC;
        session.OFC = brainAreas.OFC;
        monkey.(key) = session;
    end

    Monkeys.(monkeyLetter) = monkey;
end

M = Monkeys.M;
N = Monkeys.N;

% overwrite old file
save("Z:\users\Jeremiah\M\M_pupil_playedtr_initialbar_glm_results.mat", "M");
save("Z:\users\Jeremiah\N\N_pupil_playedtr_initialbar_glm_results.mat", "N");


% ======================================================================
%  init_brain_area_struct - extended to include initialbar and
%  playedtr alongside the original intercept/rewardsize/
%  choiceornochoice fields, matching extract_coef_struct's output in
%  ap_reward_glm_analysis_v2.m.
% ======================================================================
function tempBrainArea = init_brain_area_struct()
    tempBrainArea = struct();
    tempBrainArea.aperiodic_exponent = struct();
    tempBrainArea.aperiodic_exponent.intercept = struct('coefficient', [], 'pValue', []);
    tempBrainArea.aperiodic_exponent.avgpupil = struct('coefficient', [], 'pValue', []);
    tempBrainArea.aperiodic_exponent.initialbar = struct('coefficient', [], 'pValue', []);
    tempBrainArea.aperiodic_exponent.playedtr = struct('coefficient', [], 'pValue', []);

    tempBrainArea.offset = struct();
    tempBrainArea.offset.intercept = struct('coefficient', [], 'pValue', []);
    tempBrainArea.offset.avgpupil = struct('coefficient', [], 'pValue', []);
    tempBrainArea.offset.initialbar = struct('coefficient', [], 'pValue', []);
    tempBrainArea.offset.playedtr = struct('coefficient', [], 'pValue', []);
end