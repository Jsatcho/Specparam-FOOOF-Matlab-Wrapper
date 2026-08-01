function specparam_save(specparam_results, file_name, file_path, save_results, save_settings, save_data, graph_format)

    if nargin < 3 || isempty(file_path)
        file_path = pwd;
    end
    if nargin < 4 || isempty(save_results)
        save_results = true;
    end
    if nargin < 5 || isempty(save_settings)
        save_settings = true;
    end
    if nargin < 6 || isempty(save_data)
        save_data = true;
    end
    if nargin < 7 || isempty(graph_format)
        graph_format = 'pdf';
    end

    if ~exist(file_path, 'dir')
        mkdir(file_path);
    end
    
    if isstring(file_name)
        file_name = char(file_name);
    end

    if isstring(file_path)
        file_path = char(file_path);
    end

    model_file  = fullfile(file_path, [file_name, '_model.json']);
    report_file = fullfile(file_path, [file_name, '_report.txt']);
    graph_file  = fullfile(file_path, [file_name, '_graphs.', graph_format]);

    %% Save model JSON
    if numel(specparam_results) > 1
        save_specparam_group_json(specparam_results, model_file, save_results, save_settings, save_data);
    else
        save_specparam_model_json(specparam_results, model_file, save_results, save_settings, save_data);
    end

    %% Save report text
    report_text = evalc('specparam_report(specparam_results);');

    fid = fopen(report_file, 'w');
    fprintf(fid, '%s', report_text);
    fclose(fid);

    %% Save report figure
    specparam_report(specparam_results);

    if strcmpi(graph_format, 'pdf')
        exportgraphics(gcf, graph_file, 'ContentType', 'vector');
    else
        exportgraphics(gcf, graph_file, 'Resolution', 300);
    end

    fprintf('\nSaved model to:  %s\n', model_file);
    fprintf('Saved report to: %s\n', report_file);
    fprintf('Saved graph to:  %s\n\n', graph_file);

end


% =========================================================================
% Save single model JSON
% =========================================================================
function save_specparam_model_json(results, model_file, save_results, save_settings, save_data)

    obj = make_save_object(results, save_results, save_settings, save_data, true);

    json_text = jsonencode(obj, 'PrettyPrint', true);

    fid = fopen(model_file, 'w');
    fprintf(fid, '%s\n', json_text);
    fclose(fid);

end


% =========================================================================
% Save group JSON
% This saves one JSON object per line, like specparam / FOOOF group saves.
% =========================================================================
function save_specparam_group_json(results, model_file, save_results, save_settings, save_data)

    fid = fopen(model_file, 'w');

    for i = 1:numel(results)

        save_base = i == 1;
        obj = make_save_object(results(i), save_results, save_settings, save_data, save_base);

        json_text = jsonencode(obj);

        fprintf(fid, '%s\n', json_text);
    end

    fclose(fid);

end


% =========================================================================
% Build saveable object
% =========================================================================
function obj = make_save_object(results, save_results, save_settings, save_data, save_base)

    obj = struct();

    %% Base information
    if save_base

        if isfield(results, 'freqs') && ~isempty(results.freqs)
            obj.freqs = results.freqs;
            obj.freq_range = [results.freqs(1), results.freqs(end)];

            if numel(results.freqs) > 1
                obj.freq_res = results.freqs(2) - results.freqs(1);
            end
        end

        obj.aperiodic_mode = get_result_setting(results, 'aperiodic_mode', 'default');
        obj.periodic_mode = 'gaussian';
        obj.bands = struct();

    end

    %% Results
    if save_results

        if isfield(results, 'aperiodic_params')
            obj.aperiodic_params = results.aperiodic_params;
        end

        if isfield(results, 'peak_params')
            obj.peak_params = results.peak_params;
            obj.gaussian_params = results.peak_params;
        end

        if isfield(results, 'gaussian_params')
            obj.gaussian_params = results.gaussian_params;
        end

        metrics = struct();

        if isfield(results, 'error')
            metrics.error_mae = results.error;
            obj.error = results.error;
        end

        if isfield(results, 'r_squared')
            metrics.gof_rsquared = results.r_squared;
            obj.r_squared = results.r_squared;
        end

        obj.metrics = metrics;

    end

    %% Settings
    if save_settings

        settings = get_results_settings(results);

        obj.peak_width_limits = get_setting(settings, 'peak_width_limits', [0.5, 12]);
        obj.max_n_peaks = get_setting(settings, 'max_n_peaks', Inf);
        obj.min_peak_height = get_setting(settings, 'min_peak_height', 2.0);
        obj.peak_threshold = get_setting(settings, 'peak_threshold', 0);
        obj.aperiodic_mode = get_setting(settings, 'aperiodic_mode', 'default');

        if isfield(settings, 'verbose')
            obj.verbose = settings.verbose;
        else
            obj.verbose = true;
        end

    end

    %% Data
    if save_data

        if isfield(results, 'power_spectrum')
            obj.power_spectrum = results.power_spectrum;
        end

        if isfield(results, 'specparamed_spectrum')
            obj.specparamed_spectrum = results.specparamed_spectrum;
        end

        if isfield(results, 'ap_fit')
            obj.ap_fit = results.ap_fit;
        end

    end

end


% =========================================================================
% Get settings from results
% =========================================================================
function settings = get_results_settings(results)

    if isfield(results, 'settings') && ~isempty(results.settings)
        settings = results.settings;
    else
        settings = struct();
    end

end


% =========================================================================
% Get setting with default
% =========================================================================
function value = get_setting(settings, field_name, default_value)

    if isfield(settings, field_name) && ~isempty(settings.(field_name))
        value = settings.(field_name);
    else
        value = default_value;
    end

end


% =========================================================================
% Get setting directly from results
% =========================================================================
function value = get_result_setting(results, field_name, default_value)

    settings = get_results_settings(results);
    value = get_setting(settings, field_name, default_value);

end