function plot_case_results(varargin)
% PLOT_CASE_RESULTS  Publication-ready figures for HMLV case study.
% Author: Venkatesh
%
%   PLOT_CASE_RESULTS(Name,Value,...) loads Before/After weekly KPIs, job
%   logs, and LMI summary to generate comparison bar charts, run charts,
%   and MLT histograms.
%
%   Name-Value Options
%   ------------------
%   'KpiBeforeFile'   (char) default '../output/tables/weekly_kpis_before.csv'
%   'KpiAfterFile'    (char) default '../output/tables/weekly_kpis_after.csv'
%   'LmiFile'         (char) default '../output/tables/tepi_scmi_lmi_summary.csv'
%   'JobBeforeFile'   (char) default '../output/before_jobs.csv'
%   'JobAfterFile'    (char) default '../output/after_jobs.csv'
%   'FigurePath'      (char) default '../output/figures'
%   'WorkHoursPerDay' (double) default 8    % for MLT in days

% ---- Parse inputs ----
p = inputParser;
addParameter(p, 'KpiBeforeFile','../output/tables/weekly_kpis_before.csv', @ischar);
addParameter(p, 'KpiAfterFile', '../output/tables/weekly_kpis_after.csv',  @ischar);
addParameter(p, 'LmiFile',      '../output/tables/tepi_scmi_lmi_summary.csv', @ischar);
addParameter(p, 'JobBeforeFile','../output/before_jobs.csv', @ischar);
addParameter(p, 'JobAfterFile', '../output/after_jobs.csv',  @ischar);
addParameter(p, 'FigurePath',   '../output/figures', @ischar);
addParameter(p, 'WorkHoursPerDay', 8, @isnumeric);
parse(p, varargin{:});
opt = p.Results;

fprintf('Loading data for plotting...\n');
kb  = readtable(opt.KpiBeforeFile);
ka  = readtable(opt.KpiAfterFile);
lmi = readtable(opt.LmiFile);
jb  = readtable(opt.JobBeforeFile);
ja  = readtable(opt.JobAfterFile);

if ~isfolder(opt.FigurePath), mkdir(opt.FigurePath); end

% Colors
color_before = '#0072BD';
color_after  = '#D95319';

%% 1) Mean KPI comparison
fprintf('Generating KPI comparison bars...\n');
mb = mean(kb{:,2:end});
ma = mean(ka{:,2:end});

f1 = figure('Name','KPI Comparison','Position',[100 100 1200 600]);
tiledlayout(1,4,'Padding','compact','TileSpacing','compact');
title('Mean Weekly KPI Comparison: Before vs After','FontSize',16,'FontWeight','bold');

% OEE
nexttile;
b = bar([mb(4)*100; ma(4)*100]); b.FaceColor = 'flat';
b.CData(1,:) = hex2rgb(color_before); b.CData(2,:) = hex2rgb(color_after);
ylabel('OEE (%)'); set(gca,'XTickLabel',{'Before','After'}); grid on; title('OEE');

% PPM
nexttile;
b = bar([mb(5); ma(5)]); b.FaceColor = 'flat';
b.CData(1,:) = hex2rgb(color_before); b.CData(2,:) = hex2rgb(color_after);
ylabel('Defects (PPM)'); set(gca,'XTickLabel',{'Before','After'}); grid on; title('PPM');

% OTD
nexttile;
b = bar([mb(6)*100; ma(6)*100]); b.FaceColor = 'flat';
b.CData(1,:) = hex2rgb(color_before); b.CData(2,:) = hex2rgb(color_after);
ylabel('OTD (%)'); set(gca,'XTickLabel',{'Before','After'}); grid on; title('OTD');

% MLT
nexttile;
b = bar([mb(7); ma(7)]); b.FaceColor = 'flat';
b.CData(1,:) = hex2rgb(color_before); b.CData(2,:) = hex2rgb(color_after);
ylabel('Lead Time (Days)'); set(gca,'XTickLabel',{'Before','After'}); grid on; title('MLT');

saveas(f1, fullfile(opt.FigurePath, 'kpi_summary_bars.png'));

%% 2) LMI, SCMI, TEPI bars
fprintf('Generating LMI bars...\n');
f2 = figure('Name','LMI Comparison','Position',[100 100 800 500]);
bar([lmi.Before, lmi.After]);
set(gca,'XTickLabel', lmi.Index);
ylabel('Score (0-100)');
title('Lean Maturity Index (LMI) Comparison','FontSize',16,'FontWeight','bold');
legend('Before','After','Location','northwest'); grid on;
ylim([-110, 100]); % show negative TEPI if present
saveas(f2, fullfile(opt.FigurePath, 'lmi_summary_bars.png'));

%% 3) Weekly run charts (OEE, MLT)
fprintf('Generating weekly run charts...\n');
f3 = figure('Name','Weekly Run Charts','Position',[100 100 1000 700]);
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');
title('Weekly Performance Trends','FontSize',16,'FontWeight','bold');

% OEE
nexttile;
plot(kb.Week, kb.OEE*100, 'o-','Color',color_before,'LineWidth',2,'MarkerFaceColor','w'); hold on;
plot(ka.Week, ka.OEE*100, 's--','Color',color_after,'LineWidth',2,'MarkerFaceColor','w');
ylabel('OEE (%)'); xlabel('Week'); title('OEE Trend'); legend('Before','After'); grid on;

% MLT
nexttile;
plot(kb.Week, kb.MLT_days, 'o-','Color',color_before,'LineWidth',2,'MarkerFaceColor','w'); hold on;
plot(ka.Week, ka.MLT_days, 's--','Color',color_after,'LineWidth',2,'MarkerFaceColor','w');
ylabel('Lead Time (Days)'); xlabel('Week'); title('MLT Trend'); legend('Before','After'); grid on;

saveas(f3, fullfile(opt.FigurePath, 'kpi_run_charts.png'));

%% 4) Lead-time distributions
fprintf('Generating MLT distributions...\n');
lt_b = (jb.completion_time - jb.release_time) / (opt.WorkHoursPerDay * 60);
lt_a = (ja.completion_time - ja.release_time) / (opt.WorkHoursPerDay * 60);

f4 = figure('Name','MLT Distribution','Position',[100 100 800 500]);
histogram(lt_b, 'BinWidth', 1, 'FaceColor', color_before, 'FaceAlpha', 0.7); hold on;
histogram(lt_a, 'BinWidth', 1, 'FaceColor', color_after,  'FaceAlpha', 0.7);
title('Distribution of Manufacturing Lead Times','FontSize',16,'FontWeight','bold');
xlabel('Lead Time (Days)'); ylabel('Number of Jobs'); legend('Before','After'); grid on;
xlim([0, max(prctile(lt_a, 99), prctile(lt_b, 99))]);
saveas(f4, fullfile(opt.FigurePath, 'mlt_distribution_hist.png'));

fprintf('\nAll figures saved to %s\n', opt.FigurePath);
end

% --- Helpers ---
function rgb = hex2rgb(hex)
    if startsWith(hex,'#'), hex = hex(2:end); end
    rgb = sscanf(hex, '%2x%2x%2x', [1 3]) / 255;
end
