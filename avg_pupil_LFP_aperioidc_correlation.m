% ======================================================================
%  pupil_aperiodic_correlation.m
%
%  Correlates (Pearson) the raw average pupil size per trial against
%  the per-channel aperiodic exponent per trial, WITHIN each session,
%  for both monkeys.
%
%  INPUTS:
%   Z:\users\Jeremiah\M\M_average_pupil_data.mat   struct 'M'
%       M.<sessionkey>.AveragePupilSize   (n_trials x 1)
%   Z:\users\Jeremiah\N\N_average_pupil_data.mat   struct 'N'
%       N.<sessionkey>.AveragePupilSize   (n_trials x 1)
%
%   Z:\users\Jeremiah\M\<sessionkey>\<sessionkey>_<channelName>.mat   'channelData'
%       channelData.Aperiodic.Exponents   (n_trials x 1)
%   Z:\users\Jeremiah\N\<sessionkey>\<sessionkey>_<channelName>.mat   'channelData'
%
%  Channel discovery/order comes from dir()-listing each session's
%  per-channel .mat files (sorted however the OS returns them - not
%  re-derived from the raw data file). <channelName> is recovered by
%  stripping the "<sessionkey>_" prefix and ".mat" suffix from each
%  filename and used AS-IS (no matlab.lang.makeValidName pass), so it
%  matches the channel name ap_reward_analysis.m used verbatim when it
%  built that filename from fieldnames(data.NEURO.LFP).
%
%  Both vectors are trial-ordered (same NumTrials, same trial k), so
%  they are correlated directly index-for-index. Either vector can
%  contain NaN (missing pupil trial, skipped/unfit specparam trial) -
%  those trial indices are excluded pairwise via corr(...,'rows','complete').
%
%  OUTPUT:
%   Nested struct, one per monkey, mirroring the M/N pupil structs:
%     M.<sessionkey>.rawPupil_to_aperiodicExp_PCC.<channelName>.PCC
%     M.<sessionkey>.rawPupil_to_aperiodicExp_PCC.<channelName>.pValue
%     M.<sessionkey>.rawPupil_to_aperiodicExp_PCC.<channelName>.NPairs
%     M.<sessionkey>.rawPupil_to_aperiodicExp_PCC.<channelName>.NTotalTrials
%   (same layout for N)
%
%   Saved to:
%     Z:\users\Jeremiah\M\M_pupil_aperiodicExp_PCC.mat   (struct 'M')
%     Z:\users\Jeremiah\N\N_pupil_aperiodicExp_PCC.mat   (struct 'N')
% ======================================================================

pupil_base_M = "Z:\users\Jeremiah\M";
pupil_base_N = "Z:\users\Jeremiah\N";

monkeys = {'M', 'N'};
pupil_bases = {pupil_base_M, pupil_base_N};

PCC_FIELD = 'rawPupil_to_aperiodicExp_PCC';

M = struct();
N = struct();

n_correlations = 0;   % running count, for the summary print at the end

for m = 1:numel(monkeys)
    monkey_letter = monkeys{m};
    base_folder = pupil_bases{m};

    pupil_file = fullfile(base_folder, sprintf('%s_average_pupil_data.mat', monkey_letter));
    if ~isfile(pupil_file)
        warning('Pupil data file not found for monkey %s: %s. Skipping monkey.', monkey_letter, pupil_file);
        continue
    end

    pupil_loaded = load(pupil_file);
    if ~isfield(pupil_loaded, monkey_letter)
        warning('Variable "%s" not found inside %s. Skipping monkey.', monkey_letter, pupil_file);
        continue
    end
    pupil_struct = pupil_loaded.(monkey_letter);

    session_keys = fieldnames(pupil_struct);
    fprintf('Monkey %s: %d sessions with pupil data.\n', monkey_letter, numel(session_keys));

    for s = 1:numel(session_keys)
        key = session_keys{s};

        if ~isfield(pupil_struct.(key), 'AveragePupilSize')
            warning('%s (%s): no AveragePupilSize field. Skipping session.', monkey_letter, key);
            continue
        end
        pupil_vec = pupil_struct.(key).AveragePupilSize(:);

        session_folder = fullfile(base_folder, key);
        if ~isfolder(session_folder)
            warning('%s (%s): no session output folder found at %s. Skipping session (no channel data).', ...
                monkey_letter, key, session_folder);
            continue
        end

        channel_files = dir(fullfile(session_folder, sprintf('%s_*.mat', key)));
        channel_files = channel_files(~strcmpi({channel_files.name}, sprintf('%s_BHV.mat', key)));
        channel_files = channel_files(~strcmpi({channel_files.name}, 'COMPLETE.mat'));

        if isempty(channel_files)
            warning('%s (%s): no per-channel .mat files found in %s. Skipping session.', ...
                monkey_letter, key, session_folder);
            continue
        end

        for c = 1:numel(channel_files)
            chan_filename = channel_files(c).name;
            % strip "<key>_" prefix and ".mat" suffix to recover channel
            % name, used as-is (no makeValidName) so it matches the
            % upstream channel field name exactly.
            channel_name = chan_filename(length(key)+2:end-4);

            chan_data_loaded = load(fullfile(session_folder, chan_filename));
            if ~isfield(chan_data_loaded, 'channelData') ...
                    || ~isfield(chan_data_loaded.channelData, 'Aperiodic') ...
                    || ~isfield(chan_data_loaded.channelData.Aperiodic, 'Exponents')
                warning('%s (%s, %s): missing channelData.Aperiodic.Exponents. Skipping channel.', ...
                    monkey_letter, key, channel_name);
                continue
            end
            exponent_vec = chan_data_loaded.channelData.Aperiodic.Exponents(:);

            if length(exponent_vec) ~= length(pupil_vec)
                warning(['%s (%s, %s): trial count mismatch - pupil has %d trials, ' ...
                    'aperiodic exponent has %d trials. Skipping channel.'], ...
                    monkey_letter, key, channel_name, length(pupil_vec), length(exponent_vec));
                continue
            end

            n_total = length(pupil_vec);
            valid_pairs = ~isnan(pupil_vec) & ~isnan(exponent_vec);
            n_pairs = sum(valid_pairs);

            if n_pairs < 3
                warning('%s (%s, %s): only %d valid trial pairs (need >=3). Skipping channel.', ...
                    monkey_letter, key, channel_name, n_pairs);
                pcc_val = NaN;
                pval = NaN;
            else
                [pcc_val, pval] = corr(pupil_vec(valid_pairs), exponent_vec(valid_pairs), ...
                    'Type', 'Pearson');
            end

            % channel_name is used as-is (not re-sanitized), so the
            % output field name is identical to the channel name
            % extracted from the upstream filename/field name.
            pcc_entry = struct();
            pcc_entry.PCC = pcc_val;
            pcc_entry.pValue = pval;
            pcc_entry.NPairs = n_pairs;
            pcc_entry.NTotalTrials = n_total;

            if strcmp(monkey_letter, 'M')
                M.(key).(PCC_FIELD).(channel_name) = pcc_entry;
            else
                N.(key).(PCC_FIELD).(channel_name) = pcc_entry;
            end

            n_correlations = n_correlations + 1;
        end
    end
end

fprintf('\nComputed %d (session, channel) Pearson correlations.\n', n_correlations);

if ~exist(pupil_base_M, 'dir'); mkdir(pupil_base_M); end
if ~exist(pupil_base_N, 'dir'); mkdir(pupil_base_N); end

save(fullfile(pupil_base_M, 'M_pupil_aperiodicExp_PCC.mat'), 'M');
save(fullfile(pupil_base_N, 'N_pupil_aperiodicExp_PCC.mat'), 'N');
fprintf('Saved M/N PCC structs to %s and %s\n', pupil_base_M, pupil_base_N);