function stats_results = perform_statistical_tests(varargin)
% PERFORM_STATISTICAL_TESTS  Paired tests and effect sizes on weekly KPIs.
% Author: Venkatesh
%
%   stats_results = PERFORM_STATISTICAL_TESTS(Name,Value,...) loads weekly
%   KPI tables (Before/After), performs paired t-tests, computes Cohen's d,
%   and returns a summary table.
%
%   Name-Value Options
%   ------------------
%   'KpiBeforeFile' (char) default '../output/tables/weekly_kpis_before.csv'
%   'KpiAfterFile'  (char) default '../output/tables/weekly_kpis_after.csv'
%   'OutputFile'    (char) default ''   % optional CSV path

% ---- Parse inputs ----
p = inputParser;
addParameter(p, 'KpiBeforeFile', '../output/tables/weekly_kpis_before.csv', @ischar);
addParameter(p, 'KpiAfterFile',  '../output/tables/weekly_kpis_after.csv',  @ischar);
addParameter(p, 'OutputFile',    '', @ischar);
parse(p, varargin{:});
opt = p.Results;

fprintf('Loading weekly KPI data...\n');
kb = readtable(opt.KpiBeforeFile);
ka = readtable(opt.KpiAfterFile);

% Ensure same length for paired testing
n = min(height(kb), height(ka));
kb = kb(1:n, :);
ka = ka(1:n, :);

metrics = {'Availability','Performance','Quality','OEE','PPM','OTD','MLT_days'};
results = cell(numel(metrics), 5);

fprintf('Running paired t-tests and effect sizes...\n');
for i = 1:numel(metrics)
    m = metrics{i};
    b = kb.(m); a = ka.(m);

    [~, pval, ci, stats] = ttest(a, b);     % after vs before (paired)
    diff = a - b;
    sd_diff = std(diff);
    if sd_diff == 0
        d = sign(mean(diff)) * inf;
    else
        d = mean(diff) / sd_diff;           % Cohen's d for paired
    end
    results(i,:) = {m, pval, stats.tstat, ci(1), d};
end

stats_results = cell2table(results, 'VariableNames', ...
    {'Metric','P_Value','T_Statistic','CI_Lower','Cohens_d'});

% Significance & effect-size labels
stats_results.Is_Significant_p05 = stats_results.P_Value < 0.05;
labels = strings(height(stats_results),1);
absd = abs(stats_results.Cohens_d);
labels(absd >= 0.8) = "Large";
labels(absd >= 0.5 & absd < 0.8) = "Medium";
labels(absd >= 0.2 & absd < 0.5) = "Small";
labels(absd < 0.2) = "Trivial";
stats_results.Effect_Size = labels;

% ---- Save (if requested) ----
if ~isempty(opt.OutputFile)
    outdir = fileparts(opt.OutputFile);
    if ~isempty(outdir) && ~isfolder(outdir), mkdir(outdir); end
    writetable(stats_results, opt.OutputFile);
    fprintf('Saved stats summary to %s\n', opt.OutputFile);
end

% ---- Display ----
fprintf('\n--- STATISTICAL TEST SUMMARY ---\n');
disp(stats_results);
end
