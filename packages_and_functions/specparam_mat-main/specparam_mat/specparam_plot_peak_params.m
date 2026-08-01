function ax = plot_peak_params(peaks, freq_range, colors, labels, ax)

    if nargin < 2
        freq_range = [];
    end
    if nargin < 3 || isempty(colors)
        colors = [];
    end
    if nargin < 4
        labels = [];
    end
    if nargin < 5 || isempty(ax)
        figure;
        ax = axes;
    end

    hold(ax, 'on');

    if iscell(peaks)

        for i = 1:numel(peaks)
            cur_color = get_group_color(colors, i);
            cur_label = get_group_label(labels, i);

            plot_peak_params(peaks{i}, freq_range, cur_color, cur_label, ax);
        end

    else

        xs = peaks(:, 1);       % CF
        ys = peaks(:, 2);       % PW
        sizes = peaks(:, 3) * 150;  % BW controls dot size

        scatter(ax, xs, ys, sizes, colors, ...
            'filled', ...
            'MarkerFaceAlpha', 0.7, ...
            'DisplayName', labels);

    end

    xlabel(ax, 'Center Frequency');
    ylabel(ax, 'Power');

    if ~isempty(freq_range)
        xlim(ax, freq_range);
    end

    yl = ylim(ax);
    ylim(ax, [0, yl(2)]);

    if ~isempty(labels)
        legend(ax, 'show');
    end

    style_param_plot(ax);

end