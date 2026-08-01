% ======================================================================
%  ap_reward_analysis.m
%
%  Resumable, per-channel-saving version of the pipeline.
%
%  KEY DESIGN CHANGES vs. the in-memory version:
%   - Each channel's result is saved to its own .mat file AS SOON AS it
%     is computed, inside process_one_channel. Nothing large is held in
%     memory across the whole run anymore (no file_results accumulation,
%     no ap_analysis struct holding everything) - this also substantially
%     reduces the memory pressure that caused the earlier OOM crashes,
%     since results are flushed to disk per-channel instead of piling up.
%   - A file is considered "done" once a COMPLETE.mat marker exists in
%     its output folder. Files with this marker are skipped entirely on
%     the next run (never even loaded), which is what lets you resume
%     after a crash without redoing finished work.
%   - Within a not-yet-complete file, each channel is ALSO checked
%     individually: if that channel's output file already exists, it is
%     skipped. This means even a mid-file crash only costs you the
%     channels that hadn't finished yet, not the whole file.
%   - A snapshot list of files still remaining (as of the start of this
%     run) is written to a text file so you can see the queue at a
%     glance without re-deriving it by hand.
%
%  OUTPUT LAYOUT:
%   Z:\users\Jeremiah\M\<FILENAME>\<FILENAME>_<CHANNEL>.mat   (per channel)
%   Z:\users\Jeremiah\M\<FILENAME>\<FILENAME>_BHV.mat          (behavior)
%   Z:\users\Jeremiah\M\<FILENAME>\COMPLETE.mat                (marker)
%   (same under \N\ for N-prefixed files)
% ======================================================================

input_folder = "D:\Jeremiah_data";
output_base_M = "Z:\users\Jeremiah\M";
output_base_N = "Z:\users\Jeremiah\N";
status_folder = "Z:\users\Jeremiah";   % where the remaining-files snapshot is written

if ~exist(output_base_M, 'dir'); mkdir(output_base_M); end
if ~exist(output_base_N, 'dir'); mkdir(output_base_N); end
if ~exist(status_folder, 'dir'); mkdir(status_folder); end

files = dir(fullfile(input_folder,'*.mat'));
files = files(~startsWith({files.name}, '._'));   % filter macOS metadata files

exclude_list = {'NLFP_APs.mat', 'NLFPareas.mat', 'N_primsec_LFPprobeAPs.mat', 'N0203.mat'};
keep_mask = true(1, length(files));
for i = 1:length(files)
    if any(strcmpi(files(i).name, exclude_list))
        keep_mask(i) = false;
    end
end
files = files(keep_mask);

% ------------------------------------------------------------------
% Determine which files still need processing (skip anything with a
% COMPLETE marker already on disk) and write a snapshot of the queue.
% ------------------------------------------------------------------
n_all = length(files);
already_done = false(1, n_all);

for i = 1:n_all
    filename = files(i).name;
    key = filename(1:end-4);
    out_folder = get_output_folder(filename, key, output_base_M, output_base_N);
    marker = fullfile(out_folder, 'COMPLETE.mat');
    already_done(i) = isfile(marker);
end

files_to_process = files(~already_done);
n_files = length(files_to_process);

fprintf('%d files already complete, %d files remaining to process.\n', ...
    sum(already_done), n_files);

remaining_names = {files_to_process.name};
status_file = fullfile(status_folder, 'remaining_files.txt');
fid = fopen(status_file, 'w');
fprintf(fid, 'Remaining files as of %s:\n', datestr(now));
for i = 1:numel(remaining_names)
    fprintf(fid, '%s\n', remaining_names{i});
end
fclose(fid);
fprintf('Remaining-file list written to: %s\n', status_file);

if n_files == 0
    fprintf('Nothing left to process. Exiting.\n');
    return
end

% specparam settings - defined once, passed into every worker
settings = struct();
settings.max_n_peaks = 6;
settings.peak_width_limits = [3 6];
settings.aperiodic_mode = 'fixed';
f_range = [1, 100];

% start parallel pool if not already running
if isempty(gcp('nocreate'))
    c = parcluster('Processes');
    c.NumWorkers = 6;
    parpool(c, 6);% adjust based on your available RAM - see memory notes
end

tic

status = cell(1, n_files);   % lightweight per-file status only, not full results

parfor file = 1:n_files
    filename = files_to_process(file).name;
    fprintf('Starting file %d/%d: %s\n', file, n_files, filename);
    status{file} = process_one_file(filename, input_folder, output_base_M, output_base_N, f_range, settings);
end

toc

fprintf('\n--- Run summary ---\n');
for file = 1:n_files
    fprintf('%s: %s\n', files_to_process(file).name, status{file});
end


% ======================================================================
%  get_output_folder - determines the per-file output directory based
%  on whether the filename starts with M or N, WITHOUT needing to load
%  the file itself. Used both for the completion-marker check up front
%  and inside process_one_file.
% ======================================================================
function out_folder = get_output_folder(filename, key, output_base_M, output_base_N)
    if filename(1) == 'M'
        out_folder = fullfile(output_base_M, key);
    elseif filename(1) == 'N'
        out_folder = fullfile(output_base_N, key);
    else
        error('Filename "%s" does not start with M or N - cannot route to output folder.', filename);
    end
end


% ======================================================================
%  process_one_file - loads one .mat file, builds BHV vectors, and
%  processes each channel, SAVING EACH CHANNEL'S RESULT TO DISK
%  IMMEDIATELY rather than returning it. Skips channels whose output
%  file already exists (partial-crash resume), and skips the whole
%  file up front if a COMPLETE marker is already present.
%  Returns a short status string only (memory-light for parfor).
% ======================================================================
function status_msg = process_one_file(filename, input_folder, output_base_M, output_base_N, f_range, settings)

    key = filename(1:end-4);
    out_folder = get_output_folder(filename, key, output_base_M, output_base_N);

    marker = fullfile(out_folder, 'COMPLETE.mat');
    if isfile(marker)
        status_msg = 'already complete, skipped';
        return
    end

    if ~exist(out_folder, 'dir')
        mkdir(out_folder);
    end

    data = load(fullfile(input_folder, filename));
    if ~isfield(data, 'data')
        status_msg = 'no "data" field found, skipped (not a trial data file)';
        return
    end
    data = data.data;

    % -------------------- Behavioral vectors --------------------
    picon = NaN(data.NEURO.NumTrials,1);
    for k = 1:length(data.NEURO.CodeNumbers2)
        trial_error = data.BHV.UserVars(k).TrialError;  % 0 = correct, 6 = incorrect-but-complete
        trial_complete = (trial_error == 0) || (trial_error == 6);

        if ismember(27, data.NEURO.CodeNumbers2{k}) && trial_complete
            idx = find(data.NEURO.CodeNumbers2{k} == 27);
            if length(idx) > 1
                warning('%s, trial %d: code 27 found %d times even after TrialError filter (error=%d). Using first occurrence - flag for Erin.', ...
                    filename, k, length(idx), trial_error);
            end
            picon(k) = data.NEURO.CodeTimes2{k}(idx(1));
        end
    end

    rewsz = NaN(length(picon),2);
    for k = 1:length(picon)
        rewsz(k,:) = data.BHV.UserVars(k).RewardSize;
    end

    choicetrial = NaN(length(picon),1);
    for k = 1:length(picon)
        choicetrial(k) = data.BHV.UserVars(k).ChoiceTrial;
    end

    chosen = NaN(length(picon),1);
    for k = 1:length(picon)
        chosen(k) = data.BHV.UserVars(k).Chosen;
    end

    errors = NaN(size(picon));
    for k = 1:length(picon)
        errors(k) = data.BHV.UserVars(k).TrialError;
    end

    chosenrewsz = NaN(length(picon), 1);
    for k = 1:length(picon)
        if choicetrial(k)==0 && errors(k)==0
            chosenrewsz(k) = rewsz(k,1);
        elseif choicetrial(k)==1 && errors(k)==0
            chosenrewsz(k) = rewsz(k,chosen(k));
        end
    end

    BHV = struct();
    BHV.PiconEpochs = picon;
    BHV.ChoiceOrNot = choicetrial;
    BHV.ChosenRewardSize = chosenrewsz;
    BHV.RewardSizes = rewsz;

    % -------------------- Channels --------------------
    LFPchannels = data.NEURO.LFP;
    channelNames = fieldnames(LFPchannels);
    n_channels_done = 0;
    n_channels_skipped = 0;

    for ch = 1:length(channelNames)
        channel_out_file = fullfile(out_folder, sprintf('%s_%s.mat', key, channelNames{ch}));

        if isfile(channel_out_file)
            n_channels_skipped = n_channels_skipped + 1;
            continue   % this channel was already completed in a prior run
        end

        channelData = process_one_channel(channelNames{ch}, LFPchannels.(channelNames{ch}), ...
            picon, filename, f_range, settings);

        save_channel_result(channel_out_file, channelData);
        n_channels_done = n_channels_done + 1;
    end

    % -------------------- BHV, saved once per file --------------------
    bhv_file = fullfile(out_folder, sprintf('%s_BHV.mat', key));
    if ~isfile(bhv_file)
        save_bhv_result(bhv_file, BHV);
    end

    % -------------------- Completion marker --------------------
    % Only mark complete if every channel currently has an output file
    % (accounts for channels skipped this run because they were already
    % done in a previous partial run, plus channels just completed now).
    all_channels_present = true;
    for ch = 1:length(channelNames)
        channel_out_file = fullfile(out_folder, sprintf('%s_%s.mat', key, channelNames{ch}));
        if ~isfile(channel_out_file)
            all_channels_present = false;
            break
        end
    end

    if all_channels_present
        completed_at = datestr(now); %#ok<TNOW1,DATST>
        save(marker, 'completed_at');
        status_msg = sprintf('done (%d channels processed, %d already had results)', ...
            n_channels_done, n_channels_skipped);
    else
        status_msg = sprintf('incomplete (%d channels processed, %d skipped, some missing - will retry remaining next run)', ...
            n_channels_done, n_channels_skipped);
    end

end


% ======================================================================
%  save_channel_result / save_bhv_result - thin wrappers so save() can
%  be called with a variable name that matches what you'll load back
%  (avoids "cannot save variable with parfor-generated name" friction
%  and keeps the on-disk field name predictable: 'channelData'/'BHV').
% ======================================================================
function save_channel_result(filepath, channelData) %#ok<INUSD>
    save(filepath, 'channelData');
end

function save_bhv_result(filepath, BHV) %#ok<INUSD>
    save(filepath, 'BHV');
end


% ======================================================================
%  process_one_channel - windows LFP by trial, computes PSD, fits
%  specparam on valid (finite, positive) trials only, and maps results
%  back into picon-length vectors. Generates a text report (no live
%  plot window is needed/kept - any figure specparam_report opens is
%  closed immediately since we're running inside a parallel worker).
% ======================================================================
function channelData = process_one_channel(channelName, channel_data, picon, filename, f_range, settings)

    channel_len = length(channel_data);
    n_trials = length(picon);

    LFPperTrial = NaN(n_trials, 4000);
    n_skipped = 0;
    n_nan_picon = 0;

    for k = 1:n_trials
        if isnan(picon(k))
            n_nan_picon = n_nan_picon + 1;
            continue
        end

        win_start = picon(k) - 999;
        win_end   = picon(k) + 3000;

        if win_start < 1 || win_end > channel_len
            warning('%s, channel %s, trial %d: window [%d, %d] out of bounds (channel length %d). Skipping.', ...
                filename, channelName, k, win_start, win_end, channel_len);
            n_skipped = n_skipped + 1;
            continue
        end

        LFPperTrial(k,:) = channel_data(win_start:win_end);
    end

    TW = 6;
    K = 2*TW-1;
    params = struct();
    params.tapers = [TW K];
    params.Fs = 1000;
    params.fpass = [0 100];
    params.trialave = 0;
    [PSD, f] = mtspectrumc(LFPperTrial', params);
    f = f(:)';

    % isfinite catches NaN/Inf; PSD > 0 catches zero/negative power,
    % which crashes specparam's internal log10 even though it's finite
    valid_mask = all(isfinite(PSD), 1) & all(PSD > 0, 1);
    valid_idx  = find(valid_mask);

    num_peaks = NaN(n_trials,1);
    aperiodic_offsets = NaN(n_trials,1);
    aperiodic_exps = NaN(n_trials,1);
    specparam_valid = [];
    report_text = sprintf('%s - %s: no valid trials, no report generated.', filename, channelName);

    if isempty(valid_idx)
        warning('%s, channel %s: no valid trials to fit. Skipping specparam.', filename, channelName);
    else
        PSD_valid = PSD(:, valid_mask);
        specparam_valid = specparam_group(f, PSD_valid, f_range, settings);

        for i = 1:length(valid_idx)
            k = valid_idx(i);
            aperiodic_offsets(k) = specparam_valid(i).aperiodic_params(1);
            aperiodic_exps(k)    = specparam_valid(i).aperiodic_params(2);
            num_peaks(k)         = length(specparam_valid(i).peak_params);
        end

        plot_title = sprintf('%s - %s', filename, channelName);
        report_text = evalc('specparam_report(specparam_valid, false, plot_title);');
        close all   % close any figure(s) specparam_report opened - not needed/viewable inside a worker
    end

    aperiodic_params = struct();
    aperiodic_params.Offsets = aperiodic_offsets;
    aperiodic_params.Exponents = aperiodic_exps;

    channelData = struct();
    channelData.Aperiodic = aperiodic_params;
    channelData.NumberOfPeaks = num_peaks;
    channelData.TrialFitted = valid_mask';
    channelData.NumSkippedTrials = n_skipped;
    channelData.NumNaNPiconTrials = n_nan_picon;
    channelData.SpecparamResults = specparam_valid;
    channelData.Report = report_text;

end