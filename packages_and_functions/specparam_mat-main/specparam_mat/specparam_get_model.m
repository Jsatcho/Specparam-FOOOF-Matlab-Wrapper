% specparam_get_model() - Return the model fit values from a SpectralModel object
%
% Usage:
%   >> model_fit = specparam_get_model(fm)
%
% Inputs:
%   fm              = SpectralModel object (specparam)
%
% Outputs:
%   model_fit       = model results, in a struct, including:
%       model_fit.freqs
%       model_fit.power_spectrum
%       model_fit.specparaed_spectrum
%       model_fit.ap_fit
%
% Notes
%   This function is mostly an internal function.
%     It can be called directly by the user if you are interacting with SpectralModel objects directly.

function model_fit = specparam_get_model(fm)

    model_fit = struct();

    model_fit.freqs = double(py.array.array('d', fm.data.freqs));
    model_fit.power_spectrum = double(py.array.array('d', fm.data.power_spectrum));
    model_fit.specparamed_spectrum = double(py.array.array('d', fm.results.model.modeled_spectrum));
    ap_fit_raw = py.getattr(fm.results.model, '_ap_fit');
    model_fit.ap_fit = double(py.array.array('d', ap_fit_raw));
end