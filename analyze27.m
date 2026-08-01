% ======================================================================
%  scan_multiple_27s.m
%
%  Read-only scan over the same input files used by ap_reward_analysis.m.
%  For every trial in every file, checks whether code 27 appears more than
%  once in CodeNumbers2 (restricted to "complete" trials, i.e. TrialError
%  == 0 or == 6, matching the logic already in process_one_file). Does NOT
%  run any spectral/specparam analysis and does NOT write anything into
%  the M/N output trees - it only writes a summary CSV so you can pull up
%  the flagged files/trials for further analysis.
%
%  OUTPUT:
%   <status_folder>\multiple_27_report.csv
%   Columns: filename, trial, trial_error, n_code27, code27_times
% ======================================================================

input_folder = "D:\Jeremiah_data";
status_folder = "Z:\users\Jeremiah";   % where the report gets written

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

n_files = length(files);
fprintf('Scanning %d files for trials with multiple code-27 occurrences...\n', n_files);

% Collect results as rows to write out at the end
report_rows = {};  % each row: {filename, trial, trial_error, n_code27, code27_times_str}

for i = 1:n_files
    filename = files(i).name;
    fprintf('  [%d/%d] %s\n', i, n_files, filename);

    try
        loaded = load(fullfile(input_folder, filename));
    catch ME
        warning('%s: failed to load (%s). Skipping.', filename, ME.message);
        continue
    end

    if ~isfield(loaded, 'data')
        fprintf('    no "data" field found, skipped (not a trial data file)\n');
        continue
    end
    data = loaded.data;

    if ~isfield(data, 'NEURO') || ~isfield(data.NEURO, 'CodeNumbers2')
        fprintf('    missing NEURO.CodeNumbers2, skipped\n');
        continue
    end

    n_trials_this_file = length(data.NEURO.CodeNumbers2);

    for k = 1:n_trials_this_file
        trial_error = data.BHV.UserVars(k).TrialError;
        trial_complete = (trial_error == 0) || (trial_error == 6);

        if ~trial_complete
            continue
        end

        codes = data.NEURO.CodeNumbers2{k};
        idx = find(codes == 27);

        if length(idx) > 1
            times = data.NEURO.CodeTimes2{k}(idx);
            times_str = strjoin(string(times(:)'), ';');

            all_identical = all(times == times(1));
            time_spread = max(times) - min(times);   % 0 if all identical

            report_rows(end+1, :) = {filename, k, trial_error, length(idx), times_str, ...
                all_identical, time_spread}; %#ok<AGROW>

            fprintf('    trial %d: code 27 found %d times (error=%d), identical=%d, spread=%g\n', ...
                k, length(idx), trial_error, all_identical, time_spread);
        end
    end
end

fprintf('\nTotal flagged trials: %d\n', size(report_rows, 1));

% -------------------- Write CSV report --------------------
report_file = fullfile(status_folder, 'multiple_27_report.csv');
fid = fopen(report_file, 'w');
fprintf(fid, 'filename,trial,trial_error,n_code27,code27_times,all_identical,time_spread\n');
for r = 1:size(report_rows, 1)
    fprintf(fid, '%s,%d,%d,%d,"%s",%d,%g\n', report_rows{r,1}, report_rows{r,2}, ...
        report_rows{r,3}, report_rows{r,4}, report_rows{r,5}, report_rows{r,6}, report_rows{r,7});
end
fclose(fid);

n_flagged = size(report_rows, 1);
n_identical = sum(cell2mat(report_rows(:,6)));
n_different = n_flagged - n_identical;
fprintf('  -> %d had identical timestamps (harmless duplicates)\n', n_identical);
fprintf('  -> %d had genuinely different timestamps (worth reviewing)\n', n_different);

fprintf('Report written to: %s\n', report_file);