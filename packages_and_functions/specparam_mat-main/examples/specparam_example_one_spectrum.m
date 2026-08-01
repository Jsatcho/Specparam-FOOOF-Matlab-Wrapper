%% FOOOF Matlab Wrapper Example - Single PSD
%
% This example computes an example power spectrum model for a single
% power spectrum, and prints out the results.
%

%% Run Example

% Set up Python environment
if pyenv().Status == "NotLoaded"
    pyenv('Version', 'CUsersJeremiah Satchominiconda3envsfooof_envpython.exe')
end
% Ensure the FOOOF module is available
if isempty(py.importlib.import_module('specparam'))
    error('specparam module could not be imported. Check your Python environment.');
end
addpath("C:\Users\Jeremiah Satcho\Desktop\NYU_SURP\Jeremiah_Erin_MATLAB\packages_and_functions\specparam_mat-main\examples\data")

% Load data
load("ch_dat_one.mat");

% Calculate a power spectrum with Welch's method
[psd, freqs] = pwelch(ch_dat_one, 500, [], [], s_rate);

% Transpose, to make inputs row vectors
freqs = freqs';
psd = psd';

% specparam settings
%       settings.peak_width_limts   default: [0.5, 12]
%       settings.max_n_peaks        default: infinite
%       settings.min_peak_height    default: 2.0
%       settings.peak_threshold     default: 0
%       settings.aperiodic_mode     default: default
settings = struct();  % Use defaults
settings.max_n_peaks = 2;
settings.aperiodic_mode = 'doublexp';

f_range = [1, 30];

% Run specparam
%specparam_results = specparam(freqs, psd, f_range, settings, true);
specparam_results = specparam_ms(freqs, psd, f_range, settings, 12)

% create report
specparam_report(specparam_results, false);