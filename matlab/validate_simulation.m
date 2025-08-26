function validation_summary = validate_simulation(varargin)
% VALIDATE_SIMULATION  Compare baseline KPIs vs real-world calibration.
% Author: Venkatesh
%
%   validation_summary = VALIDATE_SIMULATION(Name,Value,...) compares
%   simulated baseline KPIs to calibration-derived real KPIs (defect rate
%   and availability proxy), and reports percent difference.
%
%   Name-Value Options
%   ------------------
%   'KpiBeforeFile'  (char) default '../output/tables/weekly_kpis_before.csv'
%   'CalibrationFile'(char) default '../config/calibration.mat'
%   'OutputFile'     (char) default ''   % optional CSV path

% ---- Parse inputs ----
p = inputParser;
addParameter(p, 'KpiBeforeFile',   '../output/tables/weekly_kpis_before.csv', @ischar);
addParameter(p, 'CalibrationFile', '../config/calibration.mat', @ischar);
addParameter(p, 'OutputFile',      '', @ischar);
parse(p, varargin{:});
opt = p.Results;

fprintf('Loading data for validation...\n');
kb = readtable(opt.KpiBeforeFile);
load(opt.CalibrationFile, 'calib');

% Mean baseline KPIs
mkb = mean(kb{:,2:end}, 1);
sim_ppm = mkb(5);
sim_av  = mkb(1);

% Real-world from calibration
real_ppm = calib.defectProp * 1e6;
real_av  = 1 - calib.stop_ratio;

Metric  = {'Defect Rate (PPM)'; 'Availability (%)'};
Real    = [real_ppm; real_av*100];
Sim     = [sim_ppm;  sim_av*100];
PctDiff = (abs(Sim - Real) ./ max(Real, eps)) * 100;

validation_summary = table(Metric, Real, Sim, PctDiff, ...
    'VariableNames', {'Metric','Real_Data_Value','Simulated_Baseline_Value','Percent_Difference'});

% ---- Save (if requested) ----
if ~isempty(opt.OutputFile)
    outdir = fileparts(opt.OutputFile);
    if ~isempty(outdir) && ~isfolder(outdir), mkdir(outdir); end
    writetable(validation_summary, opt.OutputFile);
    fprintf('Saved validation summary to %s\n', opt.OutputFile);
end

fprintf('\n--- SIMULATION VALIDATION SUMMARY ---\n');
disp(validation_summary);
end
