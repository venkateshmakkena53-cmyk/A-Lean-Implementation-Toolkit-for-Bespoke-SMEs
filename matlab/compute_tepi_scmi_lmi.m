function lmi_summary = compute_tepi_scmi_lmi(varargin)
% COMPUTE_TEPI_SCMI_LMI  Combine SCMI and TEPI into final LMI.
% Author: Venkatesh
%
%   lmi_summary = COMPUTE_TEPI_SCMI_LMI(Name,Value,...) loads weekly KPIs
%   (Before/After) and SCMI scores, computes TEPI for each period, then
%   forms the Lean Maturity Index (LMI) as 0.5*SCMI + 0.5*TEPI.
%
%   Name-Value Options
%   ------------------
%   'KpiBeforeFile' (char) default '../output/tables/weekly_kpis_before.csv'
%   'KpiAfterFile'  (char) default '../output/tables/weekly_kpis_after.csv'
%   'ScmiFile'      (char) default '../output/tables/scmi_before_after.csv'
%   'OutputFile'    (char) default ''   % optional CSV path

% ---- Parse inputs ----
p = inputParser;
addParameter(p, 'KpiBeforeFile', '../output/tables/weekly_kpis_before.csv', @ischar);
addParameter(p, 'KpiAfterFile',  '../output/tables/weekly_kpis_after.csv',  @ischar);
addParameter(p, 'ScmiFile',      '../output/tables/scmi_before_after.csv',  @ischar);
addParameter(p, 'OutputFile',    '', @ischar);
parse(p, varargin{:});
opt = p.Results;

fprintf('Loading KPI and SCMI data...\n');
kpis_before = readtable(opt.KpiBeforeFile);
kpis_after  = readtable(opt.KpiAfterFile);
scmi_table  = readtable(opt.ScmiFile);

% ---- Mean weekly KPIs per period ----
mean_kpis_before = varfun(@mean, kpis_before, 'InputVariables', @isnumeric);
mean_kpis_after  = varfun(@mean, kpis_after,  'InputVariables', @isnumeric);

% SCMI (0–100)
scmi_before = scmi_table.Before(strcmp(scmi_table.Variable, 'SCMI_Score'));
scmi_after  = scmi_table.After( strcmp(scmi_table.Variable, 'SCMI_Score'));

fprintf('Calculating TEPI and LMI...\n');

% ---- TEPI targets / baselines ----
oee_target   = 0.85;
otd_target   = 0.95;
ppm_baseline = mean_kpis_before.mean_PPM;
mlt_baseline = mean_kpis_before.mean_MLT_days;

% ---- Before TEPI ----
oee_b = mean_kpis_before.mean_OEE;
ppm_b = mean_kpis_before.mean_PPM;
otd_b = mean_kpis_before.mean_OTD;
mlt_red_b = 0;

tepi_before = (0.4*(oee_b/oee_target) + ...
               0.3*(1 - (ppm_b/ppm_baseline)) + ...
               0.2*(otd_b/otd_target) + ...
               0.1*mlt_red_b) * 100;

% ---- After TEPI ----
oee_a = mean_kpis_after.mean_OEE;
ppm_a = mean_kpis_after.mean_PPM;
otd_a = mean_kpis_after.mean_OTD;
mlt_a = mean_kpis_after.mean_MLT_days;
mlt_red_a = (mlt_baseline - mlt_a) / max(mlt_baseline, eps);

tepi_after = (0.4*(oee_a/oee_target) + ...
              0.3*(1 - (ppm_a/ppm_baseline)) + ...
              0.2*(otd_a/otd_target) + ...
              0.1*mlt_red_a) * 100;

% ---- LMI ----
lmi_before = 0.5*scmi_before + 0.5*tepi_before;
lmi_after  = 0.5*scmi_after  + 0.5*tepi_after;
delta_lmi  = lmi_after - lmi_before;

Index  = {'SCMI'; 'TEPI'; 'LMI (Lean Maturity Index)'};
Before = [scmi_before; tepi_before; lmi_before];
After  = [scmi_after;  tepi_after;  lmi_after];
Delta  = [scmi_after - scmi_before; tepi_after - tepi_before; delta_lmi];

lmi_summary = table(Index, Before, After, Delta);

% ---- Save (if requested) ----
if ~isempty(opt.OutputFile)
    outdir = fileparts(opt.OutputFile);
    if ~isempty(outdir) && ~isfolder(outdir), mkdir(outdir); end
    writetable(lmi_summary, opt.OutputFile);
    fprintf('Saved TEPI/SCMI/LMI summary to %s\n', opt.OutputFile);
end

% ---- Display ----
fprintf('\n--- FINAL LMI SUMMARY ---\n');
disp(lmi_summary);
end
