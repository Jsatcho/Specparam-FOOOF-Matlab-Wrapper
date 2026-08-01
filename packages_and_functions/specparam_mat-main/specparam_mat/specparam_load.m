function specparam_results = specparam_load(file_name, file_path)

    %% --- Defaults ---
    if nargin < 2 || isempty(file_path)
        file_path = pwd;
    end

    if ~endsWith(file_name, '.json')
        file_name = [file_name, '.json'];
    end

    model_file = fullfile(file_path, file_name);

    if ~exist(model_file, 'file')
        error('File not found: %s', model_file);
    end

    %% --- Read file ---
    file_text = fileread(model_file);

    lines = splitlines(string(file_text));
    lines = lines(strlength(strtrim(lines)) > 0);

    %% --- Decide single model vs group ---
    if numel(lines) > 1
        specparam_results = load_specparam_group_json(lines);
    else
        specparam_results = load_specparam_model_json(file_text);
    end

end


% =========================================================================
% Load single model JSON
% =========================================================================
function results = load_specparam_model_json(file_text)

    obj = jsondecode(file_text);
    results = json_to_specparam_result(obj);

end


% =========================================================================
% Load group JSON
% =========================================================================
function results = load_specparam_group_json(lines)

    results = [];

    for i = 1:numel(lines)
        obj = jsondecode(lines(i));
        cur_results = json_to_specparam_result(obj);

        results = [results, cur_results];
    end

end


% =========================================================================
% Convert decoded JSON object back into specparam results struct
% =========================================================================
function results = json_to_specparam_result(obj)

    results = struct();

    %% Model outputs
    if isfield(obj, 'aperiodic_params')
        results.aperiodic_params = ensure_row(obj.aperiodic_params);
    else
        results.aperiodic_params = [];
    end

    if isfield(obj, 'peak_params')
        results.peak_params = ensure_matrix(obj.peak_params);
    else
        results.peak_params = [];
    end

    if isfield(obj, 'gaussian_params')
        results.gaussian_params = ensure_matrix(obj.gaussian_params);
    else
        results.gaussian_params = results.peak_params;
    end

    %% Metrics
    if isfield(obj, 'error')
        results.error = obj.error;
    elseif isfield(obj, 'metrics') && isfield(obj.metrics, 'error_mae')
        results.error = obj.metrics.error_mae;
    else
        results.error = [];
    end

    if isfield(obj, 'r_squared')
        results.r_squared = obj.r_squared;
    elseif isfield(obj, 'metrics') && isfield(obj.metrics, 'gof_rsquared')
        results.r_squared = obj.metrics.gof_rsquared;
    else
        results.r_squared = [];
    end

    %% Data
    if isfield(obj, 'freqs')
        results.freqs = ensure_row(obj.freqs);
    end

    if isfield(obj, 'power_spectrum')
        results.power_spectrum = ensure_row(obj.power_spectrum);
    end

    if isfield(obj, 'specparamed_spectrum')
        results.specparamed_spectrum = ensure_row(obj.specparamed_spectrum);
    end

    if isfield(obj, 'ap_fit')
        results.ap_fit = ensure_row(obj.ap_fit);
    end

    %% Settings
    settings = struct();

    if isfield(obj, 'peak_width_limits')
        settings.peak_width_limits = ensure_row(obj.peak_width_limits);
    else
        settings.peak_width_limits = [0.5, 12];
    end

    if isfield(obj, 'max_n_peaks')
        settings.max_n_peaks = obj.max_n_peaks;
    else
        settings.max_n_peaks = Inf;
    end

    if isfield(obj, 'min_peak_height')
        settings.min_peak_height = obj.min_peak_height;
    else
        settings.min_peak_height = 2.0;
    end

    if isfield(obj, 'peak_threshold')
        settings.peak_threshold = obj.peak_threshold;
    else
        settings.peak_threshold = 0;
    end

    if isfield(obj, 'aperiodic_mode')
        settings.aperiodic_mode = char(obj.aperiodic_mode);
    else
        settings.aperiodic_mode = 'default';
    end

    if isfield(obj, 'verbose')
        settings.verbose = obj.verbose;
    else
        settings.verbose = true;
    end

    results.settings = settings;

end


% =========================================================================
% Helper: force row vector
% =========================================================================
function out = ensure_row(x)

    out = double(x);
    out = out(:)';

end


% =========================================================================
% Helper: force matrix
% =========================================================================
function out = ensure_matrix(x)

    if isempty(x)
        out = [];
        return
    end

    out = double(x);

    if isvector(out)
        out = out(:)';

        if mod(numel(out), 3) == 0
            out = reshape(out, 3, numel(out) / 3)';
        end
    end

end