% DEFINE_PARAMS_FROM_CALIBRATION  Build 'before' and 'after' param structs.
% Author: Venkatesh
%
% Creates params_before / params_after using calibration results
% (../config/calibration.mat) and saves them to ../config/.

%% 1) Load calibration
fprintf('Loading calibration data from ../config/calibration.mat...\n');
load('../config/calibration.mat', 'calib');

%% 2) "Before" parameters
fprintf('Defining "params_before"...\n');
params_before = struct();

% Layout
params_before.stages      = {'Cutting','CNC','Welding','Finishing','Inspection'};
params_before.num_stages  = numel(params_before.stages);

% Families & routings
params_before.families = {
    struct('name','Brackets','routing',[1 4 5])
    struct('name','Shafts',  'routing',[1 2 4 5])
    struct('name','Gates',   'routing',[1 2 3 4 5])
};
params_before.num_families = numel(params_before.families);

% Processing times (means, minutes)
params_before.proc_time_mu = {
    [5], [NaN], [NaN], [8],  [3];   % Brackets
    [8], [20],  [NaN], [10], [5];   % Shafts
    [15],[30],  [45],  [25], [10];  % Gates
};
% Variability factor (CV) from calibration
params_before.proc_time_sd_factor = calib.cv_rate;

% Setup (minutes)
params_before.setup_time_mu = 45;
params_before.setup_time_sd = 15;

% Downtime from calibration (fallback if NaN)
params_before.downtime_prob = 0.03;
params_before.downtime_mu   = calib.stop_mu_min;
params_before.downtime_sd   = calib.stop_sd_min;
if isnan(params_before.downtime_mu)
    params_before.downtime_mu = 3.1;
    params_before.downtime_sd = 2.5;
end

% Stage defect probabilities (Welding dominant)
params_before.defect_prob = [0.005, 0.01, calib.defectProp, 0.005, 0.005];

%% 3) "After" parameters (apply toolkit improvements)
fprintf('Defining "params_after"...\n');
params_after = params_before;

% SMED → setup reduction
params_after.setup_time_mu = params_before.setup_time_mu * 0.75;
params_after.setup_time_sd = params_before.setup_time_sd * 0.66;

% TPM → fewer downtimes
params_after.downtime_prob = params_before.downtime_prob * 0.67;

% RCA → fewer defects at Welding
params_after.defect_prob(3) = params_before.defect_prob(3) * 0.50;

% 5S/Std Work → lower process variability
params_after.proc_time_sd_factor = params_before.proc_time_sd_factor * 0.64;

%% 4) Save
outdir = '../config';
if ~isfolder(outdir), mkdir(outdir); end
fprintf('Saving parameter files to %s ...\n', outdir);
save(fullfile(outdir,'params_before.mat'), 'params_before');
save(fullfile(outdir,'params_after.mat'),  'params_after');

fprintf('\nStep complete. Saved params_before.mat and params_after.mat\n\n');

% Summary
disp('=== Parameter Summary ===');
disp('--- BEFORE ---'); disp(params_before);
disp('--- AFTER  ---'); disp(params_after);
