# specparam-toolbox

A lightweight MATLAB toolbox for the Python [`specparam`](https://github.com/fooof-tools/fooof) (formerly `fooof`) package for parameterizing neural power spectra into periodic and aperiodic components.

The toolbox interfaces directly with the Python `specparam` package through MATLAB's built-in Python interface, allowing you to perform spectral parameterization, batch processing, visualization, reporting, and result serialization entirely from within MATLAB.

The toolbox targets the current `specparam` API (v2), the actively developed successor to `fooof`, and is not intended for the legacy MATLAB wrappers written for the `fooof` 1.x API.

---

# Features

* Fit individual neural power spectra
* Batch fit entire datasets of spectra
* Automatic handling of failed model fits
* Native MATLAB structures for results
* Optional return of reconstructed model components
* Built-in plotting utilities
* Human-readable model reports
* Save and load fitted models
* MATLAB-friendly interface to the Python `specparam` package

---

# Overview

`specparam` models a neural power spectrum as the sum of:

* an **aperiodic component** (1/f-like background)
* one or more **periodic components** (putative oscillatory peaks)

This toolbox currently provides the following high-level functions:

| Function             | Purpose                                                                |
| -------------------- | ---------------------------------------------------------------------- |
| `specparam()`        | Fit a single power spectrum                                            |
| `specparam_group()`  | Fit every spectrum in a matrix of spectra                              |
| `specparam_plot()`   | Visualize model fits and extracted components                          |
| `specparam_report()` | Generate a formatted report summarizing model settings and fit results |
| `specparam_save()`   | Save fitted model results                                              |
| `specparam_load()`   | Load previously saved model results                                    |

All functions operate directly on MATLAB data while internally calling the official Python implementation of `specparam`.

---

# Requirements

* MATLAB with the MATLAB-Python interface configured (`pyenv`)
* Python ≥ 3.7
* The Python `specparam` package

Install `specparam` with

```shell
pip install specparam
```

Verify the installation:

```shell
python -c "import specparam"
```

---

# Installation

Clone the repository

```shell
git clone https://github.com/<your-username>/specparam-toolbox
```

Add it to your MATLAB path

```matlab
addpath('/path/to/specparam-toolbox')
```

Configure MATLAB to use the desired Python installation

```matlab
pyenv('Version','/path/to/python')
```

Verify MATLAB can access the package

```matlab
py.importlib.import_module('specparam')
```

If no error is produced, MATLAB is correctly configured.

---

# Usage

## Fitting a single power spectrum

```matlab
% freqs and power_spectrum are row vectors.
% power_spectrum should contain LINEAR (not log-transformed) power values.

f_range = [3 40];

settings = struct();

settings.peak_width_limits = [1 8];
settings.max_n_peaks       = 6;
settings.min_peak_height   = 0.1;
settings.peak_threshold    = 2;
settings.aperiodic_mode    = 'fixed';

results = specparam(freqs,power_spectrum,f_range,settings);

results.aperiodic_params
results.peak_params
results.error
results.r_squared
results.fit_ok
```

The returned MATLAB structure contains the fitted parameters, model statistics, and goodness-of-fit metrics extracted directly from the underlying Python `SpectralModel`.

> **Important**
>
> The input spectrum must contain **linear power values**. The Python `specparam` model performs its own logarithmic transformation internally. Supplying log-transformed power values will produce incorrect results.

---

## Returning model components

To also return the fitted model curves

```matlab
results = specparam(freqs,power_spectrum,f_range,settings,true);

results.freqs
results.power_spectrum
results.specparamed_spectrum
results.ap_fit
```

---

## Fitting multiple spectra

```matlab
% psds is an Nfreq × Nspectra matrix.
% Each COLUMN corresponds to one spectrum.

group_results = specparam_group(freqs,psds,f_range,settings);
```

`specparam_group()` iterates over every column of the PSD matrix, fits each spectrum individually using `specparam()`, and returns a MATLAB struct array containing one fitted model per spectrum.

---

# Plotting

Model fits can be visualized using

```matlab
specparam_plot(results)
```

The plotting utility displays the original spectrum together with the fitted aperiodic component, flattened spectrum, detected oscillatory peaks, and reconstructed model.

---

# Reports

Generate a formatted report describing the fitted model

```matlab
specparam_report(results)
```

The generated report summarizes

* fitting settings
* aperiodic parameters
* periodic peak parameters
* goodness-of-fit statistics
* model error

making it convenient to inspect model fits directly from MATLAB.

---

# Saving and Loading Results

Save fitted models

```matlab
specparam_save(results,'model.mat')
```

Load previously saved models

```matlab
results = specparam_load('model.mat')
```

These helper functions provide a convenient way to archive and reload fitted models while preserving the complete MATLAB structure.

---

# Settings

| Setting             | Description                                           | Default    |
| ------------------- | ----------------------------------------------------- | ---------- |
| `peak_width_limits` | Minimum and maximum allowable bandwidth               | `[0.5 12]` |
| `max_n_peaks`       | Maximum number of peaks                               | `Inf`      |
| `min_peak_height`   | Minimum absolute peak height above the aperiodic fit  | `0`        |
| `peak_threshold`    | Relative peak threshold (SD above flattened spectrum) | `2`        |
| `aperiodic_mode`    | `'fixed'`, `'knee'`, `'doublexp'`, etc.               | `'fixed'`  |
| `verbose`           | Display fitting information                           | `false`    |

Unspecified settings are automatically populated with default values by `specparam_check_settings()`.

---

# Peak-Fitting Parameters

### `peak_width_limits`

Constrains how narrow or broad fitted peaks are allowed to be.

As a general guideline, the lower limit should be at least twice the frequency resolution of the input spectrum. Otherwise, individual frequency bins may be mistaken for genuine oscillatory peaks.

---

### Stopping Criteria

Peak extraction continues until one of the following conditions is reached:

* `max_n_peaks`

  * Maximum number of peaks has been found.

* `peak_threshold`

  * Candidate peak falls below the specified relative threshold.

* `min_peak_height`

  * Candidate peak falls below the specified absolute height above the aperiodic fit.

Both thresholds are evaluated independently.

---

# Failure Handling

Individual spectra occasionally fail to fit.

Unlike the underlying Python implementation, this toolbox is designed to continue processing entire datasets even when individual spectra fail.

If fitting fails

* MATLAB issues a warning containing the underlying Python error.
* A MATLAB structure with appropriately-sized NaN parameters is returned.
* `results.fit_ok` is set to `false`.
* Placeholder model fields are added when model outputs were requested.

This allows `specparam_group()` to continue fitting the remaining spectra instead of terminating the entire batch.

When processing groups of spectra, users should always inspect the `fit_ok` field before interpreting fitted parameters.

---

# Further Reading

For complete documentation of the underlying spectral parameterization algorithm, see

* https://specparam-tools.github.io/
* https://fooof-tools.github.io/fooof/

---

# Citation

If you use this toolbox in published work, please cite the original spectral parameterization method:

> Donoghue T, Haller M, Peterson EJ, Varma P, Sebastian P, Gao R, Noto T, Lara AH, Wallis JD, Knight RT, Shestyuk A, & Voytek B (2020). *Parameterizing neural power spectra into periodic and aperiodic components.* Nature Neuroscience, 23, 1655–1665. https://doi.org/10.1038/s41593-020-00744-x

---

# Acknowledgments

This project was inspired by the original **fooof_mat** MATLAB wrapper developed by the fooof-tools team, which demonstrated how to interface MATLAB with the Python implementation of the spectral parameterization algorithm.

This toolbox has since been substantially redesigned and expanded for the current `specparam` API. In addition to single-spectrum fitting, it includes batch fitting utilities, robust error handling, plotting, report generation, model serialization (save/load), optional model reconstruction outputs, support for multiple aperiodic modes, and expanded documentation while maintaining seamless integration with MATLAB.

The underlying spectral parameterization algorithm is provided by the `specparam` Python package developed by the fooof-tools team.

Original MATLAB wrapper:

https://github.com/fooof-tools/fooof_mat

---

# License

This project is licensed under the MIT License. See the `LICENSE` file for details.
