clc, clear, close all
addpath(genpath('./pso_base'));
addpath('../')
savepath;
global_var_declare; % Declare the global variables

%% set parameter
% EV.size: The number of EVs in this simulation
% EV.cap[kwh]: Battery capacity [kwh] for one EV
% EV.Tsoc: Target SOC[%]
% Power: PCS power[kw]. Chargeing and discharging. Values are refered to KIAPI charger
EV.size=[];
EV.size=3;
EV.Tsoc=0.8;
var_range = [20/4 -10/4];
plotflag=2;
global_var_config; % Load parameters

%% Generate Charging schedule; Uncoordinated charging
% [un_sol,un_fval,un_needenergy]=un_optimize;
% %%%check uncoord
% % un_check=zeros(EV.size,1);
% % for EV = 1:EV.size
% %     un_check(EV)=sum(un_sol.P(EV,plug_in(EV,1):plug_in(EV,2)-1));
% % end
% %%%
% in=plug_in(:,1);
% out=plug_in(:,2);
% for EV=1:EV.size
%     un_sol.P(EV,1:in(EV)-1)=0;
%     un_sol.P(EV,out(EV):96)=0;
% end
% un_X=sum(un_sol.P,1);
% un_schedule=un_X'+B_data_sample;
%
% un_TOU=Tariff_B * un_schedule;
% un_peak=7220*max(un_schedule);
%
% w_t=un_TOU/un_peak;

%% Optimization; Quadratic programming-----------------------------------------------------------------
% The objective function is desinged as
%        arg min alpha*TOU_cost + beta*peak_cost
% alpha and beta are the weights(coefficients) defined as number like 1.2, 1,0... etc.
%------------------------------------------------------------------------------------------------

%% test set
tic
qpset;
toc
% output is [x,fval,exitflag]
% qpflag -1; QP didn't find the feasible solution
% qpflag 0; QP reashced
% qpflag 1; appropriately find the solution

%% Check QP result
total_demand=qp.X+B_data'; % EV demand + building demand
cost=Tariff_B*total_demand'+7220*bound;

% soc check
qpsoc=zeros(G.size,96);
for g=1:G.size
    qpsoc(g,G.in(g))=G.soc(g);
end
for g=1:G.size
    for t=1:G.out(g)-G.in(g)
        qpsoc(g,G.in(g)+t)=qpsoc(g,G.in(g)+t-1)+qp.x_sw(g,G.in(g)+t-1);
    end
end

% kwh=>%
qpsoc=qpsoc./G.cap*100;

% plot soc graph
if plotflag==1
    figure(1)
    for i=1:size(qpsoc,1)
        plot(1:96,qpsoc(i,:))
        hold on
    end
end

% qp final soc
qpsoc_final=zeros(G.size,1);
for i=1:G.size
    qpsoc_final(i)=qpsoc(i,G.out(i));
end
ttt=toc;