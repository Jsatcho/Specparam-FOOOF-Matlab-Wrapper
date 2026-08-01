function ax = plot_aperiodic_params(aps, colors, labels, ax)

    if nargin < 2 || isempty(colors)
        colors = [];
    end
    if nargin < 3
        labels = [];
    end
    if nargin < 4 || isempty(ax)
        figure;
        ax = axes;
    end

    hold(ax, 'on');

    if iscell(aps)

        for i = 1:numel(aps)
            cur_color = get_group_color(colors, i);
            cur_label = get_group_label(labels, i);

            plot_aperiodic_params(aps{i}, cur_color, cur_label, ax);
        end

    else

        xs = aps(:, 1);       % offset
        ys = aps(:, end);     % exponent is always last column

        scatter(ax, xs, ys, 150, colors, ...
            'filled', ...
            'MarkerFaceAlpha', 0.7, ...
            'DisplayName', labels);

    end

    xlabel(ax, 'Offset');
    ylabel(ax, 'Exponent');

    if ~isempty(labels)
        legend(ax, 'show');
    end

    style_param_plot(ax);

end