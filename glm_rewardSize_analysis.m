% ======================================================================
%  ap_reward_glm_analysis.m
%
%  Downstream of ap_reward_analysis.m. That script writes, per file key,
%  one <key>_<CHANNEL>.mat (channelData) and one <key>_BHV.mat (BHV) into
%  Z:\users\Jeremiah\M\<key>\ or Z:\users\Jeremiah\N\<key>\.
%
%  THIS VERSION:
%   - Never loads all channels/sessions into one big in-memory table.
%     Each session (folder) is handled by one worker, and within that
%     worker, channel files are loaded ONE AT A TIME - fit, save the
%     row of results, discard, move to the next channel file.
%   - Channels are NOT concatenated with each other, and sessions are
%     NOT concatenated with each other. Every channel, in every
%     session, gets its own independent fitglm call.
%   - Instead of per-session CSVs, results are collected into ONE
%     NESTED STRUCT PER MONKEY and saved as a single .mat file each:
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

output_base_M = "Z:\users\Jeremiah\M";
output_base_N = "Z:\users\Jeremiah\N";

% Restrict to specific channels of interest, or leave empty for "all
% channels found in each session folder".
CHANNELS_OF_INTEREST = {};   % e.g. {'LFP01','LFP02','LFP03'}

MIN_TRIALS_PER_CHANNEL = 10;  % skip a channel's fit if fewer valid trials than this

% ----------------------------------------------------------------------
% Build the list of session folders to process (one entry per <key>
% folder under output_base_M / output_base_N).
% ----------------------------------------------------------------------
sessions = list_session_folders(output_base_M, output_base_N);
n_sessions = numel(sessions);
fprintf('Found %d session folders to process.\n', n_sessions);

if n_sessions == 0
    fprintf('Nothing to do. Exiting.\n');
    return
end

% ----------------------------------------------------------------------
% Start a parallel pool (one worker per session folder in flight)
% ----------------------------------------------------------------------
if isempty(gcp('nocreate'))
    c = parcluster('Processes');
    c.NumWorkers = 8;
    parpool(c, 8);
end

status = cell(1, n_sessions);
sessionData = cell(1, n_sessions);   % each cell: struct of channel results for that session

parfor s = 1:n_sessions
    [status{s}, sessionData{s}] = process_one_session_glm(sessions(s), CHANNELS_OF_INTEREST, MIN_TRIALS_PER_CHANNEL);
end

fprintf('\n--- Run summary ---\n');
for s = 1:n_sessions
    fprintf('%s: %s\n', sessions(s).key, status{s});
end

% ----------------------------------------------------------------------
% Assemble per-monkey nested structs from the per-session results
% (done serially, outside parfor, since fieldnames are dynamic and
% we're just stitching small structs together here).
% ----------------------------------------------------------------------
M = struct(); %#ok<NASGU>
N = struct(); %#ok<NASGU>

for s = 1:n_sessions
    validKey = matlab.lang.makeValidName(sessions(s).key);
    if isempty(fieldnames(sessionData{s}))
        continue  % nothing was fit for this session, skip adding an empty entry
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
%  list_session_folders - lists every <key> subfolder under
%  output_base_M and output_base_N. Returns a struct array with
%  .key, .folder, .monkey for each session.
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
%  process_one_session_glm - handles ONE session folder:
%   1) Loads that session's BHV.mat once (RewardSize, Choice).
%   2) Loops over its channel files ONE AT A TIME - load, fit, discard.
%   3) Builds a struct of results, keyed by (sanitized) channel name:
%        sessionChannels.<channel>.aperiodic_exponent.rewardsize.pValue
%        sessionChannels.<channel>.aperiodic_exponent.rewardsize.coefficient
%        sessionChannels.<channel>.aperiodic_exponent.choiceornochoice.pValue
%        sessionChannels.<channel>.aperiodic_exponent.choiceornochoice.coefficient
%        sessionChannels.<channel>.aperiodic_exponent.intercept.pValue
%        sessionChannels.<channel>.aperiodic_exponent.intercept.coefficient
%        sessionChannels.<channel>.offset.rewardsize.pValue
%        sessionChannels.<channel>.offset.rewardsize.coefficient
%        sessionChannels.<channel>.offset.choiceornochoice.pValue
%        sessionChannels.<channel>.offset.choiceornochoice.coefficient
%        sessionChannels.<channel>.offset.intercept.pValue
%        sessionChannels.<channel>.offset.intercept.coefficient
%  Returns a short status string plus that struct (both memory-light,
%  parfor-friendly).
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

    RewardSize = BHV.ChosenRewardSize(:) - 2.5;  % center: 1-4 -> -1.5/-0.5/0.5/1.5
    Choice = BHV.ChoiceOrNot(:);
    Choice(Choice == 0) = -1;                    % no-choice -> -1, choice stays 1
    n_trials = length(RewardSize);

    chan_files = dir(fullfile(folder, sprintf('%s_*.mat', key)));
    chan_files = chan_files(~endsWith({chan_files.name}, '_BHV.mat'));
    chan_files = chan_files(~strcmpi({chan_files.name}, 'COMPLETE.mat'));

    n_fit = 0;
    n_skipped = 0;

    for c = 1:numel(chan_files)
        cf = chan_files(c).name;
        channelName = cf(length(key)+2 : end-4);   % strip "<key>_" prefix and ".mat"

        if ~isempty(channels_of_interest) && ~ismember(channelName, channels_of_interest)
            continue
        end

        validChannel = matlab.lang.makeValidName(channelName);

        % ---- load ONE channel file, use it, then let it go ----
        Sc = load(fullfile(folder, cf));
        if ~isfield(Sc, 'channelData')
            n_skipped = n_skipped + 1;
            continue
        end
        exponent = Sc.channelData.Aperiodic.Exponents(:);
        offset   = Sc.channelData.Aperiodic.Offsets(:);
        clear Sc

        if length(exponent) ~= n_trials
            warning('%s / %s: trial count mismatch (BHV=%d, channel=%d), skipping.', ...
                key, channelName, n_trials, length(exponent));
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
        end

        try
            mdl_off = fitglm(Tg, 'Offset ~ RewardSize + Choice');
            sessionChannels.(validChannel).offset = extract_coef_struct(mdl_off);
            fit_ok = true;
        catch ME
            warning('%s / %s: Offset fitglm failed: %s', key, channelName, ME.message);
        end

        if fit_ok
            n_fit = n_fit + 1;
        else
            n_skipped = n_skipped + 1;
        end
        % Tg, exponent, offset all go out of scope / get overwritten on
        % the next loop iteration - nothing channel-specific persists.
    end

    status_msg = sprintf('%d channels fit, %d skipped', n_fit, n_skipped);
end


% ======================================================================
%  extract_coef_struct - pulls the Intercept, RewardSize, and Choice
%  coefficients (Estimate + pValue) out of a fitted GLM and returns
%  them as:
%    s.intercept.coefficient / s.intercept.pValue
%    s.rewardsize.coefficient / s.rewardsize.pValue
%    s.choiceornochoice.coefficient / s.choiceornochoice.pValue
%    s.N  (number of observations used in the fit)
%  Missing coefficients (shouldn't normally happen given the fixed
%  formula) are left as NaN rather than erroring.
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