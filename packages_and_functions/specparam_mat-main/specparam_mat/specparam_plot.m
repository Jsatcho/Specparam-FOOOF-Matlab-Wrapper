% specparam_plot() - Plot a specparam model.
%
% Usage:
%   >> specparam_plot(specparam_results)
%
% Inputs:
%   specparam_results   = struct of specparam results
%                           Note: must contain specparam model, not just results
%   log_axes            = boolean, whether to log frequency and power axis
%                           Note: this argument is optional, defaults to false
%

function specparam_plot(specparam_results, log_freqs, plot_title)

    if nargin < 2
        log_freqs = false;
    end

    if ~isfield(specparam_results, 'freqs')
        error('specparam results struct does not contain model output.')
    end

    if log_freqs
        plt_freqs = log10(specparam_results.freqs);
    else
        plt_freqs = specparam_results.freqs;
    end

    lw = 2.5;

    figure()
    set(gca, 'Color', 'white')
    hold on

    data = plot(plt_freqs, specparam_results.power_spectrum, 'black');
    model = plot(plt_freqs, specparam_results.specparamed_spectrum, 'red');
    ap_fit = plot(plt_freqs, specparam_results.ap_fit, 'b--');

    for plt = [data, model, ap_fit]
        set(plt, 'LineWidth', lw);
    end

    model.Color(4) = 0.5;

    grid on
    set(gca, 'GridColor', [0.5 0.5 0.5])
    set(gca, 'GridAlpha', 1)

    ylabel('log(Power)')

    if log_freqs
        xlabel('log(Frequency)')
    else
        xlabel('Frequency Hz')
    end

    if exist('plot_title', 'var')
        title(plot_title);
    end

    legend('Original Spectrum', 'Full Model Fit', 'Aperiodic Fit')

    hold off
end
% helper functions------
function vals = aperiodic_func(freqs, ap_params, aperiodic_mode)

    switch lower(aperiodic_mode)

        case {'default', 'fixed'}
            offset = ap_params(1);
            exponent = ap_params(2);

            vals = offset - log10(freqs .^ exponent);

        case 'knee'
            offset = ap_params(1);
            knee = ap_params(2);
            exponent = ap_params(3);

            vals = offset - log10(knee + freqs .^ exponent);

        case 'doubleexp'
            offset = ap_params(1);
            exponent1 = ap_params(2);
            knee = ap_params(3);
            exponent2 = ap_params(4);

            vals = offset - log10(freqs .^ exponent1 .* ...
                (knee + freqs .^ exponent2));

        otherwise
            error('Unknown aperiodic_mode.');
    end

end