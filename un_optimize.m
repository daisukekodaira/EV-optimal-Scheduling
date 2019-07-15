function[sol,fval,un_needenergy]=un_optimize(Tariff_B, plug_in, ori_soc, EV_num, EV_cap)
%% Create expressions for the costs associated with the variables.
in=plug_in(:,1);
out=plug_in(:,2);
EV_agg = optimproblem;
P = optimvar('P',EV_num,96,'LowerBound', 0,'UpperBound',20);

%% Define objective function
EV_agg.Objective = sum(sum(P));

%% Elements of Constraints
% required energy matrix (가로 합이 이거보다 커야됨)
un_needenergy=zeros(EV_num,1);
for EV=1:EV_num
    un_needenergy(EV)=EV_cap-ori_soc(EV);
end

Y=un_def_y(P,EV_num,plug_in);

EV_agg.Constraints.energy = Y >= un_needenergy;

%% Solve Problem
% % sol is answer of each constraints
% % fval is final cost value
[sol,fval] = solve(EV_agg,'intlinprog');
% %% check y
% check_Y=zeros(50,1);
% for EV = 1:EV_num    
%     check_Y(EV)=sum(sol.P(EV,plug_in(EV,1):plug_in(EV,2)-1));
% end
end