function[sol,fval,un_needenergy]=un_optimize
%% Create expressions for the costs associated with the variables.
global_var_declare;

EV_agg = optimproblem;
P = optimvar('P',EV.size,96,'LowerBound', 0,'UpperBound',20);

%% Define objective function
EV_agg.Objective = sum(sum(P));

%% Elements of Constraints
% required energy matrix (가로 합이 이거보다 커야됨)
un_needenergy=zeros(EV.size,1);
for ev=1:EV.size
    un_needenergy(ev)=EV.cap(ev)-EV.soc(ev);
end

Y=un_def_y(P,EV);

EV_agg.Constraints.energy = Y >= un_needenergy;

%% Solve Problem
% % sol is answer of each constraints
% % fval is final cost value
[sol,fval] = solve(EV_agg);
end