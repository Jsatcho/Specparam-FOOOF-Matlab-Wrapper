function ax = plot_peak_fits(peaks, periodic_mode, freq_range, average, shade, ...
                             plot_individual, colors, labels, ax)

% plot_peak_fits() - Plot reconstructions of model peak fits.
%
% Usage:
%   plot_peak_fits(results.peak_params, 'gaussian')
%   plot_peak_fits(results.gaussian_params, 'gaussian', [1 40])
%   plot_peak_fits({results.peak_params}, 'gaussian')
%
% Inputs:
%   peaks             = [n_peaks x 3] matrix, each row [CF, PW, BW]
%                       OR cell array of peak matrices for group plotting
%   periodic_mode     = 'gaussian' or 'lorentzian'
%   freq_range        = optional [f_min, f_max]
%   average           = 'mean', 'median', or false
%   shade             = 'sem', 'std', or false
%   plot_individual   = true/false
%   colors            = optional color spec, e.g. 'b'
%   labels            = optional legend label
%   ax                = optional axes handle

    %% Defaults
    if nargin < 2 || isempty(periodic_mode)
        periodic_mode = 'gaussian';
    end

    if nargin < 3
        freq_range = [];
    end

    if nargin < 4 || isempty(average)
        average = 'mean';
    end

    if nargin < 5 || isempty(shade)
        shade = 'sem';
    end

    if nargin < 6 || isempty(plot_individual)
        plot_individual = true;
    end

    if nargin < 7 || isempty(colors)
        colors = [];
    end

    if nargin < 8
        labels = [];
    end

    if nargin < 9 || isempty(ax)
        figure;
        ax = axes;
    end

    hold(ax, 'on');

    %% If group/cell input, recursively plot each set
    if iscell(peaks)

        for i = 1:numel(peaks)

            cur_color = get_group_color(colors, i);
            cur_label = get_group_label(labels, i);

            plot_peak_fits(peaks{i}, periodic_mode, freq_range, average, shade, ...
                           plot_individual, cur_color, cur_label, ax);
        end

        xlabel(ax, 'Frequency');
        ylabel(ax, 'log(Power)');
        style_param_plot(ax);

        return
    end

    %% Handle empty peaks
    if isempty(peaks)
        warning('No peaks to plot.');
        return
    end

    %% Define frequency range if not provided
    if isempty(freq_range)

        cfs = peaks(:, 1);
        cfs = cfs(~isnan(cfs));

        f_buffer = 4;

        f_min = min(cfs) - f_buffer;
        if f_min < 0
            f_min = 0;
        end

        f_max = max(cfs) + f_buffer;

        freq_range = [f_min, f_max];
    end

    %% Create frequency axis
    freqs = freq_range(1):0.1:freq_range(2);

    %% Pick color
    if isempty(colors)
        color = [0 0.4470 0.7410];
    else
        color = colors;
    end

    %% Reconstruct each peak
    all_peak_vals = zeros(size(peaks, 1), numel(freqs));

    for ind = 1:size(peaks, 1)

        peak_params = peaks(ind, :);

        peak_vals = periodic_func(freqs, peak_params, periodic_mode);

        all_peak_vals(ind, :) = peak_vals;

        if plot_individual
            plot(ax, freqs, peak_vals, ...
                'Color', color, ...
                'LineWidth', 1.25, ...
                'HandleVisibility', 'off');
        end
    end

    %% Plot average and shade
    if ~isequal(average, false)

        plot_yshade(ax, freqs, all_peak_vals, average, shade, color, labels);

    end

    %% Labels and limits
    xlabel(ax, 'Frequency');
    ylabel(ax, 'log(Power)');

    xlim(ax, freq_range);

    yl = ylim(ax);
    ylim(ax, [0, yl(2)]);

    style_param_plot(ax);

end


% =========================================================================
% Periodic model function
% =========================================================================
function vals = periodic_func(freqs, peak_params, periodic_mode)

    cf = peak_params(1);
    pw = peak_params(2);
    bw = peak_params(3);

    switch lower(periodic_mode)

        case 'gaussian'
            vals = pw .* exp(-((freqs - cf).^2) ./ (2 .* bw.^2));

        case 'lorentzian'
            vals = pw ./ (1 + ((freqs - cf) ./ bw).^2);

        otherwise
            error('Unknown periodic_mode. Use ''gaussian'' or ''lorentzian''.');
    end

end


% =========================================================================
% Plot average line with optional shaded region
% =========================================================================
function plot_yshade(ax, freqs, all_vals, average, shade, color, label)

    switch lower(average)

        case 'mean'
            avg_vals = mean(all_vals, 1, 'omitnan');

        case 'median'
            avg_vals = median(all_vals, 1, 'omitnan');

        otherwise
            error('average must be ''mean'', ''median'', or false.');
    end

    if ~isequal(shade, false)

        switch lower(shade)

            case 'sem'
                spread_vals = std(all_vals, 0, 1, 'omitnan') ./ sqrt(size(all_vals, 1));

            case 'std'
                spread_vals = std(all_vals, 0, 1, 'omitnan');

            otherwise
                error('shade must be ''sem'', ''std'', or false.');
        end

        upper = avg_vals + spread_vals;
        lower = avg_vals - spread_vals;

        fill(ax, [freqs, fliplr(freqs)], [upper, fliplr(lower)], ...
             color, ...
             'FaceAlpha', 0.15, ...
             'EdgeColor', 'none', ...
             'HandleVisibility', 'off');
    end

    if isempty(label)
        plot(ax, freqs, avg_vals, ...
             'Color', color, ...
             'LineWidth', 3.75);
    else
        plot(ax, freqs, avg_vals, ...
             'Color', color, ...
             'LineWidth', 3.75, ...
             'DisplayName', label);
        legend(ax, 'show');
    end

end


% =========================================================================
% Get group color
% =========================================================================
function color = get_group_color(colors, i)

    default_colors = lines(7);

    if isempty(colors)
        color = default_colors(mod(i - 1, size(default_colors, 1)) + 1, :);
    elseif iscell(colors)
        color = colors{i};
    elseif isnumeric(colors) && size(colors, 1) > 1
        color = colors(i, :);
    else
        color = colors;
    end

end


% =========================================================================
% Get group label
% =========================================================================
function label = get_group_label(labels, i)

    if isempty(labels)
        label = [];
    elseif iscell(labels)
        label = labels{i};
    elseif isstring(labels)
        label = labels(i);
    else
        label = labels;
    end

end


% =========================================================================
% Basic plot styling
% =========================================================================
function style_param_plot(ax)

    box(ax, 'off');
    set(ax, 'FontSize', 12);
    grid(ax, 'off');

end