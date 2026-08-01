ap_analysis = struct();
ap_analysis.M = struct();
ap_analysis.N = struct();

folder = "D:\Jeremiah_data";
files = dir(fullfile(folder,'*.mat'));
files = files(~startsWith({files.name}, '._'));   % filter macOS metadata files

exclude_list = {'NLFP_APs.mat', 'NLFPareas.mat', 'N_primsec_LFPprobeAPs.mat'};
keep_mask = true(1, length(files));
for i = 1:length(files)
    if any(strcmpi(files(i).name, exclude_list))
        keep_mask(i) = false;
    end
end
files = files(keep_mask);

n_files = length(files);
file_results = cell(1, n_files);

% specparam settings - defined once, passed into every worker
settings = struct();
settings.max_n_peaks = 6;
settings.peak_width_limits = [3 6];
settings.aperiodic_mode = 'fixed';
f_range = [1, 100];

% start parallel pool if not already running
if isempty(gcp('nocreate'))
    c = parcluster('Processes');
    c.NumWorkers = 8;
    parpool(c, 8);
end

tic

parfor file = 1:n_files
    filename = files(file).name;
    fprintf('Starting file %d/%d: %s\n', file, n_files, filename);
    file_results{file} = process_one_file(filename, folder, f_range, settings);
end

toc

% ------------------------------------------------------------------
% Serial pass: assign results into ap_analysis, generate plots/reports
% ------------------------------------------------------------------
for file = 1:n_files
    filename = files(file).name;
    fr = file_results{file};

    if isempty(fr)
        continue   % file was skipped (shouldn't happen post-filtering, but safe)
    end

    % Generate reports/plots now, serially, where figures actually work
    channelNames = fieldnames(fr.Channels);
    for ch = 1:length(channelNames)
        cd = fr.Channels.(channelNames{ch});
        if ~isempty(cd.SpecparamResults)
            plot_title = sprintf('%s - %s', filename, channelNames{ch});
            specparam_report(cd.SpecparamResults, false, plot_title);
            fr.Channels.(channelNames{ch}).Report = evalc('specparam_report(cd.SpecparamResults);');
        else
            fr.Channels.(channelNames{ch}).Report = sprintf('%s - %s: no valid trials, no report generated.', filename, channelNames{ch});
        end
        close all
    end

    key = filename(1:end-4);
    if filename(1,1) == 'M'
        ap_analysis.M.(key) = fr;
    elseif filename(1,1) == 'N'
        ap_analysis.N.(key) = fr;
    end
end


%  process_one_file - loads one .mat file, builds BHV vectors, and
%  fits specparam across all channels for that file. Designed to be
%  called from inside parfor: no plotting, no shared-state writes.
function fr = process_one_file(filename, folder, f_range, settings)

    data = load(fullfile(folder, filename));
    if ~isfield(data, 'data')
        warning('%s: no "data" field found, skipping (not a trial data file).', filename);
        fr = [];
        return
    end
    data = data.data;

    % Behavioral vectors 
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
        % otherwise picon(k) stays NaN - either no code 27, or trial was aborted (error 1/4/5)
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

    % Channels (serial within this file)
    LFPchannels = data.NEURO.LFP;
    channelNames = fieldnames(LFPchannels);
    all_channels = struct();

    for ch = 1:length(channelNames)
        channelData = process_one_channel(channelNames{ch}, LFPchannels.(channelNames{ch}), ...
            picon, filename, f_range, settings);
        all_channels.(channelNames{ch}) = channelData;
    end

    fr = struct();
    fr.BHV = BHV;
    fr.Channels = all_channels;

end


%  process_one_channel - windows LFP by trial, computes PSD, fits
%  specparam on valid (finite, positive) trials only, and maps results
%  back into picon-length vectors. No plotting - report/plot generation
%  is deferred to a serial pass after parfor completes.
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
    fprintf('%s: %d/%d trials have valid picon\n', filename, sum(~isnan(picon)), length(picon)); % check trials

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

    exps = NaN(n_trials,1);
    num_peaks = NaN(n_trials,1);
    aperiodic_offsets = NaN(n_trials,1);
    aperiodic_exps = NaN(n_trials,1);
    specparam_valid = [];

    if isempty(valid_idx)
        n_nan_in_psd = sum(any(~isfinite(PSD), 1));
        n_nonpos_in_psd = sum(any(PSD <= 0, 1));
        fprintf('%s, channel %s DIAGNOSTIC: %d/%d cols have NaN/Inf, %d/%d cols have <=0 power\n', ...
            filename, channelName, n_nan_in_psd, size(PSD,2), n_nonpos_in_psd, size(PSD,2));
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
    end

    aperiodic_params = struct();
    aperiodic_params.Offsets = aperiodic_offsets;
    aperiodic_params.Exponents = aperiodic_exps;

    channelData = struct();
    channelData.Aperiodic = aperiodic_params;
    channelData.NumberOfPeaks = num_peaks;
    %channelData.TrialLFPs = LFPperTrial;
    channelData.TrialFitted = valid_mask';
    channelData.NumSkippedTrials = n_skipped;
    channelData.NumNaNPiconTrials = n_nan_picon;
    channelData.SpecparamResults = specparam_valid;   % kept for serial report/plot pass
    
end