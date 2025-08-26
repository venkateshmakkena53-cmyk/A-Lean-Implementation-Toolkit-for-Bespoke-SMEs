function job_log = simulate_hmlv(param_file, varargin)
% SIMULATE_HMLV  Discrete-event simulator for a HMLV job shop.
% Author: Venkatesh
%
%   job_log = SIMULATE_HMLV(param_file, Name,Value,...) runs the simulation
%   using params_* .mat file and returns a table of completed jobs. Uses an
%   event queue (arrival/finish) to avoid time-step issues.
%
%   Name-Value Options
%   ------------------
%   'NumJobs'             (double) default 200
%   'MeanInterarrivalTime'(double) default 25   % minutes
%   'OutputFile'          (char)   default ''   % optional CSV path
%
%   Output Columns
%   --------------
%   job_id, family_id, release_time, completion_time,
%   total_setup_time, total_processing_time, total_downtime, is_defective

% ---- Parse inputs ----
p = inputParser;
addRequired(p, 'param_file', @ischar);
addParameter(p, 'NumJobs', 200, @isnumeric);
addParameter(p, 'MeanInterarrivalTime', 25, @isnumeric);
addParameter(p, 'OutputFile', '', @ischar);
parse(p, param_file, varargin{:});
opt = p.Results;

% ---- Load parameters ----
fprintf('Loading parameters from %s...\n', opt.param_file);
if contains(opt.param_file, 'before')
    s = load(opt.param_file, 'params_before'); params = s.params_before;
else
    s = load(opt.param_file, 'params_after');  params = s.params_after;
end

% ---- Init ----
fprintf('Initializing HMLV simulation...\n');
machine_free_time   = zeros(1, params.num_stages);
machine_last_family = zeros(1, params.num_stages);
job_queue = cell(1, params.num_stages); for i=1:params.num_stages, job_queue{i} = {}; end
completed_jobs = cell(1, opt.NumJobs);

job_id_counter = 0; jobs_completed = 0;

% Pre-generate arrivals
arrival_times       = cumsum(exprnd(opt.MeanInterarrivalTime, opt.NumJobs, 1));
job_family_indices  = randi(params.num_families, opt.NumJobs, 1);
event_queue = table(arrival_times, repmat("arrival",opt.NumJobs,1), (1:opt.NumJobs)', ...
                    'VariableNames', {'time','type','job_id'});

fprintf('Starting simulation for %d jobs...\n', opt.NumJobs);

% ---- Event loop ----
while ~isempty(event_queue)
    cur = event_queue(1,:); event_queue(1,:) = [];
    tnow = cur.time; etype = cur.type; jid = cur.job_id;

    if etype == "arrival"
        % New job
        job_id_counter = job_id_counter + 1;
        j = struct('id', job_id_counter, ...
                   'family_idx', job_family_indices(job_id_counter), ...
                   'routing', [], 'current_stage_idx', 1, ...
                   'arrival_time', tnow, 'completion_time', [], ...
                   'total_setup_time', 0, 'total_downtime', 0, ...
                   'is_defective', false, 'total_processing_time', 0);
        j.routing = params.families{j.family_idx}.routing;

        first_stage = j.routing(1);
        job_queue{first_stage}{end+1} = j;

    elseif etype == "finish"
        % Job finished on a machine
        j = completed_jobs{jid};
        if j.current_stage_idx < numel(j.routing)
            j.current_stage_idx = j.current_stage_idx + 1;
            next_stage = j.routing(j.current_stage_idx);
            job_queue{next_stage}{end+1} = j;
            completed_jobs{j.id} = j;
        else
            jobs_completed = jobs_completed + 1;
            completed_jobs{j.id}.completion_time = tnow;
            if mod(jobs_completed, 20) == 0
                fprintf('...%d/%d done (SimTime=%.2f min)\n', jobs_completed, opt.NumJobs, tnow);
            end
        end
    end

    % Process idle machines
    for m = 1:params.num_stages
        if tnow >= machine_free_time(m) && ~isempty(job_queue{m})
            j = job_queue{m}{1}; job_queue{m}(1) = [];

            % Setup time if family change
            setup_time = 0;
            if machine_last_family(m) ~= 0 && machine_last_family(m) ~= j.family_idx
                setup_time = max(0, normrnd(params.setup_time_mu, params.setup_time_sd));
            end
            j.total_setup_time = j.total_setup_time + setup_time;

            % Processing time
            mu = params.proc_time_mu{j.family_idx, m};
            sd = mu * params.proc_time_sd_factor;
            proc_time = max(0, normrnd(mu, sd));
            j.total_processing_time = j.total_processing_time + proc_time;

            % Downtime
            down = 0; if rand() < params.downtime_prob
                down = max(0, normrnd(params.downtime_mu, params.downtime_sd));
            end
            j.total_downtime = j.total_downtime + down;

            % Quality
            if rand() < params.defect_prob(m)
                j.is_defective = true;
            end

            % Schedule finish
            tfin = tnow + setup_time + proc_time + down;
            event_queue = [event_queue; table(tfin,"finish",j.id,'VariableNames',{'time','type','job_id'})];
            event_queue = sortrows(event_queue, 'time');

            machine_free_time(m)   = tfin;
            machine_last_family(m) = j.family_idx;
            completed_jobs{j.id}   = j;
        end
    end
end

% ---- Build output table ----
fprintf('Formatting final job log...\n');
cells = cell(jobs_completed, 8); c = 0;
for i = 1:opt.NumJobs
    if ~isempty(completed_jobs{i}) && isfield(completed_jobs{i},'completion_time')
        c = c + 1;
        j = completed_jobs{i};
        cells(c,:) = {j.id, j.family_idx, j.arrival_time, j.completion_time, ...
                      j.total_setup_time, j.total_processing_time, j.total_downtime, j.is_defective};
    end
end

job_log = cell2table(cells, 'VariableNames', ...
    {'job_id','family_id','release_time','completion_time', ...
     'total_setup_time','total_processing_time','total_downtime','is_defective'});

% ---- Save (if requested) ----
if ~isempty(opt.OutputFile)
    outdir = fileparts(opt.OutputFile);
    if ~isempty(outdir) && ~isfolder(outdir), mkdir(outdir); end
    writetable(job_log, opt.OutputFile);
    fprintf('Saved %d jobs to %s\n', height(job_log), opt.OutputFile);
end
end
