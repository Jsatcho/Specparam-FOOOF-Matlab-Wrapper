%% LFP to PSD preprocessing
% Load LFP data
data = load('M0101.mat');
LFP = data.data.NEURO.LFP; % change back to data.data.NEURO.LFP.AD01
%% Notch Filtering
% Notch filter to remove line noise (60Hz and harmonics); currently may not
% use notch filter bc averaging results may solve this or we will snip the
% exact frequencies causing the noise.
fields = fieldnames(LFP);
LFP_mat = zeros(length(LFP.(fields{1})), numel(fields));
for i = 1:numel(fields)
    %LFP.(fields{i}) = simple_notch_filter(LFP.(fields{i}), [60 120 180], 1000);
    LFP_mat(:,i) = LFP.(fields{i});
end
%LFP = LFP_mat; move this to wherever you want to use average the LFP's

%% Filtering
TW = 6;
K = 2*TW-1;
LFP_window = LFP_mat(45521-999:45521+3000,:);
params = struct();
params.tapers = [TW K];      % TW=3, K=5 tapers use K = 2*TW-1
params.Fs = 1000;
params.fpass = [0 100];     % frequencies of interest
params.trialave = 0;        % 0 doesn't avg; 1 averages across trials; keep at zero bc we won't be averging across trials until after filtering, right before placing in PSD.
[PSD, f] = mtspectrumc(LFP_window, params);
figure
plot(f, log10(PSD))
title("(Not averaged) TW = " + TW + " K = " + K)
%legend(fields)

%% specparam
% specparam settings:
%       settings.peak_width_limts   default: [0.5, 12]
%       settings.max_n_peaks        default: infinite
%       settings.min_peak_height    default: 0
%       settings.peak_threshold     default: 2.0 ~2std from apfloor= signif
%       settings.aperiodic_mode     default: default 
%       settings.verbose
settings = struct();  % Use defaults
settings.max_n_peaks = 8;
settings.peak_width_limits = [3 6];


settings.aperiodic_mode = 'doublexp';

f_range = [1, 100];

% Run specparam]
f = f(:)';
n_channels = size(PSD, 2);
all_results = cell(n_channels, 1);
for max_peak = [1 2 3 4 5 6 7 8 9 10 11 12]
    %for i = 1:length(all_results)

        settings.peak_width_limits = [2, 6];
        settings.max_n_peaks = max_peak;
        groupMode = false;
        if groupMode
            all_results{i} = specparam_group_ms(f, PSD, f_range, settings, 12);
        else
            all_results = specparam(f, PSD(:,8)', f_range, settings, 12);
        end
        plot_title = sprintf('mp: %d spectrum 8: min_width=%d max_width %d: %d peaks found', max_peak, settings.peak_width_limits(1,1), settings.peak_width_limits(1,2), size(all_results.peak_params,1));
        specparam_report(all_results, false, plot_title);
    %end
end
  



%% Report results for each channel
for i = 1:n_channels
    fprintf('Channel %d:\n', i)
    specparam_report(all_results{i}, false);
end
