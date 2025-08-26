function [weekly_kpis, varargout] = compute_kpis_from_jobs(job_log_file, varargin)
% COMPUTE_KPIS_FROM_JOBS  Aggregate HMLV job-log CSV into weekly KPIs.
% Author: Venkatesh
%
%   [weekly_kpis, ideal_rate_from_sim] = COMPUTE_KPIS_FROM_JOBS(job_log_file, Name,Value,...)
%   reads a simulator job log and computes weekly Availability, Performance,
%   Quality, OEE, PPM, OTD, and MLT (days). If IdealRate is not provided, the
%   function infers it from baseline data and returns it as a second output.
%
%   Name-Value Options
%   ------------------
%   'IdealRate'        (double) default NaN    % jobs/hour; inferred when NaN
%   'OutputFile'       (char)   default ''     % optional CSV path
%   'WorkHoursPerDay'  (double) default 8
%   'WorkDaysPerWeek'  (double) default 5
%
%   Output
%   ------
%   weekly_kpis : table with columns
%       Week, Availability, Performance, Quality, OEE, PPM, OTD, MLT_days
%
%   Notes
%   -----
%   - MLT is median(completion - release) in workdays.
%   - OTD due dates are family-specific (3/5/7 workdays for Brackets/Shafts/Gates).

% ---- Parse inputs ----
p = inputParser;
addRequired(p, 'job_log_file', @ischar);
addParameter(p, 'IdealRate', NaN, @isnumeric);
addParameter(p, 'OutputFile', '', @ischar);
addParameter(p, 'WorkHoursPerDay', 8, @isnumeric);
addParameter(p, 'WorkDaysPerWeek', 5, @isnumeric);
parse(p, job_log_file, varargin{:});
opt = p.Results;

% ---- Load & basic prep ----
fprintf('Loading job log from %s...\n', opt.job_log_file);
jobs = readtable(opt.job_log_file);

% Map minutes → week index (1-based)
mins_per_week = opt.WorkHoursPerDay * opt.WorkDaysPerWeek * 60;
jobs.week = floor(jobs.completion_time / mins_per_week) + 1;

% ---- Ideal rate (if not given) ----
if isnan(opt.IdealRate)
    fprintf('Calculating ideal rate from baseline data...\n');
    total_processing_time_hours = sum(jobs.total_processing_time) / 60;
    if total_processing_time_hours > 0
        ideal_rate_from_sim = height(jobs) / total_processing_time_hours; % jobs/hour
    else
        ideal_rate_from_sim = 0;
    end
    fprintf('Calculated Ideal Rate: %.2f jobs/hour\n', ideal_rate_from_sim);
else
    ideal_rate_from_sim = opt.IdealRate;
end

% ---- Weekly KPI computation ----
fprintf('Calculating weekly KPIs...\n');
unique_weeks = unique(jobs.week)';  % row vector
kpi_data = [];

for week_num = unique_weeks
    wk = jobs(jobs.week == week_num, :);
    if isempty(wk), continue; end

    % Availability
    total_proc   = sum(wk.total_processing_time);
    total_setup  = sum(wk.total_setup_time);
    total_down   = sum(wk.total_downtime);
    total_run    = total_proc + total_setup + total_down;
    availability = (total_run > 0) * (total_proc / max(total_run, eps));

    % Quality
    total_units = height(wk);
    good_units  = sum(~wk.is_defective);
    quality     = (total_units > 0) * (good_units / max(total_units, 1));

    % Performance vs ideal rate
    if total_proc > 0 && ideal_rate_from_sim > 0
        actual_rate_jobs_per_hour = total_units / (total_proc / 60);
        performance = actual_rate_jobs_per_hour / ideal_rate_from_sim;
    else
        performance = 0;
    end

    % OEE
    oee = availability * performance * quality;

    % PPM
    defective_units = sum(wk.is_defective);
    ppm = (total_units > 0) * (defective_units / max(total_units, 1)) * 1e6;

    % MLT (days)
    lead_times_mins = wk.completion_time - wk.release_time;
    mlt_days = median(lead_times_mins) / (opt.WorkHoursPerDay * 60);

    % OTD (due dates by family)
    due = wk.release_time;
    due(wk.family_id == 1) = due(wk.family_id == 1) + 3 * opt.WorkHoursPerDay * 60;
    due(wk.family_id == 2) = due(wk.family_id == 2) + 5 * opt.WorkHoursPerDay * 60;
    due(wk.family_id == 3) = due(wk.family_id == 3) + 7 * opt.WorkHoursPerDay * 60;
    on_time = (total_units > 0) * (sum(wk.completion_time <= due) / max(total_units, 1));

    % Append row
    kpi_data = [kpi_data; week_num, availability, performance, quality, oee, ppm, on_time, mlt_days];
end

weekly_kpis = array2table(kpi_data, 'VariableNames', ...
    {'Week','Availability','Performance','Quality','OEE','PPM','OTD','MLT_days'});

% ---- Save (if requested) ----
if ~isempty(opt.OutputFile)
    outdir = fileparts(opt.OutputFile);
    if ~isempty(outdir) && ~isfolder(outdir), mkdir(outdir); end
    writetable(weekly_kpis, opt.OutputFile);
    fprintf('Saved weekly KPIs to %s\n', opt.OutputFile);
end

% ---- Optional second output ----
if nargout > 1
    varargout{1} = ideal_rate_from_sim;
end
end
