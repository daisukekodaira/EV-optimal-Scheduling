clc, clear, close all
addpath('../')
savepath;
%% Global var declare
global Tariff_B
global var_range
global B_data
global G
global EV
global x
global weight
% x.first: qp schedule
% x.second: EV schedule
% x.third: violated schedule

%% set parameter
% EV.size: The number of EVs in this simulation
% EV.cap[kwh]: Battery capacity [kwh] for one EV
% EV.Tsoc: Target SOC[%]
% Power: PCS power[kw]. Chargeing and discharging. Values are refered to KIAPI charger

EV.size=5;
EV.Tsoc=1;
weight=1;
var_range = [20/4 -10/4];
% var_range = [80 -80];
plotflag=1;
global_var_config; % Load parameters

x.first=zeros(G.size,96);
x.second=zeros(EV.size,96);
x.third=zeros(EV.size,96);
lp.update=[];
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
qpset;
B_data=B_data'+sum(qpx_sw,1);
% bar(B_data)
% 
% soc=zeros(size(qpx_sw));
% for i=1:EV.size
%     soc(i,EV.in(i))=EV.soc(i);
%    for j=EV.in(i):EV.out(i)-1
%        soc(i,j+1)=soc(i,j)+qpx_sw(i,j);
%    end
% end