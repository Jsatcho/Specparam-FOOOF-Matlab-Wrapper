% ======================================================================
%  ap_reward_glm_analysis.m
%
%  Downstream of ap_reward_analysis.m. That script writes, per file key,
%  one <key>_<CHANNEL>.mat (channelData) and one <key>_BHV.mat (BHV) into
%  Z:\users\Jeremiah\M\<key>\ or Z:\users\Jeremiah\N\<key>\.
%
%  THIS VERSION:
%   - Each session (folder) is handled by one worker, and within that
%     worker, channel files are loaded ONE AT A TIME - fit, save the
%     row of results, discard, move to the next channel file.
%   - Every channel, in everysession, gets its own independent fitglm call.
%   - NESTED STRUCT PER MONKEY and saved as a single .mat file each:
%       Z:\users\Jeremiah\M\M_glm_results.mat   (variable "M")
%       Z:\users\Jeremiah\N\N_glm_results.mat   (variable "N")
%     with layout:
%       M.<file>.<channel>.aperiodic_exponent.rewardsize.pValue
%       M.<file>.<channel>.aperiodic_exponent.rewardsize.coefficient
%       M.<file>.<channel>.aperiodic_exponent.choiceornochoice.pValue
%       M.<file>.<channel>.aperiodic_exponent.choiceornochoice.coefficient
%       M.<file>.<channel>.aperiodic_exponent.intercept.pValue
%       M.<file>.<channel>.aperiodic_exponent.intercept.coefficient
%       M.<file>.<channel>.offset.rewardsize.pValue
%       M.<file>.<channel>.offset.rewardsize.coefficient
%       M.<file>.<channel>.offset.choiceornochoice.pValue
%       M.<file>.<channel>.offset.choiceornochoice.coefficient
%       M.<file>.<channel>.offset.intercept.pValue
%       M.<file>.<channel>.offset.intercept.coefficient
%     (and same layout under N for monkey N). <file> and <channel> are
%     sanitized with matlab.lang.makeValidName since they're used as
%     struct field names.
%   - Parallelized with parfor across session folders (both M and N),
%     since folders are the natural independent unit of work here.
%     Each worker returns a small per-session struct (not CSVs); the
%     per-monkey struct is assembled serially after the parfor loop.
%
%  REWARD SIZE ENCODING:
%   RewardSize is fit as a CONTINUOUS predictor, centered by subtracting
%   2.5from the raw 1-4 values, since 2.5 is the actual
%   midpoint of that range - so RewardSize ends up as -1.5/-0.5/0.5/1.5,
%   genuinely centered on 0. Choice is recoded to -1/+1.
% ======================================================================

% ======================================================================
%  ap_reward_glm_analysis.m
%
%  Downstream of ap_reward_analysis.m. See original header comments for
%  full pipeline description. This version additionally: writes a
%  NaN-padded placeholder entry for every channel FILE FOUND ON DISK,
%  even if that channel's fit fails or is skipped, instead of omitting
%  it from the output struct entirely. A SkipReason field records why.
% ======================================================================

output_base_M = "Z:\users\Jeremiah\M";
output_base_N = "Z:\users\Jeremiah\N";

CHANNELS_OF_INTEREST = {};   % e.g. {'LFP01','LFP02','LFP03'}
MIN_TRIALS_PER_CHANNEL = 10;

sessions = list_session_folders(output_base_M, output_base_N);
n_sessions = numel(sessions);
fprintf('Found %d session folders to process.\n', n_sessions);

if n_sessions == 0
    fprintf('Nothing to do. Exiting.\n');
    return
end

if isempty(gcp('nocreate'))
    c = parcluster('Processes');
    c.NumWorkers = 8;
    parpool(c, 8);
end

status = cell(1, n_sessions);
sessionData = cell(1, n_sessions);

parfor s = 1:n_sessions
    [status{s}, sessionData{s}] = process_one_session_glm(sessions(s), CHANNELS_OF_INTEREST, MIN_TRIALS_PER_CHANNEL);
end

fprintf('\n  --- Run summary ---\n');
for s = 1:n_sessions
    fprintf('%s: %s\n', sessions(s).key, status{s});
end

M = struct(); %#ok<NASGU>
N = struct(); %#ok<NASGU>

for s = 1:n_sessions
    validKey = matlab.lang.makeValidName(sessions(s).key);
    if isempty(fieldnames(sessionData{s}))
        continue
    end
    switch sessions(s).monkey
        case 'M'
            M.(validKey) = sessionData{s};
        case 'N'
            N.(validKey) = sessionData{s};
    end
end

if ~exist(output_base_M, 'dir')
    mkdir(output_base_M);
end
if ~exist(output_base_N, 'dir')
    mkdir(output_base_N);
end

save(fullfile(output_base_M, 'M_glm_results.mat'), 'M');
save(fullfile(output_base_N, 'N_glm_results.mat'), 'N');

fprintf('\nSaved %s\n', fullfile(output_base_M, 'M_glm_results.mat'));
fprintf('Saved %s\n', fullfile(output_base_N, 'N_glm_results.mat'));

% ======================================================================
%  list_session_folders
% ======================================================================
function sessions = list_session_folders(output_base_M, output_base_N)

    sessions = struct('key', {}, 'folder', {}, 'monkey', {});
    bases = {output_base_M, output_base_N};

    for b = 1:numel(bases)
        base = bases{b};
        if ~exist(base, 'dir')
            continue
        end

        d = dir(base);
        d = d([d.isdir] & ~ismember({d.name}, {'.', '..'}));

        for i = 1:numel(d)
            key = d(i).name;
            monkey = key(1);
            if ~(monkey == 'M' || monkey == 'N')
                continue
            end
            sessions(end+1) = struct('key', key, 'folder', fullfile(base, key), 'monkey', monkey); %#ok<AGROW>
        end
    end
end

% ======================================================================
%  process_one_session_glm - every channel FILE FOUND ON DISK gets
%  exactly one entry in sessionChannels: NaN-padded by default,
%  overwritten with real coefficients only if the fit succeeds.
% ======================================================================
function [status_msg, sessionChannels] = process_one_session_glm(session, channels_of_interest, min_trials)

    key = session.key;
    folder = session.folder;
    sessionChannels = struct();

    bhv_file = fullfile(folder, sprintf('%s_BHV.mat', key));
    if ~isfile(bhv_file)
        status_msg = 'no BHV file found, skipped';
        return
    end

    S = load(bhv_file);
    BHV = S.BHV;
    clear S

    RewardSize = BHV.ChosenRewardSize(:) - 2.5;
    Choice = BHV.ChoiceOrNot(:);
    Choice(Choice == 0) = -1;
    n_trials = length(RewardSize);

    chan_files = dir(fullfile(folder, sprintf('%s_*.mat', key)));
    chan_files = chan_files(~endsWith({chan_files.name}, '_BHV.mat'));
    chan_files = chan_files(~endsWith({chan_files.name}, '_ChannelOrder.mat'));
    chan_files = chan_files(~strcmpi({chan_files.name}, 'COMPLETE.mat'));

    n_fit = 0;
    n_skipped = 0;

    for c = 1:numel(chan_files)
        cf = chan_files(c).name;
        channelName = cf(length(key)+2 : end-4);

        if ~isempty(channels_of_interest) && ~ismember(channelName, channels_of_interest)
            continue   % deliberate scope restriction - no placeholder
        end

        validChannel = matlab.lang.makeValidName(channelName);

        % default: NaN-padded placeholder, overwritten below only if the
        % fit actually succeeds
        sessionChannels.(validChannel).aperiodic_exponent = nan_coef_struct();
        sessionChannels.(validChannel).offset = nan_coef_struct();
        sessionChannels.(validChannel).SkipReason = '';

        Sc = load(fullfile(folder, cf));
        if ~isfield(Sc, 'channelData')
            sessionChannels.(validChannel).SkipReason = 'no channelData field in file';
            n_skipped = n_skipped + 1;
            continue
        end
        exponent = Sc.channelData.Aperiodic.Exponents(:);
        offset   = Sc.channelData.Aperiodic.Offsets(:);
        clear Sc

        if length(exponent) ~= n_trials
            warning('%s / %s: trial count mismatch (BHV=%d, channel=%d), skipping.', ...
                key, channelName, n_trials, length(exponent));
            sessionChannels.(validChannel).SkipReason = sprintf( ...
                'trial count mismatch (BHV=%d, channel=%d)', n_trials, length(exponent));
            n_skipped = n_skipped + 1;
            continue
        end

        Tg = table();
        Tg.RewardSize = RewardSize;
        Tg.Choice     = Choice;
        Tg.Exponent   = exponent;
        Tg.Offset     = offset;

        validRows = ~ismissing(Tg.RewardSize) & ~ismissing(Tg.Choice) & ...
                    ~ismissing(Tg.Exponent)   & ~ismissing(Tg.Offset);
        Tg = Tg(validRows, :);

        if height(Tg) < min_trials
            sessionChannels.(validChannel).SkipReason = sprintf( ...
                'too few valid trials (%d < %d)', height(Tg), min_trials);
            n_skipped = n_skipped + 1;
            continue
        end

        fit_ok = false;

        try
            mdl_exp = fitglm(Tg, 'Exponent ~ RewardSize + Choice');
            sessionChannels.(validChannel).aperiodic_exponent = extract_coef_struct(mdl_exp);
            fit_ok = true;
        catch ME
            warning('%s / %s: Exponent fitglm failed: %s', key, channelName, ME.message);
            sessionChannels.(validChannel).SkipReason = sprintf('Exponent fitglm failed: %s', ME.message);
        end

        try
            mdl_off = fitglm(Tg, 'Offset ~ RewardSize + Choice');
            sessionChannels.(validChannel).offset = extract_coef_struct(mdl_off);
            fit_ok = true;
        catch ME
            warning('%s / %s: Offset fitglm failed: %s', key, channelName, ME.message);
            prevReason = sessionChannels.(validChannel).SkipReason;
            newReason = sprintf('Offset fitglm failed: %s', ME.message);
            if isempty(prevReason)
                sessionChannels.(validChannel).SkipReason = newReason;
            else
                sessionChannels.(validChannel).SkipReason = [prevReason '; ' newReason];
            end
        end

        if fit_ok
            n_fit = n_fit + 1;
        else
            n_skipped = n_skipped + 1;
        end
    end

    status_msg = sprintf('%d channels fit, %d skipped', n_fit, n_skipped);
end


% ======================================================================
%  extract_coef_struct - pulls Intercept/RewardSize/Choice coefficients
%  (Estimate + pValue) out of a fitted GLM.
% ======================================================================
function s = extract_coef_struct(mdl)
    s = struct();
    s.intercept = struct('coefficient', NaN, 'pValue', NaN);
    s.rewardsize = struct('coefficient', NaN, 'pValue', NaN);
    s.choiceornochoice = struct('coefficient', NaN, 'pValue', NaN);

    coefNames = mdl.CoefficientNames;

    idxInt = find(strcmp(coefNames, '(Intercept)'), 1);
    if ~isempty(idxInt)
        s.intercept.coefficient = mdl.Coefficients.Estimate(idxInt);
        s.intercept.pValue      = mdl.Coefficients.pValue(idxInt);
    end

    idxRS = find(strcmp(coefNames, 'RewardSize'), 1);
    if ~isempty(idxRS)
        s.rewardsize.coefficient = mdl.Coefficients.Estimate(idxRS);
        s.rewardsize.pValue      = mdl.Coefficients.pValue(idxRS);
    end

    idxCh = find(strcmp(coefNames, 'Choice'), 1);
    if ~isempty(idxCh)
        s.choiceornochoice.coefficient = mdl.Coefficients.Estimate(idxCh);
        s.choiceornochoice.pValue      = mdl.Coefficients.pValue(idxCh);
    end

    s.N = mdl.NumObservations;
end

% ======================================================================
%  nan_coef_struct - same shape as extract_coef_struct's output, used
%  as the up-front default before a fit is attempted/succeeds.
% ======================================================================
function s = nan_coef_struct()
    s = struct();
    s.intercept = struct('coefficient', NaN, 'pValue', NaN);
    s.rewardsize = struct('coefficient', NaN, 'pValue', NaN);
    s.choiceornochoice = struct('coefficient', NaN, 'pValue', NaN);
    s.N = 0;
end