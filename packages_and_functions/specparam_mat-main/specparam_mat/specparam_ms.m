function best_model = specparam_ms(freqs, power_spectrum, f_range, settings, max_peaks)
    if ~exist('max_peaks', 'var')
        max_peaks = 12; % Default value for max_peaks if not provided
    end

    BIC = NaN(max_peaks + 1, 1);
    models = cell(max_peaks + 1, 1); % Initialize cell array to store models
    for npeaks = 0:max_peaks
    
        settings.max_n_peaks = int32(npeaks);
    
        result = specparam_m(freqs, power_spectrum, f_range, settings);
        
        specparam_report(result)
    
        BIC(npeaks+1) = result.BIC;
    
        models{npeaks+1} = result;
      
    end

    [~,best] = min(BIC);
    disp('BIC per number of peaks (0 to max):')
    for i = 1:length(BIC)
        fprintf('  %d peaks: BIC = %.4f\n', i-1, BIC(i));
    end

    best_model = models{best};
end

% specparam_m() - Fit the specparam model on a neural power spectrum.
%
% Usage:
%   >> specparam_results = specparam(freqs, power_spectrum, f_range, settings);
%
% Inputs:
%   freqs           = row vector of frequency values
%   power_spectrum  = row vector of power values
%   f_range         = fitting range (Hz)
%   settings        = specparam model settings, in a struct, including:
%       settings.peak_width_limts   default: [0.5, 12]
%       settings.max_n_peaks        default: infinite
%       settings.min_peak_height    default: 2.0
%       settings.peak_threshold     default: 0
%       settings.aperiodic_mode     default: default 
%       settings.verbose
%   return_model    = boolean of whether to return the specparam model fit, optional
%
% Outputs:
%   specparam_results   = specparam model ouputs, in a struct, including:
%       specparam_results.aperiodic_params 
%       specparam_results.peak_params
%       specparam_results.gaussian_params
%       specparam_results.error
%       specparam_results.r_squared
%       specparam_results.freqs
%       specparam_results.power_spectrum
%       specparam_results.specparamed_spectrum
%       specparam_results.ap_fit
%
% Notes
%   Not all settings need to be defined by the user.
%     Any settings that are not provided are set to default values.
%     To run with all defaults, input settings as an empty struct.

function specparam_results = specparam_m(freqs, power_spectrum, f_range, settings)

    settings = specparam_check_settings(settings);

    % Save MATLAB vectors before converting to Python
    freqs_matlab = freqs;
    power_spectrum_matlab = power_spectrum;

    % Convert inputs to Python
    freqs = py.numpy.array(freqs);
    power_spectrum = py.numpy.array(power_spectrum);
    f_range = py.list({f_range(1), f_range(2)});

    % Initialize SpectralModel object
    fm = py.specparam.SpectralModel(pyargs(...
        'peak_width_limits', settings.peak_width_limits, ...
        'max_n_peaks', int32(settings.max_n_peaks), ...
        'min_peak_height', settings.min_peak_height, ...
        'peak_threshold', settings.peak_threshold, ...
        'aperiodic_mode', settings.aperiodic_mode, ...
        'verbose', settings.verbose));

    fm.fit(freqs, power_spectrum, f_range)

    specparam_results = struct();

    specparam_results.aperiodic_params = double(py.array.array('d', fm.results.params.aperiodic.params));

    temp = double(py.array.array('d', fm.results.params.periodic.params.ravel()));
    if isempty(temp)
        specparam_results.peak_params = [];
        specparam_results.gaussian_params = [];
    else
        specparam_results.peak_params = transpose(reshape(temp, 3, length(temp) / 3));
        specparam_results.gaussian_params = specparam_results.peak_params;
    end

    metrics_results = fm.results.metrics.results;
    specparam_results.error = double(metrics_results{'error_mae'});
    specparam_results.r_squared = double(metrics_results{'gof_rsquared'});

    model_out = specparam_get_model(fm);
    for field = fieldnames(model_out)'
        specparam_results.(field{1}) = model_out.(field{1});
    end

    specparam_results.settings = settings;
    
    

    % Replace the BIC section with this:
    fitted_freqs = specparam_results.freqs;
    
    % Find indices in freqs_matlab that fall within the fitted range
    freq_mask = freqs_matlab >= fitted_freqs(1) & freqs_matlab <= fitted_freqs(end);
    trimmed_power = power_spectrum_matlab(freq_mask);
    
    % If lengths still don't match, interpolate power to fitted freq grid
    if length(trimmed_power) ~= length(specparam_results.specparamed_spectrum)
        trimmed_power = interp1(freqs_matlab(freq_mask), trimmed_power, fitted_freqs, 'linear');
    end
    
    residuals = log10(trimmed_power(:)') - specparam_results.specparamed_spectrum(:)';
    n = length(trimmed_power);
    specparam_results.MSE = mean(residuals.^2);
    specparam_results.loglik = -(n/2) * (1 + log(2*pi * specparam_results.MSE));
    n_params = numel(specparam_results.aperiodic_params) + numel(specparam_results.peak_params);
    specparam_results.BIC = n_params * log(n) - 2 * specparam_results.loglik;
    
    %debug
    disp('trimmed_power range:')
    disp([min(trimmed_power) max(trimmed_power)])
    disp('specparamed_spectrum range:')
    disp([min(specparam_results.specparamed_spectrum) max(specparam_results.specparamed_spectrum)])

end