function [specparam_results, best_n_peaks, BF01s] = specparam_group_ms(freqs, psds, f_range, settings, max_peaks)

    if ~exist('max_peaks', 'var')
        max_peaks = 12;
    end

    settings = specparam_check_settings(settings);
    n_spectra = size(psds, 1);

    %% Step 1: group-level model selection
    % Fit all peak counts on every spectrum, accumulate average BIC
    
    BICmat = NaN(n_spectra, max_peaks + 1);
    parfor psd_idx = 1:n_spectra
        BIC_row = NaN(max_peaks + 1, 1);
        for npeaks = 0:max_peaks
            s = settings;
            s.max_n_peaks = int32(npeaks);
            result = specparam(freqs, psds(psd_idx,:), f_range, s, true);
            BIC_row(npeaks + 1) = result.BIC;
        end
        
        BICmat(psd_idx,:) = BIC_row;
    end

    BIC_mean = mean(BICmat,1);
    [~, best] = min(BIC_mean);
    best_n_peaks = best - 1;           % convert from 1-indexed to peak count
    settings.max_n_peaks = best_n_peaks;

    %% Step 2: refit all spectra with the winning peak count
    specparam_results = cell(n_spectra, 1);
    BF01s = NaN(n_spectra, 1);

    parfor psd_idx = 1:n_spectra
        [specparam_results{psd_idx}, BF01s(psd_idx)] = ...
            specparam_m(freqs, psds(psd_idx,:), f_range, settings, true, best_n_peaks);
    end

    specparam_results = [specparam_results{:}];   % cell array → struct array

    
    % Plot average BIC values against the number of peaks
    figure;
    plot(0:max_peaks, BIC_mean, '-o');
    xlabel('Number of Peaks');
    ylabel('Average BIC');
    title('Model Selection: Average BIC vs Number of Peaks');
    grid on;
    %plot avg BIC's per npeaks
    figure;
    plot(0:max_peaks, BICmat, 'o');
    xlabel('Number of Peaks');
    ylabel('BIC');
    title('Model Selection: Average BIC vs Number of Peaks')
    grid on;
end