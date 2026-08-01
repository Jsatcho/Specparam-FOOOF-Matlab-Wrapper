% ======================================================================
%  sanity_check_channel_counts.m
%
%  Run LAST, after: (1) patched ap_reward_glm_analysis.m has been
%  rerun fresh, (2) build_channel_area_map.m has produced
%  <M|N>_channel_area_map.mat, (3) channelToBrainRegion_v2.m has been
%  rerun on the fresh GLM output.
%
%  Checks two things:
%   1) COUNT INTEGRITY: for every session, does the merged output's
%      session.ACC/OFC.ChannelNames count match the area map's ACC/OFC
%      list count for that session? By construction (v2 script loops
%      off the area map) these should always match - if they don't,
%      something upstream was rerun out of order or a session is
%      missing from one file but not the other. Flags this immediately.
%   2) FIT COVERAGE: for every session/area, what fraction of channels
%      have a real (non-NaN) fit vs. a NaN-padded placeholder (fit
%      failed or channel missing)? Uses the SkipReason field added by
%      the ap_reward_glm_analysis.m patch to summarize WHY, so you can
%      see if failures cluster around a particular reason (e.g. "too
%      few valid trials") rather than just seeing a raw NaN count.
%
%  Set EXPECTED_TOTALS below to your manually-counted numbers to get a
%  direct pass/fail against them; leave empty to just report totals.
% ======================================================================

% Optional: fill in with your manual counts to check against directly.
% Leave as [] to skip that comparison and just print totals.
EXPECTED_TOTALS = struct( ...
    'M', struct('ACC', 82,  'OFC', 256), ...
    'N', struct('ACC', 57,  'OFC', 224)  ...
);

output_base_M = "Z:\users\Jeremiah\M";
output_base_N = "Z:\users\Jeremiah\N";

monkeys = {'M', 'N'};
output_bases = {output_base_M, output_base_N};

for m = 1:numel(monkeys)
    monkeyLetter = monkeys{m};
    base = output_bases{m};

    glm_file = fullfile(base, sprintf('%s_glm_results.mat', monkeyLetter));
    map_file = fullfile(base, sprintf('%s_channel_area_map.mat', monkeyLetter));

    if ~isfile(glm_file) || ~isfile(map_file)
        warning('Monkey %s: missing %s or %s. Skipping.', monkeyLetter, glm_file, map_file);
        continue
    end

    G = load(glm_file);
    monkeyGLM = G.(monkeyLetter);
    A = load(map_file);
    AreaMap = A.AreaMap;

    fprintf('\n=== Monkey %s ===\n', monkeyLetter);

    totalACC_map = 0; totalOFC_map = 0;
    totalACC_glm = 0; totalOFC_glm = 0;

    accFitCount = 0; accFailCount = 0;
    ofcFitCount = 0; ofcFailCount = 0;
    failReasons = containers.Map('KeyType', 'char', 'ValueType', 'double');

    sessionKeys = fieldnames(AreaMap);   % area map is the ground-truth session list

    for s = 1:numel(sessionKeys)
        key = sessionKeys{s};
        mapACC = numel(AreaMap.(key).ACC);
        mapOFC = numel(AreaMap.(key).OFC);
        totalACC_map = totalACC_map + mapACC;
        totalOFC_map = totalOFC_map + mapOFC;

        if ~isfield(monkeyGLM, key)
            warning('%s (%s): session in area map but MISSING from GLM results entirely. ' , ...
                monkeyLetter, key);
            continue
        end
        session = monkeyGLM.(key);

        if isfield(session, 'ACC') && isfield(session.ACC, 'ChannelNames')
            glmACC = numel(session.ACC.ChannelNames);
        else
            glmACC = 0;
        end
        if isfield(session, 'OFC') && isfield(session.OFC, 'ChannelNames')
            glmOFC = numel(session.OFC.ChannelNames);
        else
            glmOFC = 0;
        end
        totalACC_glm = totalACC_glm + glmACC;
        totalOFC_glm = totalOFC_glm + glmOFC;

        if glmACC ~= mapACC
            warning('%s (%s): ACC count mismatch - map has %d, merged GLM output has %d.', ...
                monkeyLetter, key, mapACC, glmACC);
        end
        if glmOFC ~= mapOFC
            warning('%s (%s): OFC count mismatch - map has %d, merged GLM output has %d.', ...
                monkeyLetter, key, mapOFC, glmOFC);
        end

        % ---- fit coverage, using SkipReason on the raw per-channel entries ----
        channels = fieldnames(session);
        channels = channels(startsWith(channels, 'AD0'));  % adjust prefix filter if needed
        for c = 1:numel(channels)
            chField = channels{c};
            chData = session.(chField);
            if ~isfield(chData, 'SkipReason')
                continue   % pre-patch data slipped through somehow, nothing to report
            end

            inACC = ismember(chField, matlab.lang.makeValidName(AreaMap.(key).ACC));
            inOFC = ismember(chField, matlab.lang.makeValidName(AreaMap.(key).OFC));

            failed = ~isempty(chData.SkipReason);
            if failed
                reasonKey = chData.SkipReason;
                if isKey(failReasons, reasonKey)
                    failReasons(reasonKey) = failReasons(reasonKey) + 1;
                else
                    failReasons(reasonKey) = 1;
                end
            end

            if inACC
                if failed, accFailCount = accFailCount + 1; else, accFitCount = accFitCount + 1; end
            elseif inOFC
                if failed, ofcFailCount = ofcFailCount + 1; else, ofcFitCount = ofcFitCount + 1; end
            end
        end
    end

    fprintf('ACC: area-map total = %d, merged-output total = %d\n', totalACC_map, totalACC_glm);
    fprintf('OFC: area-map total = %d, merged-output total = %d\n', totalOFC_map, totalOFC_glm);

    if isfield(EXPECTED_TOTALS, monkeyLetter)
        exp = EXPECTED_TOTALS.(monkeyLetter);
        accStatus = 'MATCH'; if totalACC_map ~= exp.ACC, accStatus = 'MISMATCH'; end
        ofcStatus = 'MATCH'; if totalOFC_map ~= exp.OFC, ofcStatus = 'MISMATCH'; end
        fprintf('  vs expected ACC=%d: %s\n', exp.ACC, accStatus);
        fprintf('  vs expected OFC=%d: %s\n', exp.OFC, ofcStatus);
    end

    fprintf('ACC fit coverage: %d fit, %d failed (%.1f%% failed)\n', ...
        accFitCount, accFailCount, 100*accFailCount/max(1,accFitCount+accFailCount));
    fprintf('OFC fit coverage: %d fit, %d failed (%.1f%% failed)\n', ...
        ofcFitCount, ofcFailCount, 100*ofcFailCount/max(1,ofcFitCount+ofcFailCount));

    if failReasons.Count > 0
        fprintf('Failure reason breakdown:\n');
        reasonKeys = keys(failReasons);
        for r = 1:numel(reasonKeys)
            fprintf('  [%dx] %s\n', failReasons(reasonKeys{r}), reasonKeys{r});
        end
    end
end

%%
% ======================================================================
%  diagnose_channel_mismatch.m
%
%  For each flagged session (ChannelOrder count != ChanAreas{s} count),
%  prints the full channel name list side by side with what we can see
%  of the area codes, so you can visually spot which channel is the
%  "extra" one before deciding how to handle it. DOES NOT modify or
%  save anything - read-only diagnostic.
%
%  Edit MISMATCHED_SESSIONS below to match whatever the
%  build_channel_area_map.m warnings reported.
% ======================================================================

output_base_N = "Z:\users\Jeremiah\N";
input_folder  = "D:\Jeremiah_data";

NChanAreas = load("C:\Users\Jeremiah Satcho\Desktop\NYU_SURP\Jeremiah_Erin_MATLAB\channel_Areas\NChanAreas.mat");
NChanAreas = NChanAreas.areas;

% key = session folder name, chanAreasIndex = the {s} index reported in
% the warning (e.g. "ChanAreas{13}" -> 13)
MISMATCHED_SESSIONS = struct( ...
    'key', {'N0113', 'N0110'}, ...
    'chanAreasIndex', {13, 10} ...
);

for i = 1:numel(MISMATCHED_SESSIONS)
    key = MISMATCHED_SESSIONS(i).key;
    idx = MISMATCHED_SESSIONS(i).chanAreasIndex;

    fprintf('\n=== %s (ChanAreas{%d}) ===\n', key, idx);

    session_folder = fullfile(output_base_N, key);
    order_file = fullfile(session_folder, sprintf('%s_ChannelOrder.mat', key));

    if isfile(order_file)
        L = load(order_file);
        channelOrder = L.ChannelOrder;
        fprintf('(from saved ChannelOrder.mat)\n');
    else
        raw_file = fullfile(input_folder, sprintf('%s.mat', key));
        raw = load(raw_file);
        channelOrder = fieldnames(raw.data.NEURO.LFP);
        fprintf('(reconstructed from raw file - no ChannelOrder.mat found)\n');
        clear raw
    end

    currChanAreas = NChanAreas{idx};

    fprintf('ChannelOrder has %d channels. ChanAreas{%d} has %d entries.\n', ...
        numel(channelOrder), idx, numel(currChanAreas));

    fprintf('%-12s %s\n', 'Channel', 'AreaCode (blank = no corresponding entry)');
    for c = 1:numel(channelOrder)
        if c <= numel(currChanAreas)
            areaStr = num2str(currChanAreas(c));
        else
            areaStr = '(none - past end of ChanAreas)';
        end
        fprintf('%-12s %s\n', channelOrder{c}, areaStr);
    end

    % Also check for exact-duplicate channel names, which would point to
    % a genuine data artifact (e.g. a channel logged twice) rather than
    % a legitimately-new channel Erin's map never saw.
    [uniqueNames, ~, ic] = unique(channelOrder);
    counts = accumarray(ic, 1);
    dupes = uniqueNames(counts > 1);
    if ~isempty(dupes)
        fprintf('DUPLICATE channel names found: %s\n', strjoin(dupes, ', '));
    end
end

%%
% ======================================================================
%  diagnose_merge_nan_rate.m
%
%  Checks the ACTUAL merged data (session.ACC / session.OFC, written by
%  channelToBrainRegion_v2.m) directly - not a re-derived count. Since
%  those arrays always have length == numel(AreaMap.(key).ACC/OFC) by
%  construction (NaN-padded when a channel's isfield lookup fails),
%  matching totals prove NOTHING about correctness. This checks what
%  actually matters: how many of those slots are real numbers vs NaN,
%  per session, alongside the channel names so you can see exactly
%  which channels aren't being found.
% ======================================================================

MONKEY = 'N';
PARAM = 'aperiodic_exponent';   % or 'offset'
FIELD = 'intercept';            % or 'rewardsize' / 'choiceornochoice'

output_base = "Z:\users\Jeremiah\" + MONKEY;
glm_file = fullfile(output_base, sprintf('%s_glm_results.mat', MONKEY));

G = load(glm_file);
monkeyStruct = G.(MONKEY);
sessionKeys = fieldnames(monkeyStruct);

fprintf('%-10s %6s %8s %8s   %s\n', 'Session', 'Area', 'N', 'NumNaN', 'ChannelNames (first few NaN ones)');

for s = 1:numel(sessionKeys)
    key = sessionKeys{s};
    session = monkeyStruct.(key);

    for areaName = {'ACC', 'OFC'}
        areaName = areaName{1}; %#ok<FXSET>
        if ~isfield(session, areaName)
            continue
        end
        area = session.(areaName);
        if ~isfield(area, PARAM) || ~isfield(area.(PARAM), FIELD)
            continue
        end

        coefVec = area.(PARAM).(FIELD).coefficient;
        n = numel(coefVec);
        if n == 0
            continue
        end
        nanMask = isnan(coefVec);
        nNaN = sum(nanMask);

        namesStr = '';
        if isfield(area, 'ChannelNames') && nNaN > 0
            nanNames = area.ChannelNames(nanMask);
            showN = min(5, numel(nanNames));
            namesStr = strjoin(nanNames(1:showN), ', ');
            if numel(nanNames) > showN
                namesStr = [namesStr sprintf(' ... (+%d more)', numel(nanNames) - showN)];
            end
        end

        fprintf('%-10s %6s %8d %8d   %s\n', key, areaName, n, nNaN, namesStr);
    end
end