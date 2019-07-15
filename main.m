clc, clear, close all
addpath('../')

%% set parameter
% EV_num: The number of EVs in this simulation
% EV_cap[kwh]: Battery capacity [kwh] for one EV
% boudary[kwh]: Demand[kwh]+Charging[kwh] have to be less than boundary
% fsoc: Target SOC[%]
% Power: PCS power[kw]. Chargeing and discharging. Values are refered to KIAPI charger
EV_num=20; 
EV_cap=60;
boundary=1800;
fsoc=0.8;
power = [20 -10];

%% Data loading; Builidng Demand data
% Get "Buidling demand[kwh]" with Upper boundary, mean, lower boundary
B_read = csvread('ResultData.csv',1,6);
% Extract Upper boundary, mean, lower boundary
B_cut = B_read(:,1:3)*50;
B_data_sample = B_cut(:,1);

%% Data loading; EV data
EV_info=xlsread("EV_data96_sto.xlsx");
% Get Plug-in time
EVin(:,1) = EV_info(:,3); % Mean
EVin(:,2) = EV_info(:,4); % lower boundary
EVin(:,3) = EV_info(:,5); % upper boundary

% Get Plug-out time
EVout(:,1) = EV_info(:,6);
EVout(:,2) = EV_info(:,7);
EVout(:,3) = EV_info(:,8);

%Get soc [%]
ini_soc(:,1) = EV_info(:,9); 
ini_soc(:,2) = EV_info(:,10);
ini_soc(:,3) = EV_info(:,11);
% Change the unit from SOC[%] to SOC[kwh]
ini_soc=round(ini_soc*EV_cap/100,2);

%% Data Loading; Tariffs for Building by KEPCO
%winter     week
%           saturday
%           sunday
%spring     week
%           saturday
%           sunday
%summer     week
%           saturday
%           sunday
%fall       week
%           saturday
%           sunday
Tariff_B = csvread('Industrial (B).General(B) high-voltage(A) option I.csv');
% Change the time interval from 24 (1hour) to 96(15min)
Tariff_B = repelem(Tariff_B(1,2:25),4);

%% Generate Charging schedule; Uncoordinated charging
% ori_soc=ini_soc(:,1);
% plug_in=[EVin(:,1) EVout(:,1)];
% [un_sol,un_fval,un_needenergy]=un_optimize(Tariff_B, plug_in, ori_soc, EV_num, EV_cap);
% %%%check uncoord
% % un_check=zeros(EV_num,1);
% % for EV = 1:EV_num
% %     un_check(EV)=sum(un_sol.P(EV,plug_in(EV,1):plug_in(EV,2)-1));
% % end
% %%%
% in=plug_in(:,1);
% out=plug_in(:,2);
% for EV=1:EV_num
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
% w_t; Weight for TOU
% X_st; Sum of available EVs charge/discharge amount with the 15 min instances
%          There are 3 scenarios as mean, upper boudanry, lower boundary
%          1st column of X_st: total of all EV's mean [kwh]
%          2nd column of X_st: total of all EV's upper boundary [kwh]
%          3rd column of X_st: total of all EV's lower boundary [kwh]
% st; The selected scenario for optimizaiton (originally we should calculate all 3 scenarios above)
%      one of the scenarios are selected to reduce the calculation time at present
w_t=1.1;
X_st=zeros(96,3); % schedule save
% Select one scenario and small number of EVs to easily analyze the simulation results.  
% All scenarios and EVs should be considered later on.
selected_scenario=1; % 1: mean scenario
plug_in=[EVin(1:EV_num,selected_scenario) EVout(1:EV_num,selected_scenario)]; % Extract plug-in time
ori_soc=ini_soc(1:EV_num,selected_scenario); % Extract initial SOC when EV plug-in
% boundary=max(B_data_sample); % Ideally, the boundary[kwh] has to be redefined as the scenario changes

% Call QP_test for optimization (generate EV schedules)
% x; EV schedules
% fval; never used
% exitflag; never used
% in; plug-in time
% out; plug-out time
% op_size; Originally, each EV has independent plun-in time. To minimize
%              the variables for optimizaion, the EVs which have the same
%              plug-in time bunch one group called operation group -> op_size
% energy; (plug-in time[0~96]*duration of connection[0~96]) Required energy for each group to achieve the target SOC 

[x,fval,exitflag,in,out,op_size,energy,mat_a1,mat_b1]=QP_test(B_data_sample,plug_in,ori_soc, EV_num,EV_cap,boundary,Tariff_B,fsoc,power,w_t);
% % for debug --------------------------------------------------------
% % x=round(x,2);
% sum(mat_a1*x==mat_b1)
% % -------------------------------------------------------------------

%% Show the graph of the result; optimal EV scheduling
idx=length(x)/96;
x_shift=reshape(x,[96,idx])';
X_st=sum(x_shift); % Sum of available EVs charge/discharge amount with the 15 min instances
total_demand=X_st+B_data_sample'; % EV demand + building demand
figure(2)
bar(total_demand)
hold on
plot(B_data_sample)
xlabel("Time steps in a day [15min]");
ylabel("Total demand [kwh]");
title("Scheduled demand (EV and building demand) and Building demand");
legend("EV + building demand","Building demand");


%% Display the cost as a result of simulation
% TOU cost and peak cost(basic cost)
[Tariff_B*total_demand' 7220*boundary]

