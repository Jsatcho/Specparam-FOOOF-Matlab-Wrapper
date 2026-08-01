% ======================================================================
%  average_pupil_size_extraction.m
%
%  Simple sequential pupil extraction pipeline (no parfor, no
%  resumable/marker logic). For each trial, computes picture-onset
%  time (picon) from code 27, same as the AP channel pipeline, removes
%  blinks from the raw eye-tracker analog channel, and averages the
%  1 second (500 samples @ 2ms) leading up to picon.
%
%  Unlike the AP channel pipeline, pupil is a single trace per session
%  (not per-LFP-channel), so results are NOT written one file per
%  session. Instead everything is aggregated into two structs, one per
%  monkey, each saved as a single .mat file:
%
%    M.<sessionkey>.AveragePupilSize   column vector, trial order
%    N.<sessionkey>.AveragePupilSize   column vector, trial order
%
%  Session keys are the filename (without .mat), sanitized with
%  matlab.lang.makeValidName so they're always legal struct fields.
%
%  BLINK REMOVAL: uses the raw-signal (<=0 dropout) threshold method.
%
%  UNIT CHECK: CodeTimes2 (picon) is confirmed to be real-integer
%  milliseconds, 1:1 with the 1000 Hz LFP trace used by the AP
%  pipeline. The eye/pupil channel is 500 Hz (2 ms/sample), so
%  ind = round(picon(k)/2) converts a millisecond timestamp into a
%  sample index for that channel. An assertion enforces the
%  integer-ms assumption so this fails loudly instead of silently
%  misbehaving if a future session file has non-integer codes.
%
%  OUTPUT:
%   Z:\users\Jeremiah\M\M_pupil_data.mat   contains struct 'M'
%   Z:\users\Jeremiah\N\N_pupil_data.mat   contains struct 'N'
% ======================================================================

input_folder = "D:\Jeremiah_data";
output_base_M = "Z:\users\Jeremiah\M";
output_base_N = "Z:\users\Jeremiah\N";

if ~exist(output_base_M, 'dir'); mkdir(output_base_M); end
if ~exist(output_base_N, 'dir'); mkdir(output_base_N); end

files = dir(fullfile(input_folder,'*.mat'));
files = files(~startsWith({files.name}, '._'));

exclude_list = {'NLFP_APs.mat', 'NLFPareas.mat', 'N_primsec_LFPprobeAPs.mat', 'N0203.mat'};
keep_mask = true(1, length(files));
for i = 1:length(files)
    if any(strcmpi(files(i).name, exclude_list))
        keep_mask(i) = false;
    end
end
files = files(keep_mask);

n_files = length(files);
fprintf('Processing %d files for pupil extraction.\n', n_files);

M = struct();
N = struct();
status = cell(1, n_files);

tic
for file = 1:n_files
    filename = files(file).name;
    fprintf('Processing file %d/%d: %s\n', file, n_files, filename);

    [pupil_result, status{file}] = process_one_file_pupil(filename, input_folder);

    if isempty(pupil_result)
        continue
    end

    key = matlab.lang.makeValidName(filename(1:end-4));

    if filename(1) == 'M'
        M.(key).AveragePupilSize = pupil_result.PupilSize;
    elseif filename(1) == 'N'
        N.(key).AveragePupilSize = pupil_result.PupilSize;
    else
        error('Filename "%s" does not start with M or N - cannot route to monkey struct.', filename);
    end
end
toc

fprintf('\n--- Pupil run summary ---\n');
for file = 1:n_files
    fprintf('%s: %s\n', files(file).name, status{file});
end

save(fullfile(output_base_M, 'M_average_pupil_data.mat'), 'M');
save(fullfile(output_base_N, 'N_average_pupil_data.mat'), 'N');
fprintf('Saved aggregated pupil structs.\n');


% ======================================================================
%  process_one_file_pupil - loads one session, computes picon from
%  code 27, extracts blink-cleaned pupil trace per trial, averages
%  the 1 second preceding picon. Returns a lightweight result struct
%  (PupilSize only, trial-ordered column vector) rather than writing
%  a file, so the caller can slot it into the aggregate M/N struct.
% ======================================================================
function [pupil_result, status_msg] = process_one_file_pupil(filename, input_folder)

    pupil_result = [];

    data = load(fullfile(input_folder, filename));
    if ~isfield(data, 'data')
        status_msg = 'no "data" field found, skipped (not a trial data file)';
        return
    end
    data = data.data;

    % -------------------- picture onset times (code 27) --------------------
    n_trials = data.NEURO.NumTrials;
    picon = NaN(n_trials, 1);
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

    % picon is assumed to be real-integer milliseconds (1:1 with the
    % 1000 Hz LFP trace in the AP pipeline). Fail loudly if that ever
    % stops being true rather than silently mis-indexing the eye trace.
    valid_picon = picon(~isnan(picon));
    assert(all(isreal(valid_picon)) && all(mod(valid_picon, 1) == 0), ...
        '%s: picon contains non-integer values - CodeTimes2 unit assumption (integer ms) is violated.', ...
        filename);

    % -------------------- pupil extraction --------------------
    pupilsize = NaN(n_trials, 1);
    n_skipped_bounds = 0;
    n_skipped_nan_picon = 0;
    n_skipped_missing_analog = 0;

    for k = 1:n_trials
        if isnan(picon(k))
            n_skipped_nan_picon = n_skipped_nan_picon + 1;
            continue
        end

        if numel(data.BHV.AnalogData) < k || isempty(data.BHV.AnalogData{1,k}) ...
                || ~isfield(data.BHV.AnalogData{1,k}, 'General') ...
                || ~isfield(data.BHV.AnalogData{1,k}.General, 'Gen1')
            warning('%s, trial %d: no AnalogData.General.Gen1 found. Skipping.', filename, k);
            n_skipped_missing_analog = n_skipped_missing_analog + 1;
            continue
        end

        eyedata = data.BHV.AnalogData{1,k}.General.Gen1;
        eyedata = remove_blinks_threshold(eyedata);

        n_samps = length(eyedata);

        % picon (from CodeTimes2) is an ABSOLUTE session-clock time in
        % ms, shared across all trials - that's fine for the AP
        % pipeline since the LFP channel is one continuous full-session
        % trace, but BHV.AnalogData{1,k} is trial-SEGMENTED (starts back
        % at sample 1 each trial). So picon must first be converted to
        % trial-relative time using that trial's own start code time,
        % before mapping to a sample index at 2 ms/sample (500 Hz).
        trial_start_time = data.NEURO.CodeTimes2{k}(1);
        picon_rel = picon(k) - trial_start_time;

        if picon_rel < 0
            warning('%s, trial %d: picon (%g) is before this trial''s first code time (%g). Skipping.', ...
                filename, k, picon(k), trial_start_time);
            n_skipped_bounds = n_skipped_bounds + 1;
            continue
        end

        ind = round(picon_rel / 2);

        if ind - 499 < 1 || ind > n_samps
            warning('%s, trial %d: pupil window [%d, %d] out of bounds (n_samps=%d). Skipping.', ...
                filename, k, ind - 499, ind, n_samps);
            n_skipped_bounds = n_skipped_bounds + 1;
            continue
        end

        pupilsize(k) = mean(eyedata(ind-499:ind), 'omitnan');
    end

    pupil_result = struct();
    pupil_result.PupilSize = pupilsize;   % 1 sec pre-picon average, trial order, column vector

    status_msg = sprintf('done (%d trials with pupil, %d nan picon, %d out of bounds, %d missing analog)', ...
        sum(~isnan(pupilsize)), n_skipped_nan_picon, n_skipped_bounds, n_skipped_missing_analog);
end


% ======================================================================
%  remove_blinks_threshold - raw-signal dropout removal (eyedata<=0).
%  Pads ~9-10 samples around the edges of each contiguous dropout run
%  to also remove the closing/opening transition, not just the
%  flat-zero segment itself.
% ======================================================================
function eyedata = remove_blinks_threshold(eyedata)
    eyedata = eyedata(:);
    x = find(eyedata <= 0);

    if isempty(x)
        return
    end

    removeblinks = (x(1)-10):(x(1)-1);
    for j = 2:length(x)
        if x(j) == x(j-1) + 1
            removeblinks = [removeblinks, x(j)]; %#ok<AGROW>
        else
            removeblinks = [removeblinks, (x(j-1)+1):(x(j-1)+9)]; %#ok<AGROW>
            removeblinks = [removeblinks, (x(j)-10):(x(j)-1), x(j)]; %#ok<AGROW>
        end
    end
    removeblinks = [removeblinks, (x(end)+1):(x(end)+9)];

    removeblinks = removeblinks(removeblinks >= 1 & removeblinks <= length(eyedata));

    eyedata(removeblinks) = NaN;
end

