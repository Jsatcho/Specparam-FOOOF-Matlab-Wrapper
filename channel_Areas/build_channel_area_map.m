% ======================================================================
%  build_channel_area_map.m
%
%  Builds ONE stable name-keyed channel->area map per session, per
%  monkey, and saves it. This is the new single source of truth for
%  "what area is channel X in" - everything downstream (GLM merge,
%  PCC merge, any future script) should look channels up BY NAME
%  against this map, never by position against ChanAreas directly.
%
%  SOURCE OF TRUTH FOR ORDER:
%   Z:\users\Jeremiah\<M|N>\<key>\<key>_ChannelOrder.mat  ('ChannelOrder',
%   an Nx1 cell array), written by the patched ap_reward_analysis.m at
%   the exact moment fieldnames(data.NEURO.LFP) was computed - the same
%   order ChanAreas{s} is assumed to have been built from.
%
%   FALLBACK (sessions run BEFORE the patch, so no ChannelOrder.mat
%   exists yet): reload the raw input file and recompute
%   fieldnames(data.NEURO.LFP) directly. This reproduces the exact same
%   computation ap_reward_analysis.m originally did, so it's reliable -
%   UNLIKE reconstructing order from dir() or fieldnames(session), which
%   are not guaranteed to match ChanAreas{s}'s original ordering.
%   Every fallback use is logged so you can spot-check it.
%
%  OUTPUT LAYOUT (per monkey):
%    AreaMap.<sessionkey>.ACC         = {'AD01','AD05',...}   cell array
%    AreaMap.<sessionkey>.OFC         = {'AD02','AD07',...}
%    AreaMap.<sessionkey>.Unassigned  = {'AD03',...}   (NaN or any code
%                                         that isn't 1 (ACC) or 5 (OFC))
%
%  Saved to:
%    Z:\users\Jeremiah\M\M_channel_area_map.mat   (struct 'AreaMap')
%    Z:\users\Jeremiah\N\N_channel_area_map.mat   (struct 'AreaMap')
% ======================================================================

output_base_M = "Z:\users\Jeremiah\M";
output_base_N = "Z:\users\Jeremiah\N";
input_folder  = "D:\Jeremiah_data";   % only used by the fallback path

MChanAreas = load("C:\Users\Jeremiah Satcho\Desktop\NYU_SURP\Jeremiah_Erin_MATLAB\channel_Areas\MChanAreas.mat");
MChanAreas = MChanAreas.areas;
NChanAreas = load("C:\Users\Jeremiah Satcho\Desktop\NYU_SURP\Jeremiah_Erin_MATLAB\channel_Areas\NChanAreas.mat");
NChanAreas = NChanAreas.areas;

monkeys = {'M', 'N'};
output_bases = {output_base_M, output_base_N};
chan_areas_by_monkey = {MChanAreas, NChanAreas};

for m = 1:numel(monkeys)
    monkey_letter = monkeys{m};
    base = output_bases{m};
    ChanAreas = chan_areas_by_monkey{m};

    AreaMap = struct();

    d = dir(base);
    d = d([d.isdir] & ~ismember({d.name}, {'.', '..'}));
    session_folders = d(startsWith({d.name}, monkey_letter));

    fprintf('Monkey %s: %d session folders.\n', monkey_letter, numel(session_folders));

    for s = 1:numel(session_folders)
        key = session_folders(s).name;
        session_folder = fullfile(base, key);
        validKey = matlab.lang.makeValidName(key);

        if s > numel(ChanAreas)
            warning('%s: no ChanAreas entry for session index %d (only %d sessions in ChanAreas). Skipping.', ...
                key, s, numel(ChanAreas));
            continue
        end
        currChanAreas = ChanAreas{s};

        % ---- get ordered channel name list ----
        order_file = fullfile(session_folder, sprintf('%s_ChannelOrder.mat', key));
        if isfile(order_file)
            L = load(order_file);
            channelOrder = L.ChannelOrder;
        else
            % FALLBACK: reload raw file and recompute the same way
            % ap_reward_analysis.m originally did. Logged so it can be
            % audited - this session was processed before the patch.
            raw_file = fullfile(input_folder, sprintf('%s.mat', key));
            if ~isfile(raw_file)
                warning('%s: no ChannelOrder.mat AND no raw file found at %s. Skipping session (cannot build map).', ...
                    key, raw_file);
                continue
            end
            fprintf('  [fallback] %s: no ChannelOrder.mat, reconstructing from raw file.\n', key);
            raw = load(raw_file);
            if ~isfield(raw, 'data') || ~isfield(raw.data, 'NEURO') || ~isfield(raw.data.NEURO, 'LFP')
                warning('%s: raw file missing data.NEURO.LFP. Skipping session.', key);
                continue
            end
            channelOrder = fieldnames(raw.data.NEURO.LFP);
            clear raw
        end

        MAX_TRAILING_SLACK = 2;   % how many extra trailing channels we'll auto-resolve as Unassigned

        countDiff = numel(channelOrder) - numel(currChanAreas);

        if countDiff < 0
            % ChanAreas has MORE entries than we have raw channels - a
            % different, more ambiguous failure (which area code doesn't
            % correspond to a real channel?). No positional evidence to
            % safely guess here, so this direction still skips entirely.
            warning(['%s: channel count mismatch - ChannelOrder has %d channels, ' ...
                'ChanAreas{%d} has %d entries (MORE area codes than channels). ' ...
                'Skipping session (map would misalign, and direction of mismatch ' ...
                'gives no safe way to resolve automatically).'], ...
                key, numel(channelOrder), s, numel(currChanAreas));
            continue
        elseif countDiff > MAX_TRAILING_SLACK
            warning(['%s: channel count mismatch - ChannelOrder has %d channels, ' ...
                'ChanAreas{%d} has %d entries (%d more channels than area codes, ' ...
                'exceeds MAX_TRAILING_SLACK=%d). Skipping session (too large a gap ' ...
                'to safely assume trailing-only, unlike the confirmed N0110/N0113 pattern).'], ...
                key, numel(channelOrder), s, numel(currChanAreas), countDiff, MAX_TRAILING_SLACK);
            continue
        elseif countDiff > 0
            % Small trailing-only gap - matches the confirmed N0110/N0113
            % pattern (AD01..AD15 line up exactly with ChanAreas 1:15,
            % only the LAST channel(s) have no corresponding entry).
            % Positions 1:numel(currChanAreas) are trusted as normal;
            % anything past that is explicitly marked Unassigned rather
            % than guessed at or silently dropped.
            warning(['%s: ChannelOrder has %d more channel(s) than ChanAreas{%d} ' ...
                '(%d vs %d). Assigning positions 1:%d normally and marking the ' ...
                'trailing %d channel(s) (%s) as Unassigned.'], ...
                key, countDiff, s, numel(channelOrder), numel(currChanAreas), ...
                numel(currChanAreas), countDiff, strjoin(channelOrder(end-countDiff+1:end), ', '));
        end

        accList = {};
        ofcList = {};
        unassignedList = {};

        for c = 1:numel(channelOrder)
            chName = channelOrder{c};
            if c > numel(currChanAreas)
                unassignedList{end+1} = chName; %#ok<AGROW>
                continue
            end
            code = currChanAreas(c);
            if isnan(code)
                unassignedList{end+1} = chName; %#ok<AGROW>
            elseif code == 1
                accList{end+1} = chName; %#ok<AGROW>
            elseif code == 5
                ofcList{end+1} = chName; %#ok<AGROW>
            else
                unassignedList{end+1} = chName; %#ok<AGROW>
            end
        end

        AreaMap.(validKey).ACC = accList;
        AreaMap.(validKey).OFC = ofcList;
        AreaMap.(validKey).Unassigned = unassignedList;

        fprintf('  %s: %d ACC, %d OFC, %d unassigned (%d total channels)\n', ...
            key, numel(accList), numel(ofcList), numel(unassignedList), numel(channelOrder));
    end

    save(fullfile(base, sprintf('%s_channel_area_map.mat', monkey_letter)), 'AreaMap');
    fprintf('Saved %s\n', fullfile(base, sprintf('%s_channel_area_map.mat', monkey_letter)));
end