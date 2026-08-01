% specparam_group() - Run the specparam model on a group of neural power spectra.
%
% Usage:
%   specparam_results = specparam_group(freqs, ====================================================================psds, f_range, settings);
%
% Inputs:
%   freqs           = row vector of frequency values
%   psds            = matrix of power values, which each row representing a spectrum
%   f_range         = fitting range (Hz)
%   settings        = specparam model settings, in a struct, including:
%       settings.peak_width_limts
%       settings.max_n_peaks
%       settings.min_peak_height
%       settings.peak_threshold
%       settings.aperiodic_mode
%       settings.verbose
%
% Outputs:
%   specparam_results   = specparam model ouputs, in a struct, including:
%       specparam_results.aperiodic_params
%       specparam_results.peak_params
%       specparam_results.gaussian_params
%       specparam_results.error
%       specparam_results.r_squared
%
% Notes
%   Not all settings need to be set. Any settings that are not
%     provided as set to default values. To run with all defaults,
%     input settings as an empty struct.

function specparam_results = specparam_group(freqs, psds, f_range, settings)

    % Check settings - get defaults for those not provided
    settings = specparam_check_settings(settings);

    % Initialize object to collect results
    specparam_results = [];
    
    % Run across the group of power spectra
    n = size(psds, 2);
    for i = 1:n
        psd = psds(:, i);
        cur_results = specparam(freqs, psd', f_range, settings, true, i);
        specparam_results = [specparam_results, cur_results];
    end
end
