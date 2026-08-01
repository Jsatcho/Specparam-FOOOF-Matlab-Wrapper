% ======================================================================
%  channelToBrainRegion_v2.m
%
%  Replaces the positional-index version. Sorts GLM results into
%  ACC / OFC per session using a NAME-KEYED lookup against
%  <M|N>_channel_area_map.mat (built by build_channel_area_map.m),
%  instead of matching fieldnames(session){c} against ChanAreas{s}(c)
%  positionally.
%
%  IMPORTANT: the loop below is driven by AreaMap.<key>.ACC / .OFC -
%  i.e. the FULL true channel list for that area - NOT by
%  fieldnames(session) (the GLM survivors). This means a channel whose
%  fitglm call failed upstream (so it has no field in the GLM results
%  struct) still gets ONE NaN-padded entry here, same as the existing
%  "guard against missing paramName" logic already did for
%  aperiodic_exponent/offset individually. This is what actually fixes
%  your undercounts - the positional bug was compounding a real
%  missing-channel problem, but even with alignment fixed, counts would
%  still fall short if failed-fit channels aren't padded in. Driving
%  the loop off AreaMap fixes both at once.
% ======================================================================

% Load monkey glm data
M = load("Z:\users\Jeremiah\M\M_glm_results.mat");
M = M.M;
N = load("Z:\users\Jeremiah\N\N_glm_results.mat");
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

% backup original file
copyfile("Z:\users\Jeremiah\M\M_glm_results.mat", "Z:\users\Jeremiah\M\M_glm_results_backup.mat");
copyfile("Z:\users\Jeremiah\N\N_glm_results.mat", "Z:\users\Jeremiah\N\N_glm_results_backup.mat");

% overwrite old file
save("Z:\users\Jeremiah\M\M_glm_results.mat", "M");
save("Z:\users\Jeremiah\N\N_glm_results.mat", "N");


% ======================================================================
%  init_brain_area_struct - same field layout as the original script
% ======================================================================
function tempBrainArea = init_brain_area_struct()
    tempBrainArea = struct();
    tempBrainArea.aperiodic_exponent = struct();
    tempBrainArea.aperiodic_exponent.intercept = struct('coefficient', [], 'pValue', []);
    tempBrainArea.aperiodic_exponent.rewardsize = struct('coefficient', [], 'pValue', []);
    tempBrainArea.aperiodic_exponent.choiceornochoice = struct('coefficient', [], 'pValue', []);

    tempBrainArea.offset = struct();
    tempBrainArea.offset.intercept = struct('coefficient', [], 'pValue', []);
    tempBrainArea.offset.rewardsize = struct('coefficient', [], 'pValue', []);
    tempBrainArea.offset.choiceornochoice = struct('coefficient', [], 'pValue', []);
end