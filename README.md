# specparam-toolbox

[![MATLAB](https://img.shields.io/badge/MATLAB-R2022b%2B-blue.svg)](https://www.mathworks.com/)
[![Python](https://img.shields.io/badge/Python-3.7%2B-blue.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A MATLAB toolbox for the Python [`specparam`](https://github.com/fooof-tools/fooof) (formerly **FOOOF**) package for parameterizing neural power spectra into periodic and aperiodic components.

The toolbox interfaces directly with the Python implementation through MATLAB's built-in Python interface, providing a complete MATLAB workflow for spectral parameterization, visualization, reporting, batch processing, and model serialization without leaving MATLAB.

Unlike previous MATLAB wrappers, this toolbox targets the current **specparam (v2)** API and extends it with MATLAB-native utilities for plotting, reporting, saving/loading models, batch processing, and automated analysis pipelines.

---

# Features

- Native MATLAB interface to the Python `specparam` package
- Single-spectrum spectral parameterization
- Batch processing of large collections of spectra
- Multi-session analysis utilities
- Automatic validation of model settings
- Robust handling of failed model fits
- Optional reconstruction of fitted model components
- Publication-quality plotting utilities
- Automatic report generation
- Save and load fitted models
- MATLAB-native data structures
- Toolbox version utilities

---

# Toolbox Architecture

```text
                    Raw Neural Signal
                            │
                            ▼
        (Optional) Zero-Phase FIR Notch Filtering
                            │
                            ▼
        Chronux (`mtspectrumc`) Multi-Taper PSD
                            │
                            ▼
                  Neural Power Spectrum
                            │
                            ▼
              Python `specparam` Spectral Model
                            │
                            ▼
                 MATLAB Results Structure
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
     Plotting            Reporting          Save / Load
```

This toolbox performs **spectral parameterization**, not spectral estimation. Power spectra are supplied by the user and may be generated using Chronux, EEGLAB, FieldTrip, Welch's method, or any other spectral estimation approach. During development, spectra were estimated using the Chronux multitaper implementation (`mtspectrumc`).

---

# Function Reference

## Core Modeling

| Function | Description |
|----------|-------------|
| `specparam()` | Fit a single neural power spectrum. |
| `specparam_group()` | Fit every spectrum in a matrix of power spectra. |
| `specparam_ms()` | Fit spectra using the multi-session interface. |
| `specparam_group_ms()` | Batch fit multi-session datasets. |
| `specparam_get_model()` | Return reconstructed model components from fitted results. |
| `specparam_check_settings()` | Validate user settings and populate missing defaults. |

## Visualization

| Function | Description |
|----------|-------------|
| `specparam_plot()` | Plot complete model fits. |
| `specparam_plot_aperiodic_fits()` | Plot reconstructed aperiodic fits. |
| `specparam_plot_aperiodic_params()` | Visualize estimated aperiodic parameters. |
| `specparam_plot_peak_fits()` | Plot reconstructed oscillatory peak fits. |
| `specparam_plot_peak_params()` | Visualize extracted oscillatory peak parameters. |

## Utilities

| Function | Description |
|----------|-------------|
| `specparam_report()` | Generate a formatted report summarizing model settings and fit results. |
| `specparam_save()` | Save fitted model results to disk. |
| `specparam_load()` | Load previously saved model results. |
| `specparam_version()` | Display toolbox version information. |

---

# Requirements

## Required

- MATLAB (R2022b or newer recommended)
- MATLAB Python Interface (`pyenv`)
- Python 3.7 or newer
- Python `specparam` package

Install the Python package with

```shell
pip install specparam
```

Verify the installation

```shell
python -c "import specparam"
```

## Recommended

Although any power spectral estimation method may be used, this toolbox was developed and tested using the **Chronux** toolbox for multi-taper spectral estimation.

Chronux can be downloaded from:

http://chronux.org/

---

# Installation

Clone the repository

```shell
git clone https://github.com/<your-username>/specparam-toolbox
```

Add the toolbox to the MATLAB path

```matlab
addpath(genpath('/path/to/specparam-toolbox'))
```

Configure MATLAB to use the desired Python installation

```matlab
pyenv('Version','/path/to/python')
```

Verify MATLAB can access the Python package

```matlab
py.importlib.import_module('specparam')
```

If no errors are produced, MATLAB is correctly configured and the toolbox is ready for use.

---
# Spectral Estimation Pipeline

This toolbox parameterizes **power spectra**, not raw neural recordings. Users may estimate spectra using any preferred method before fitting them with `specparam`. During development, the recommended workflow consisted of:

1. (Optional) Removal of narrow-band electrical line noise.
2. Power spectral estimation using the Chronux toolbox's `mtspectrumc` function.
3. Spectral parameterization using the Python `specparam` package.
4. Visualization, reporting, and serialization of fitted models using this toolbox.

---

## Power Spectrum Estimation

Power spectra used during development were generated using the Chronux toolbox's `mtspectrumc` function, which implements **Thomson's multitaper spectral estimation**.

Unlike conventional FFT or Welch-based methods, multitaper spectral estimation uses multiple orthogonal **Discrete Prolate Spheroidal Sequences (DPSS; Slepian tapers)** to produce statistically independent estimates of the spectrum. Averaging across these tapers substantially reduces spectral variance while preserving frequency resolution.

The multitaper approach is particularly well suited for neural electrophysiology because it provides smoother spectral estimates without obscuring narrow oscillatory peaks, making it an ideal preprocessing step for spectral parameterization.

Chronux's `mtspectrumc` function allows users to specify:

- Sampling frequency
- Frequency range of interest
- Time-bandwidth product
- Number of DPSS tapers
- FFT padding
- Confidence interval estimation
- Trial averaging

The resulting power spectrum can then be passed directly to `specparam()`.

---

## Optional Line Noise Removal

Prior to spectral estimation, neural recordings may optionally be filtered using a zero-phase finite impulse response (FIR) notch filter.

The included helper function (`simple_notch_filter`) removes narrow-band electrical interference (e.g., 50 Hz, 60 Hz, and harmonics) using forward-backward filtering (`filtfilt`), eliminating phase distortion while preserving waveform timing.

This preprocessing step is optional and depends on the recording environment and experimental setup.

---

## Spectral Parameterization

Once a power spectrum has been estimated, it is fit using the Python `specparam` package through MATLAB's Python interface.

The model decomposes the spectrum into:

- an **aperiodic component** (1/f-like background activity)
- one or more **periodic components** (putative oscillatory peaks)

The toolbox extracts and stores:

- aperiodic parameters
- oscillatory peak parameters
- goodness-of-fit metrics
- reconstructed model components
- fitting settings
- optional reconstructed spectra

All outputs are returned as MATLAB structures, making them easy to integrate into existing MATLAB workflows.

---

# Basic Usage

## Fitting a Single Power Spectrum

```matlab
% freqs and power_spectrum are 1D row vectors.
% power_spectrum should contain LINEAR (not log-transformed) power values.

f_range = [3 40];

settings = struct();

settings.peak_width_limits = [1 8];
settings.max_n_peaks       = 6;
settings.min_peak_height   = 0.1;
settings.peak_threshold    = 2;
settings.aperiodic_mode    = 'fixed';

results = specparam(freqs, power_spectrum, f_range, settings);
```

The returned MATLAB structure contains

```matlab
results.aperiodic_params
results.peak_params
results.error
results.r_squared
results.fit_ok
```

> **Important**
>
> The input spectrum must contain **linear power values**. The Python `specparam` implementation performs its own logarithmic transformation internally. Supplying log-transformed spectra will produce incorrect parameter estimates.

---

## Returning Model Components

To additionally return the reconstructed model curves

```matlab
results = specparam(freqs, power_spectrum, f_range, settings, true);

results.freqs
results.power_spectrum
results.specparamed_spectrum
results.ap_fit
```

These outputs can be used for custom visualization or downstream analyses.

---

## Batch Fitting

Power spectra are commonly organized as an **Nfreq × Nspectra** matrix, where each column represents one spectrum.

```matlab
group_results = specparam_group(freqs, psds, f_range, settings);
```

`specparam_group()` iterates over every column of the PSD matrix, fits each spectrum individually using `specparam()`, and returns a MATLAB struct array containing one fitted model per spectrum.

---

## Multi-Session Fitting

For experiments containing multiple recording sessions, the toolbox also provides dedicated multi-session interfaces.

```matlab
results = specparam_ms(...)

group_results = specparam_group_ms(...)
```

These functions provide the same outputs as their single-session counterparts while simplifying the processing of larger experimental datasets.

---
```
# Function Reference

## `specparam()`

Fits a single power spectrum using the Python `specparam` model.

### Syntax

```matlab
results = specparam(freqs, power_spectrum, f_range, settings)
```

or

```matlab
results = specparam(freqs, power_spectrum, f_range, settings, return_model)
```

### Inputs

| Input | Description |
|--------|-------------|
| `freqs` | Frequency vector (Hz). |
| `power_spectrum` | One-dimensional power spectrum (linear power values). |
| `f_range` | Frequency range over which to fit the model. |
| `settings` | MATLAB structure containing `specparam` model settings. |
| `return_model` | Logical value specifying whether reconstructed model components should be returned. Default: `false`. |

### Outputs

The returned MATLAB structure contains

| Field | Description |
|--------|-------------|
| `aperiodic_params` | Estimated aperiodic parameters. |
| `peak_params` | Oscillatory peak parameters. |
| `gaussian_params` | Gaussian parameters describing fitted peaks. |
| `error` | Mean absolute model error. |
| `r_squared` | Goodness-of-fit statistic. |
| `fit_ok` | Indicates whether the fit completed successfully. |

When `return_model = true`, the following fields are also included:

| Field | Description |
|--------|-------------|
| `freqs` | Frequency vector used during fitting. |
| `power_spectrum` | Original power spectrum. |
| `specparamed_spectrum` | Reconstructed model spectrum. |
| `ap_fit` | Reconstructed aperiodic fit. |

---

## `specparam_group()`

Fits an entire collection of spectra.

### Syntax

```matlab
group_results = specparam_group(freqs, psds, f_range, settings)
```

### Inputs

| Input | Description |
|--------|-------------|
| `freqs` | Frequency vector. |
| `psds` | Matrix of power spectra (`Nfreq × Nspectra`). Each column is fit independently. |
| `f_range` | Frequency range for fitting. |
| `settings` | MATLAB settings structure. |

### Output

Returns a MATLAB struct array containing one fitted model for every input spectrum.

---

## `specparam_ms()`

Fits spectra using the toolbox's multi-session interface.

This function is intended for datasets organized across multiple recording sessions while maintaining a consistent interface with `specparam()`.

---

## `specparam_group_ms()`

Batch fits collections of spectra organized by recording session.

The returned structure preserves session organization while providing the same model outputs returned by `specparam_group()`.

---

## `specparam_get_model()`

Returns reconstructed model components from a fitted model.

This utility provides convenient access to reconstructed spectra, allowing users to generate custom visualizations or perform downstream analyses without manually extracting fields from the returned structure.

---

## `specparam_check_settings()`

Validates user-specified settings and automatically populates unspecified parameters using toolbox defaults.

This function ensures compatibility with the Python `specparam` implementation while allowing users to specify only the parameters they wish to modify.

---

# Visualization

The toolbox includes several MATLAB plotting utilities for visualizing fitted models and extracted parameters.

---

## `specparam_plot()`

Plots a complete spectral parameterization including

- Original power spectrum
- Reconstructed model
- Aperiodic fit
- Flattened spectrum
- Detected oscillatory peaks

```matlab
specparam_plot(results)
```

---

## `specparam_plot_aperiodic_fits()`

Visualizes reconstructed aperiodic model fits.

```matlab
specparam_plot_aperiodic_fits(results)
```

---

## `specparam_plot_aperiodic_params()`

Plots estimated aperiodic parameters across one or more fitted spectra.

```matlab
specparam_plot_aperiodic_params(group_results)
```

---

## `specparam_plot_peak_fits()`

Visualizes reconstructed oscillatory peak fits.

```matlab
specparam_plot_peak_fits(results)
```

---

## `specparam_plot_peak_params()`

Displays extracted oscillatory peak parameters, including

- Center frequency
- Peak height
- Bandwidth

```matlab
specparam_plot_peak_params(group_results)
```

These plotting functions are intended to provide publication-quality visualizations while remaining fully customizable using standard MATLAB graphics commands.

---

# Reporting

## `specparam_report()`

Generates a formatted summary of a fitted model.

```matlab
specparam_report(results)
```

The generated report includes

- Toolbox version
- Model settings
- Frequency range
- Aperiodic parameters
- Oscillatory peak parameters
- Goodness-of-fit metrics
- Number of detected peaks
- Model error

The report provides a convenient human-readable summary of the fitted model and can be used for quality control or record keeping.

---

# Saving and Loading Models

## `specparam_save()`

Save fitted models to disk.

```matlab
specparam_save(results,'model.mat')
```

The saved file preserves the complete MATLAB results structure, allowing models to be reloaded without recomputing spectral parameterization.

---

## `specparam_load()`

Load previously saved models.

```matlab
results = specparam_load('model.mat')
```

Loaded models retain all stored parameters, reconstructed spectra, settings, and metadata exactly as they were originally saved.

---

# Settings

Model behavior is controlled through a MATLAB structure passed to `specparam()`, `specparam_group()`, `specparam_ms()`, or `specparam_group_ms()`.

Only the settings you wish to modify need to be specified. Any omitted settings are automatically populated with default values by `specparam_check_settings()`.

## Available Settings

| Setting | Description | Default |
|----------|-------------|---------|
| `peak_width_limits` | Minimum and maximum allowable peak bandwidth (Hz). | `[0.5 12]` |
| `max_n_peaks` | Maximum number of oscillatory peaks to fit. | `Inf` |
| `min_peak_height` | Minimum absolute peak height above the aperiodic fit (log power). | `0` |
| `peak_threshold` | Minimum relative peak height (standard deviations above the flattened spectrum). | `2` |
| `aperiodic_mode` | Aperiodic model (`'fixed'`, `'knee'`, `'doublexp'`, etc.). | `'fixed'` |
| `verbose` | Display fitting information during execution. | `false` |

Example:

```matlab
settings = struct();

settings.peak_width_limits = [1 8];
settings.max_n_peaks       = 6;
settings.min_peak_height   = 0.1;
settings.peak_threshold    = 2;
settings.aperiodic_mode    = 'fixed';
```

---

# Understanding Peak-Fitting Parameters

The `specparam` algorithm identifies oscillatory peaks by iteratively fitting the largest remaining peak in the flattened spectrum until one of several stopping criteria is reached.

## `peak_width_limits`

This setting constrains how narrow or broad fitted peaks are allowed to be.

```matlab
settings.peak_width_limits = [1 8];
```

The lower limit should generally be at least **twice the frequency resolution** of the input spectrum. Otherwise, isolated frequency bins may be incorrectly identified as oscillatory peaks.

---

## `max_n_peaks`

Sets the maximum number of oscillatory peaks that may be fit.

```matlab
settings.max_n_peaks = 6;
```

Once this limit is reached, peak extraction stops even if additional candidate peaks remain.

---

## `peak_threshold`

Specifies the minimum **relative** peak height required for a candidate peak to be accepted.

```matlab
settings.peak_threshold = 2;
```

The threshold is expressed as the number of standard deviations above the flattened spectrum.

Larger values produce more conservative peak detection.

---

## `min_peak_height`

Specifies the minimum **absolute** peak height above the estimated aperiodic fit.

```matlab
settings.min_peak_height = 0.1;
```

Unlike `peak_threshold`, this value is measured in log-power units rather than standard deviations.

---

## Peak Search Stopping Criteria

Peak extraction terminates whenever **any** of the following conditions are met:

1. The maximum number of peaks (`max_n_peaks`) has been reached.
2. The next candidate peak falls below `peak_threshold`.
3. The next candidate peak falls below `min_peak_height`.

Both thresholds operate independently.

---

## Aperiodic Modes

The toolbox supports every aperiodic model implemented by the installed version of Python `specparam`.

Common options include

| Mode | Parameters Returned |
|------|----------------------|
| `'fixed'` | Offset, Exponent |
| `'knee'` | Offset, Knee, Exponent |
| `'doublexp'` | Four-parameter double exponential model |

The size of `results.aperiodic_params` is automatically adjusted based on the selected model.

---

# Failure Handling

Occasionally, individual spectra cannot be successfully parameterized.

Unlike many MATLAB wrappers, this toolbox is designed to continue processing even when individual spectra fail.

If fitting fails:

- A MATLAB warning is issued containing the underlying Python error message.
- A MATLAB results structure is still returned.
- Parameter fields are filled with appropriately-sized `NaN` values.
- `results.fit_ok` is set to `false`.
- Placeholder model fields are created when reconstructed model outputs were requested.

This behavior allows batch-processing functions such as `specparam_group()` and `specparam_group_ms()` to continue fitting the remaining spectra instead of terminating the entire analysis.

When analyzing multiple spectra, users should always verify

```matlab
results.fit_ok
```

before interpreting model parameters.

---

# Version Information

The toolbox version can be displayed using

```matlab
specparam_version()
```

Including the toolbox version in publications and analysis pipelines is recommended to improve reproducibility.

---

# Further Reading

For detailed information regarding the underlying spectral parameterization algorithm, please consult the official `specparam` documentation.

Current documentation:

https://specparam-tools.github.io/

Legacy FOOOF documentation:

https://fooof-tools.github.io/fooof/

The tutorials cover:

- Model assumptions
- Selection of fitting parameters
- Interpretation of aperiodic parameters
- Interpretation of oscillatory peaks
- Best practices for spectral parameterization
- Common pitfalls

These resources complement the MATLAB toolbox documentation and provide a deeper explanation of the underlying methodology.

---

# Citation

If you use this toolbox in published work, please cite the original spectral parameterization method.

> Donoghue T, Haller M, Peterson EJ, Varma P, Sebastian P, Gao R, Noto T, Lara AH, Wallis JD, Knight RT, Shestyuk A, & Voytek B. (2020). *Parameterizing neural power spectra into periodic and aperiodic components.* Nature Neuroscience, **23**, 1655–1665. https://doi.org/10.1038/s41593-020-00744-x

The Python implementation used by this toolbox is available at:

https://github.com/fooof-tools/fooof

For the latest documentation and tutorials, see:

https://specparam-tools.github.io/

---

# Acknowledgments

This project was inspired by the original **fooof_mat** MATLAB wrapper developed by the fooof-tools team, which demonstrated how to interface MATLAB with the Python implementation of the spectral parameterization algorithm.

This toolbox has since been substantially redesigned and expanded for the current **specparam** API. In addition to single-spectrum fitting, it includes

- Batch fitting utilities
- Multi-session analysis support
- Robust failure handling
- MATLAB-native plotting functions
- Automated report generation
- Save and load utilities
- Optional reconstructed model outputs
- Support for multiple aperiodic models
- Automatic settings validation
- Expanded documentation
- MATLAB-native workflows for large-scale neural data analysis

The underlying spectral parameterization algorithm remains the excellent work of the **specparam** developers. This toolbox simply provides a MATLAB-native interface and additional utilities for integrating `specparam` into MATLAB-based neuroscience workflows.

The original MATLAB wrapper can be found at

https://github.com/fooof-tools/fooof_mat

The Chronux toolbox was used during development for multitaper power spectral estimation. Chronux provides efficient implementations of Thomson's multitaper methods for neural time-series analysis and is available at

http://chronux.org/

The authors of both the `specparam` and Chronux projects deserve full credit for their respective algorithms and software.

---

# Contributing

Contributions are welcome.

Bug reports, feature requests, documentation improvements, and pull requests are encouraged.

When contributing, please

- Follow the existing coding style.
- Include comments for new functionality.
- Update documentation where appropriate.
- Test new features before submitting a pull request.

If you encounter a bug, please include

- MATLAB version
- Python version
- `specparam` version
- Operating system
- A minimal reproducible example
- The complete error message

---

# Roadmap

Potential future additions include

- Parallel batch fitting (`parfor`)
- Native support for MATLAB tables and timetables
- Interactive visualization utilities
- Automatic export of figures for publication
- Batch report generation
- Live Script tutorials
- MATLAB App Designer interface
- Unit testing framework
- Continuous integration (GitHub Actions)
- MATLAB Toolbox (.mltbx) packaging

Suggestions for new features are always welcome.

---

# License

MIT License

Copyright (c) 2026 Jeremiah Satcho

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
