function calib = calibrate_continuous_flow(csvPath, varargin)
% CALIBRATE_CONTINUOUS_FLOW  Calibrate run/stop and quality specs from continuous-flow data.
% Author: Venkatesh
%
%   calib = CALIBRATE_CONTINUOUS_FLOW(csvPath, Name,Value,...) ingests a CSV
%   of time-stamped process signals, detects run/stop periods using an
%   adaptive threshold, estimates stop-duration statistics, selects a
%   realistic quality proxy column, and derives robust spec bands to target
%   a plausible out-of-band/defect rate.
%
%   Required
%   --------
%   csvPath : char/string
%       Path to CSV containing at least a time column and Stage2 signals.
%
%   Name-Value Options
%   ------------------
%   'TimeCol'           (char)   default 'time_stamp'    % datetime-compatible
%   'RateCol'           (char)   default ''               % auto-detected Stage2 *_U_Actual with max variance
%   'QualityCol'        (char)   default ''               % auto-selected among remaining Stage2 *_U_Actual
%   'ResampleMin'       (double) default 1                % minutes between samples after retime
%   'FigurePath'        (char)   default '../output/figures'
%   'ConfigPath'        (char)   default '../config'
%   'SpecBandMethod'    (char)   'MAD' or 'IQR'           % robust banding method
%   'SpecK'             (double) default 3                % band width multiplier
%   'MinStopSamples'    (double) default 2                % filter micro-stops shorter than this (samples)
%   'SmoothWin'         (double) default 3                % movmean window (samples)
%   'TargetStopRange'   (1x2)    default [0.10 0.30]      % desired fraction of stopped samples
%   'EpsilonFracRange'  (1x2)    default [0.05 0.35]      % search range for epsilon as fraction of ideal rate
%
%   Output
%   ------
%   calib : struct with fields
%       file, rateCol, qualityCol, idealRate, epsilon, stop_mu_min, stop_sd_min,
%       cv_rate, spec (low/high/med), defectProp, stop_ratio
%   Side-effects:
%       - Saves MAT config to ConfigPath/calibration.mat
%       - Saves figures to FigurePath:
%           * calibration_run_stop.png
%           * calibration_quality_band.png
%
%   Example
%   -------
%       calib = calibrate_continuous_flow('data/continuous_factory_process.csv', ...
%                 'FigurePath','output/figures','ConfigPath','config');

% ---- Parse inputs ----
p = inputParser;
addParameter(p, 'TimeCol', 'time_stamp', @ischar);
addParameter(p, 'RateCol', '', @ischar);
addParameter(p, 'QualityCol', '', @ischar);
addParameter(p, 'ResampleMin', 1, @(x)isnumeric(x) && x > 0);
addParameter(p, 'FigurePath', '../output/figures', @ischar);
addParameter(p, 'ConfigPath', '../config', @ischar);
addParameter(p, 'SpecBandMethod', 'MAD', @(s)ischar(s) && any(strcmpi(s, {'MAD','IQR'})));
addParameter(p, 'SpecK', 3, @(x)isnumeric(x) && x > 0);
addParameter(p, 'MinStopSamples', 2, @(x)isnumeric(x) && x >= 1);
addParameter(p, 'SmoothWin', 3, @(x)isnumeric(x) && x >= 1);
addParameter(p, 'TargetStopRange', [0.10 0.30], @(v)isnumeric(v) && numel(v)==2 && v(1)>=0 && v(2)<=1);
addParameter(p, 'EpsilonFracRange', [0.05 0.35], @(v)isnumeric(v) && numel(v)==2 && all(v>0));
parse(p, varargin{:});
opt = p.Results;

% ---- Load & checks ----
fprintf('Loading data from %s...\n', csvPath);
T = readtable(csvPath);
assert(any(strcmpi(T.Properties.VariableNames, opt.TimeCol)), ...
    'Time column "%s" not found.', opt.TimeCol);
t = datetime(T.(opt.TimeCol));

% ---- Auto-select rate column (Stage2 *_U_Actual with max variance) ----
if isempty(opt.RateCol)
    vnames = T.Properties.VariableNames;
    mask = contains(vnames,'Stage2') & contains(vnames,'_U_Actual');
    rcands = vnames(mask);
    assert(~isempty(rcands), 'No Stage2 *_U_Actual columns found for rate.');
    sds = zeros(numel(rcands),1);
    for i = 1:numel(rcands), sds(i) = std(T.(rcands{i}), 'omitnan'); end
    [~,ix] = max(sds); opt.RateCol = rcands{ix};
    fprintf('Auto-selected Rate Column: %s\n', opt.RateCol);
end

% ---- Timetable + resample ----
rateRaw = T.(opt.RateCol);
tt0 = timetable(t, rateRaw, 'VariableNames', {'rate'});
tt0 = sortrows(tt0);
tt  = retime(tt0, 'regular', 'mean', 'TimeStep', minutes(opt.ResampleMin));
rt  = tt.Properties.RowTimes;

% ---- Adaptive run/stop threshold ----
fprintf('Calibrating run/stop threshold...\n');
sm_rate   = movmean(tt.rate, opt.SmoothWin, 'omitnan');
idealRate = prctile(tt.rate, 95);
fracs = linspace(opt.EpsilonFracRange(1), opt.EpsilonFracRange(2), 20);

bestEpsilon = fracs(1)*idealRate; bestFit = inf; bestIsRun = [];
for k = 1:numel(fracs)
    epsk = fracs(k)*idealRate;
    isRun_k = sm_rate > epsk;
    stopRatio = mean(~isRun_k, 'omitnan');
    fit = localPenalty(stopRatio, opt.TargetStopRange);
    if fit < bestFit
        bestFit = fit; bestEpsilon = epsk; bestIsRun = isRun_k;
    end
end
epsilon = bestEpsilon; isRun = bestIsRun;

% ---- Stop durations (filter micro-stops) ----
fprintf('Analyzing stop durations...\n');
d = diff([false; isRun; false]);
stopStarts = find(d == -1);
stopEnds   = find(d == 1) - 1;

shortStops = (stopEnds - stopStarts + 1) < opt.MinStopSamples;
stopStarts(shortStops) = []; stopEnds(shortStops) = [];

if isempty(stopStarts)
    stopDurMin = [];
else
    stopDurMin = minutes(rt(stopEnds) - rt(stopStarts));
    stopDurMin = stopDurMin(stopDurMin > 0);
end
stop_mu = mean(stopDurMin, 'omitnan');
stop_sd = std(stopDurMin, 'omitnan');

% ---- Rate variability on run-only samples ----
runRates = tt.rate(isRun);
cv_rate = std(runRates, 'omitnan') / max(mean(runRates, 'omitnan'), eps);

% ---- Auto-select quality proxy to yield realistic defect proportion ----
fprintf('Auto-selecting best quality proxy column...\n');
vnames = T.Properties.VariableNames;
qcands = vnames(contains(vnames,'Stage2') & contains(vnames,'_U_Actual'));
qcands = setdiff(qcands, {opt.RateCol}, 'stable');

targetDefectRange = [0.005, 0.05]; % 0.5%–5%
bestQCol = ''; bestDefectFit = inf;
bestSpec = struct('low', NaN, 'high', NaN, 'med', NaN);

for i = 1:numel(qcands)
    q_tt = retime(timetable(t, T.(qcands{i})), 'regular', 'mean', 'TimeStep', minutes(opt.ResampleMin));
    [~, ia, ib] = intersect(tt.Properties.RowTimes, q_tt.Properties.RowTimes);
    measRun = q_tt.Var1(ib);
    isRun_aligned = isRun(ia);
    measRun = measRun(isRun_aligned);
    if isempty(measRun) || all(isnan(measRun)), continue; end

    medM = median(measRun, 'omitnan');
    if strcmpi(opt.SpecBandMethod,'MAD')
        madM = median(abs(measRun - medM), 'omitnan');
        low  = medM - opt.SpecK * madM;
        high = medM + opt.SpecK * madM;
    else
        q25 = prctile(measRun, 25); q75 = prctile(measRun, 75);
        iqrV = q75 - q25; low = q25 - 1.5*iqrV; high = q75 + 1.5*iqrV;
    end

    defP = mean(measRun < low | measRun > high, 'omitnan');
    fit  = localPenalty(defP, targetDefectRange);
    if fit < bestDefectFit
        bestDefectFit = fit; bestQCol = qcands{i};
        bestSpec.low  = low; bestSpec.high = high; bestSpec.med = medM;
    end
end

% ---- Final defect proportion ----
final_q_tt = retime(timetable(t, T.(bestQCol)), 'regular', 'mean', 'TimeStep', minutes(opt.ResampleMin));
[~, ia, ib] = intersect(tt.Properties.RowTimes, final_q_tt.Properties.RowTimes);
finalMeasRun = final_q_tt.Var1(ib);
finalIsRun   = isRun(ia);
finalMeasRun = finalMeasRun(finalIsRun);
defectProp   = mean(finalMeasRun < bestSpec.low | finalMeasRun > bestSpec.high, 'omitnan');

% ---- Pack & save ----
fprintf('Saving results...\n');
calib = struct( ...
    'file',        csvPath, ...
    'rateCol',     opt.RateCol, ...
    'qualityCol',  bestQCol, ...
    'idealRate',   idealRate, ...
    'epsilon',     epsilon, ...
    'stop_mu_min', stop_mu, ...
    'stop_sd_min', stop_sd, ...
    'cv_rate',     cv_rate, ...
    'spec',        bestSpec, ...
    'defectProp',  defectProp, ...
    'stop_ratio',  mean(~isRun, 'omitnan'));

if ~isfolder(opt.FigurePath), mkdir(opt.FigurePath); end
if ~isfolder(opt.ConfigPath), mkdir(opt.ConfigPath); end

% Plot 1: rate + threshold
f1 = figure('Name','Run-Stop & Rate','Visible','off');
plot(rt, tt.rate, 'b-'); hold on;
plot(rt, sm_rate, 'g-', 'LineWidth', 1.5);
yline(epsilon, 'r--', 'LineWidth', 2);
title(sprintf('Throughput & Detected Run/Stop State (Stop Ratio: %.1f%%)', 100*calib.stop_ratio));
xlabel('Time'); ylabel('Rate (units/min)');
legend('Raw Rate','Smoothed Rate','Stop Threshold (\epsilon)'); grid on;
saveas(f1, fullfile(opt.FigurePath, 'calibration_run_stop.png')); close(f1);

% Plot 2: quality histogram + spec band
f2 = figure('Name','Quality Band','Visible','off');
histogram(finalMeasRun, 100, 'FaceColor', '#0072BD', 'EdgeColor', 'w'); hold on;
xline(bestSpec.low,  'r--', 'LineWidth', 2);
xline(bestSpec.high, 'r--', 'LineWidth', 2);
title(sprintf('Quality Proxy: %s (Defect Prop. ~ %.2f%%)', bestQCol, 100*defectProp));
xlabel(strrep(bestQCol, '_', ' ')); ylabel('Frequency');
legend('Distribution','Lower Spec Limit','Upper Spec Limit'); grid on;
saveas(f2, fullfile(opt.FigurePath, 'calibration_quality_band.png')); close(f2);

save(fullfile(opt.ConfigPath, 'calibration.mat'), 'calib');

% Console summary
fprintf('\n=== Calibration Summary ===\n');
fprintf('File: %s\n', csvPath);
fprintf('Rate column:    %s\n', opt.RateCol);
fprintf('Quality column: %s\n', bestQCol);
fprintf('Ideal rate (p95): %.4f (units/min)\n', idealRate);
fprintf('Run epsilon:      %.4f (%.1f%% of ideal)\n', epsilon, 100*epsilon/max(idealRate, eps));
fprintf('Stop ratio:       %.1f%% of samples\n', 100*calib.stop_ratio);
fprintf('Stop mean (min):  %.2f,  SD: %.2f\n', calib.stop_mu_min, calib.stop_sd_min);
fprintf('Rate CV:          %.3f\n', cv_rate);
fprintf('DefectProp:       %.2f%%\n', 100*defectProp);
fprintf('Spec band [%s]:  [%.4f, %.4f]\n', opt.SpecBandMethod, bestSpec.low, bestSpec.high);
fprintf('Saved: %s and figures in %s\n\n', fullfile(opt.ConfigPath, 'calibration.mat'), opt.FigurePath);
end

% ---- Local helper ----
function f = localPenalty(value, targetRange)
    if value >= targetRange(1) && value <= targetRange(2)
        f = 0;
    else
        f = min(abs(value - targetRange(1)), abs(value - targetRange(2)));
    end
end
