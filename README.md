# MATLAB Toolkit for Lean Implementation in Bespoke SMEs

This repository contains a suite of MATLAB functions and scripts to support data analysis, simulation, and evaluation for lean implementation case studies in bespoke small/medium manufacturing enterprises (SMEs).

## Directory Structure

```
matlab/
  calibrate_continuous_flow.m
  compute_kpis_from_jobs.m
  compute_tepi_scmi_lmi.m
  run_calibration.m
  define_params_from_calibration.m
  perform_statistical_tests.m
  simulate_hmlv.m
  validate_simulation.m
data/
output/
  figures/
config/
```

## File Descriptions

- **matlab/calibrate_continuous_flow.m**  
  Calibrates run/stop and quality metrics from continuous-flow process data in CSV format. Auto-selects relevant columns, computes robust spec bands, and saves results and figures.  
  _Run using:_  
  ```matlab
  calib = calibrate_continuous_flow('data/continuous_factory_process.csv', 'FigurePath', 'output/figures', 'ConfigPath', 'config');
  ```

- **matlab/compute_kpis_from_jobs.m**  
  Aggregates simulated job logs into weekly KPIs such as Availability, OEE, Quality, PPM, OTD, and MLT (lead time).  
  _Run using:_  
  ```matlab
  weekly_kpis = compute_kpis_from_jobs('output/before_jobs.csv');
  ```

- **matlab/compute_tepi_scmi_lmi.m**  
  Combines weekly KPIs and socio-cultural maturity index (SCMI) scores to compute TEPI and Lean Maturity Index (LMI).  
  _Run using:_  
  ```matlab
  lmi_summary = compute_tepi_scmi_lmi();
  ```

- **matlab/run_calibration.m**  
  Example script to reproduce calibration outputs for the dissertation.  
  _Run using:_  
  ```matlab
  run('matlab/run_calibration.m');
  ```

- **matlab/define_params_from_calibration.m**  
  Loads calibration results and builds 'before' and 'after' simulation parameter structures, saved to config/.  
  _Run using:_  
  ```matlab
  run('matlab/define_params_from_calibration.m');
  ```

- **matlab/perform_statistical_tests.m**  
  Runs paired t-tests and computes effect sizes (Cohen's d) for weekly KPIs before and after lean implementation.  
  _Run using:_  
  ```matlab
  stats_results = perform_statistical_tests();
  ```

- **matlab/simulate_hmlv.m**  
  Discrete-event simulator for a high-mix low-volume (HMLV) job shop using parameters from config/. Outputs job logs.  
  _Run using:_  
  ```matlab
  job_log = simulate_hmlv('config/params_before.mat', 'NumJobs', 200);
  ```

- **matlab/validate_simulation.m**  
  Compares simulated baseline KPIs to real-world calibration-derived values and reports percent differences.  
  _Run using:_  
  ```matlab
  validation_summary = validate_simulation();
  ```

## How to Run

1. Place your input CSV files in the `data/` directory.
2. Run MATLAB scripts from the `matlab/` folder. Ensure you have write access to `output/` and `config/` folders.
3. Generated figures are saved in `output/figures/`, and parameter/config files in `config/`.

## Requirements

- MATLAB R2018b or newer (recommended)
- Statistics and Machine Learning Toolbox (for some functions)

## Notes

- Adjust file paths in scripts/functions if your directory structure differs.
- For large-scale simulations or calibration, ensure sufficient disk space for output files.

---

For questions, contact [Venkatesh](mailto:venkateshmakkena53@gmail.com).
