function ax = plot_aperiodic_fits(aps, freq_range, aperiodic_mode, control_offset, ...
                                  average, shade, plot_individual, log_freqs, ...
                                  colors, labels, ax)

    %% Defaults
    if nargin < 3 || isempty(aperiodic_mode)
        aperiodic_mode = 'default';
    end
    if nargin < 4 || isempty(control_offset)
        control_offset = false;
    end
    if nargin < 5 || isempty(average)
        average = 'mean';
    end
    if nargin < 6 || isempty(shade)
        shade = 'sem';
    end
    if nargin < 7 || isempty(plot_individual)
        plot_individual = true;
    end
    if nargin < 8 || isempty(log_freqs)
        log_freqs = false;
    end
    if nargin < 9 || isempty(colors)
        colors = [];
    end
    if nargin < 10
        labels = [];
    end
    if nargin < 11 || isempty(ax)
        figure;
        ax = axes;
    end

    hold(ax, 'on');

    %% Group/cell input
    if iscell(aps)

        for i = 1:numel(aps)
            cur_color = get_group_color(colors, i);
            cur_label = get_group_label(labels, i);

            plot_aperiodic_fits(aps{i}, freq_range, aperiodic_mode, ...
                control_offset, average, shade, plot_individual, ...
                log_freqs, cur_color, cur_label, ax);
        end

        xlabel(ax, get_freq_label(log_freqs));
        ylabel(ax, 'log(Power)');
        style_param_plot(ax);
        return
    end

    %% Frequency axis
    freqs = freq_range(1):0.1:freq_range(2);

    if log_freqs
        plt_freqs = log10(freqs);
    else
        plt_freqs = freqs;
    end

    %% Pick color
    if isempty(colors)
        color = [0 0.4470 0.7410];
    else
        color = colors;
    end

    %% Reconstruct each aperiodic fit
    all_ap_vals = zeros(size(aps, 1), numel(freqs));

    for ind = 1:size(aps, 1)

        ap_params = aps(ind, :);

        if control_offset
            ap_params(1) = 0;
        end

        ap_vals = aperiodic_func(freqs, ap_params, aperiodic_mode);

        all_ap_vals(ind, :) = ap_vals;

        if plot_individual
            plot(ax, plt_freqs, ap_vals, ...
                'Color', color, ...
                'LineWidth', 1.25, ...
                'HandleVisibility', 'off');
        end
    end

    %% Plot average with shade
    if ~isequal(average, false)
        plot_yshade(ax, plt_freqs, all_ap_vals, average, shade, color, labels);
    end

    %% Labels and limits
    xlabel(ax, get_freq_label(log_freqs));
    ylabel(ax, 'log(Power)');

    if log_freqs
        xlim(ax, log10(freq_range));
    else
        xlim(ax, freq_range);
    end

    style_param_plot(ax);

end