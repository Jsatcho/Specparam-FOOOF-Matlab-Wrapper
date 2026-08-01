function specparam_report(specparam_results, log_freqs, plot_title)

    %% --- Defaults ---
    if ~exist('log_freqs', 'var') || isempty(log_freqs)
        log_freqs = false;
    end

    if ~exist('plot_title', 'var') || isempty(plot_title)
        plot_title = '';
    end

    if ~isstruct(specparam_results)
        error('specparam_results must be a struct or struct array.')
    end

    %% --- Single vs Group Report ---
    if numel(specparam_results) > 1
        specparam_group_print(specparam_results,plot_title);
        specparam_group_plot(specparam_results, plot_title);
    else

        if isfield(specparam_results, 'settings') && ~isempty(specparam_results.settings)
            settings = specparam_results.settings;
        else
            settings = struct();
        end

        if ~isfield(specparam_results, 'freqs')
            error('specparam results struct does not contain model output (missing freqs).')
        end

        specparam_print(specparam_results, settings, plot_title);
        specparam_plot(specparam_results, log_freqs, plot_title);
    end

end


% =========================================================================
%  specparam_print  -  Print single model report
% =========================================================================
function specparam_print(results, settings, plot_title)
    
    
    sep = repmat('=', 1, 78);
    fprintf('\n%s\n', sep);
    fprintf('%s\n', center_str(plot_title, 78));

    fprintf('%s\n', center_str('SPECTRUM MODEL RESULTS', 78));
    fprintf('\n');

    fprintf('%s\n', center_str('The model was fit with the ''spectral_fit'' algorithm', 78));

    freq_res = results.freqs(2) - results.freqs(1);
    fprintf('%s\n', center_str(sprintf('Model was fit to the %g-%g Hz frequency range with %.2f Hz resolution', ...
        results.freqs(1), results.freqs(end), freq_res), 78));
    fprintf('\n');

    %% Aperiodic parameters
    ap_mode = get_setting(settings, 'aperiodic_mode', 'default');
    ap = results.aperiodic_params;

    switch lower(ap_mode)

        case 'doublexp'
            fprintf('%s\n', center_str('Aperiodic Parameters (''doublexp'' mode)', 78));
            fprintf('%s\n', center_str('(offset, exponent_1, knee, exponent_2)', 78));
            ap_str = sprintf('%g, %g, %g, %g', ap(1), ap(2), ap(3), ap(4));

        case 'knee'
            fprintf('%s\n', center_str('Aperiodic Parameters (''knee'' mode)', 78));
            fprintf('%s\n', center_str('(offset, knee, exponent)', 78));
            ap_str = sprintf('%g, %g, %g', ap(1), ap(2), ap(3));

        otherwise
            fprintf('%s\n', center_str('Aperiodic Parameters (''default'' mode)', 78));
            fprintf('%s\n', center_str('(offset, exponent)', 78));
            ap_str = sprintf('%g, %g', ap(1), ap(2));
    end

    fprintf('%s\n\n', center_str(ap_str, 78));

    %% Peak parameters
    if isempty(results.peak_params)
        fprintf('%s\n', center_str('Peak Parameters (''gaussian'' mode) 0 peaks found', 78));
    else
        n_peaks = size(results.peak_params, 1);
        fprintf('%s\n', center_str(sprintf('Peak Parameters (''gaussian'' mode) %d peaks found', n_peaks), 78));

        for k = 1:n_peaks
            cf = results.peak_params(k, 1);
            pw = results.peak_params(k, 2);
            bw = results.peak_params(k, 3);

            fprintf('%s\n', center_str(sprintf('CF: %5.2f, PW: %5.2f, BW: %5.2f', cf, pw, bw), 78));
        end
    end
    fprintf('\n');

    %% Model metrics
    fprintf('%s\n', center_str('Model metrics:', 78));
    fprintf('%s\n', center_str(sprintf('error (mae) is %6.4f', results.error), 78));
    fprintf('%s\n', center_str(sprintf('gof (rsquared) is %6.4f', results.r_squared), 78));

    fprintf('%s\n\n', sep);

    %% Settings
    specparam_settings_print(settings);

end


% =========================================================================
%  specparam_group_print  -  Print group model report
% =========================================================================
function specparam_group_print(results, plot_title)

    settings = results(1).settings;

    sep = repmat('=', 1, 78);
    fprintf('\n%s\n', sep);
    fprintf('%s\n', center_str(plot_title, 78));

    
    fprintf('%s\n\n', center_str('FOOOF - GROUP RESULTS', 78));
    n_spectra = numel(results);

    aps = vertcat(results.aperiodic_params);
    offsets = aps(:, 1);
    exponents = aps(:, end);

    errors = [results.error];
    r2s = [results.r_squared];

    peak_counts = zeros(n_spectra, 1);
    all_peaks = [];

    for i = 1:n_spectra
        cur_peaks = results(i).peak_params;

        if isempty(cur_peaks)
            peak_counts(i) = 0;
        else
            peak_counts(i) = size(cur_peaks, 1);
            all_peaks = [all_peaks; cur_peaks];
        end
    end

    total_peaks = size(all_peaks, 1);

    fprintf('%s\n', center_str(sprintf('Number of power spectra in the Group: %d', n_spectra), 78));

    if isfield(results, 'freqs') && ~isempty(results(1).freqs)
        freq_res = results(1).freqs(2) - results(1).freqs(1);

        fprintf('%s\n', center_str(sprintf('The model was run on the frequency range %g - %g Hz', ...
            results(1).freqs(1), results(1).freqs(end)), 78));

        fprintf('%s\n', center_str(sprintf('Frequency Resolution is %.2f Hz', freq_res), 78));
    end

    fprintf('\n');

    ap_mode = get_setting(settings, 'aperiodic_mode', 'default');
    fprintf('%s\n\n', center_str(sprintf('Power spectra were fit with aperiodic mode: %s', ap_mode), 78));

    fprintf('%s\n', center_str('Aperiodic Fit Values:', 78));
    fprintf('%s\n', center_str(sprintf('Exponents - Min: %.3f, Max: %.3f, Mean: %.3f', ...
        min(exponents), max(exponents), mean(exponents)), 78));

    fprintf('%s\n\n', center_str(sprintf('Offsets - Min: %.3f, Max: %.3f, Mean: %.3f', ...
        min(offsets), max(offsets), mean(offsets)), 78));

    fprintf('%s\n', center_str(sprintf('In total %d peaks were extracted from the group', total_peaks), 78));

    fprintf('%s\n\n', center_str(sprintf('Peaks per spectrum - Mean: %.3f, Median: %.3f', ...
        mean(peak_counts), median(peak_counts)), 78));

    fprintf('%s\n', center_str('Goodness of fit metrics:', 78));
    fprintf('%s\n', center_str(sprintf('R2s - Min: %.3f, Max: %.3f, Mean: %.3f', ...
        min(r2s), max(r2s), mean(r2s)), 78));
    fprintf('%s\n', center_str(sprintf('Errors - Min: %.3f, Max: %.3f, Mean: %.3f', ...
        min(errors), max(errors), mean(errors)), 78));

    fprintf('%s\n\n', sep);

    specparam_settings_print(settings);

end


% =========================================================================
%  specparam_settings_print  -  Print settings block
% =========================================================================
function specparam_settings_print(settings)

    sep = repmat('=', 1, 78);
    fprintf('%s\n', sep);
    fprintf('%s\n', center_str('FOOOF - SETTINGS', 78));
    fprintf('\n');

    peak_width_limits = get_setting(settings, 'peak_width_limits', [0.5, 12]);
    max_n_peaks = get_setting(settings, 'max_n_peaks', Inf);
    min_peak_height = get_setting(settings, 'min_peak_height', 2.0);
    peak_threshold = get_setting(settings, 'peak_threshold', 0);
    ap_mode = get_setting(settings, 'aperiodic_mode', 'default');

    fprintf('%s\n', center_str(sprintf('Peak Width Limits : [%g, %g]', ...
        peak_width_limits(1), peak_width_limits(2)), 78));

    fprintf('%s\n', center_str(sprintf('Max Number of Peaks : %g', max_n_peaks), 78));
    fprintf('%s\n', center_str(sprintf('Minimum Peak Height : %g', min_peak_height), 78));
    fprintf('%s\n', center_str(sprintf('Peak Threshold : %g', peak_threshold), 78));
    fprintf('%s\n', center_str(sprintf('Aperiodic Mode : %s', ap_mode), 78));

    fprintf('%s\n\n', sep);

end


% =========================================================================
%  specparam_group_plot  -  Plot group report
% =========================================================================
function specparam_group_plot(results, plot_title)
    
    if ~exist('plot_title', 'var') || isempty(plot_title)
        plot_title = '';
    end
    
    n_spectra = numel(results);

    aps = vertcat(results.aperiodic_params);
    exponents = aps(:, end);

    errors = [results.error];
    r2s = [results.r_squared];

    all_peaks = [];

    for i = 1:n_spectra
        if ~isempty(results(i).peak_params)
            all_peaks = [all_peaks; results(i).peak_params];
        end
    end

    figure;

    %% Aperiodic Fit
    subplot(2, 2, 1)

    scatter(ones(size(exponents)), exponents, 35, 'filled', ...
        'MarkerFaceAlpha', 0.6);

    title('Aperiodic Fit');
    ylabel('Exponent');
    xticks(1);
    xticklabels({'Exponent'});
    xlim([0.5 1.5]);

    yl = ylim;
    ylim([0 yl(2)]);
    box off

    %% Goodness of Fit
    subplot(2, 2, 2)

    yyaxis left
    scatter(ones(size(errors)), errors, 35, 'filled', ...
        'MarkerFaceAlpha', 0.6);
    ylabel('Error');

    yyaxis right
    scatter(2 * ones(size(r2s)), r2s, 35, 'filled', ...
        'MarkerFaceAlpha', 0.6);
    ylabel('R^2');

    title('Goodness of Fit');
    xticks([1 2]);
    xticklabels({'Error', 'R^2'});
    xlim([0.5 2.5]);
    box off

    %% Peaks - Center Frequencies
    subplot(2, 1, 2)

    if ~isempty(all_peaks)
        center_freqs = all_peaks(:, 1);

        histogram(center_freqs, 'BinWidth', 1);

        xlabel('Center Frequency');
        ylabel('Count');
        title('Peaks - Center Frequencies');
    else
        xlabel('Center Frequency');
        ylabel('Count');
        title('Peaks - Center Frequencies');

        text(0.5, 0.5, 'No peaks found', ...
            'HorizontalAlignment', 'center');
    end

    box off

end


% =========================================================================
%  get_setting  -  Get field from settings, otherwise return default
% =========================================================================
function value = get_setting(settings, field_name, default_value)

    if isfield(settings, field_name) && ~isempty(settings.(field_name))
        value = settings.(field_name);
    else
        value = default_value;
    end

end


% =========================================================================
%  center_str  -  Center a string within a fixed width
% =========================================================================
function out = center_str(str, width)

    n = numel(str);
    left = max(0, floor((width - n) / 2));
    out = [repmat(' ', 1, left), str];

end