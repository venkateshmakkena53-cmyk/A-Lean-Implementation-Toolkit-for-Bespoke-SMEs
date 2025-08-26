function scmi_table = compute_scmi(varargin)
% COMPUTE_SCMI  Socio-Cultural Maturity Index (Before vs After).
% Author: Venkatesh
%
%   scmi_table = COMPUTE_SCMI(Name,Value,...) defines Likert-scale scores
%   (1–5) for Management Commitment, Employee Engagement, Inter-dept
%   Communication, and CI Culture, then converts to a 0–100 SCMI.
%
%   Name-Value Options
%   ------------------
%   'OutputFile'   (char) default ''   % optional CSV path

% ---- Parse inputs ----
p = inputParser;
addParameter(p, 'OutputFile', '', @ischar);
parse(p, varargin{:});
opt = p.Results;

fprintf('Defining SCMI scores for Before and After...\n');

% ---- Likert (1–5) ----
% Before: typical SME baseline
scmi_before.V_MC = 3.0;
scmi_before.V_EE = 2.0;
scmi_before.V_IC = 2.0;
scmi_before.V_CI = 1.0;

% After: expected uplift via toolkit
scmi_after.V_MC = 3.5;
scmi_after.V_EE = 4.0;
scmi_after.V_IC = 3.5;
scmi_after.V_CI = 3.5;

% ---- Convert to 0–100 ----
score_before    = [scmi_before.V_MC, scmi_before.V_EE, scmi_before.V_IC, scmi_before.V_CI];
score_after     = [scmi_after.V_MC,  scmi_after.V_EE,  scmi_after.V_IC,  scmi_after.V_CI];
scmi_before_val = mean(score_before / 5) * 100;
scmi_after_val  = mean(score_after  / 5) * 100;

% ---- Table ----
Variable = {'V_MC'; 'V_EE'; 'V_IC'; 'V_CI'; 'SCMI_Score'};
Before   = [score_before, scmi_before_val]';
After    = [score_after,  scmi_after_val ]';
scmi_table = table(Variable, Before, After);

% ---- Save (if requested) ----
if ~isempty(opt.OutputFile)
    outdir = fileparts(opt.OutputFile);
    if ~isempty(outdir) && ~isfolder(outdir), mkdir(outdir); end
    writetable(scmi_table, opt.OutputFile);
    fprintf('Saved SCMI to %s\n', opt.OutputFile);
end

% ---- Display ----
disp('--- SCMI (0–100) ---');
disp(scmi_table);
end
