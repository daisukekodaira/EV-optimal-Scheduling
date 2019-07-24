clc, clear, close all
addpath('../')

%% set parameter
timespan=2;
step=0.1;
EV_num=200; 
EV_cap=60;
% EV_cap=1000;
boundary=1800;
fsoc=0.8;
power = [20 -10];

%% Demand Data Read
B_read = csvread('ResultData.csv',1,6);
B_cut = B_read(:,1:3)*50;
B_data_sample = B_cut(:,1);

%% EV data
EV_info=xlsread("EV_data96_sto.xlsx");
%in time
EVin(:,1) = EV_info(:,3);
EVin(:,2) = EV_info(:,4);
EVin(:,3) = EV_info(:,5);

%out time
EVout(:,1) = EV_info(:,6);
EVout(:,2) = EV_info(:,7);
EVout(:,3) = EV_info(:,8);

%soc[%] => [kwh]
ini_soc(:,1) = EV_info(:,9);
ini_soc(:,2) = EV_info(:,10);
ini_soc(:,3) = EV_info(:,11);

ini_soc=round(ini_soc*EV_cap/100,2);

%% Tariffs_Building
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
% 24 => 96
Tariff_B = repelem(Tariff_B(1,2:25),4);

%% uncoord
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
%% Quadratic programming
w_t=1.1;
X_st=zeros(96,3); % schedule save

% run ex
st=1;
plug_in=[EVin(1:EV_num,st) EVout(1:EV_num,st)];
ori_soc=ini_soc(1:EV_num,st);
% boundary=max(B_data_sample);
boundary=350;


% % dummy plug in
% plug_in=[reshape(repelem([5 95],EV_num/2),[EV_num/2,2]); reshape(repelem([7 93],EV_num/2),[EV_num/2,2])];


[x,fval,exitflag,in,out,op_size,energy,mat,mat_b]=QP_test(B_data_sample,plug_in,ori_soc, EV_num,EV_cap,boundary,Tariff_B,fsoc,power,w_t);
% x=round(x,2);
sum(mat*x==mat_b)
%% check result
idx=length(x)/96;
x_shift=reshape(x,[96,idx])';
X=sum(x_shift);
B_imp=X+B_data_sample';
figure(2)
bar(B_imp)
hold on
plot(B_data_sample)

%%
[Tariff_B*B_imp' 7220*boundary]
%%


% yyaxis left
% plot(COST(:,1))
% title('Plots with Different y-Scales')
% xlabel('Values from 0 to 25')
% ylabel('PEAK')
% 
% yyaxis right
% plot(COST(:,2))
% ylabel('TOU')
% %% check the result
% soc=zeros(24,EV_num,1);
% 
% % for i=1:EV_num
% %     soc(in(i),i)=ori_soc(i);
% % end
% 
% % result_QP ÀÚ¸£±â
% cutresult=x;
% % for i=1:EV_num
% %     cutresult(in(i):out(i)-1,i) = x(in(i)+24*(i-1):out(i)-1+24*(i-1));
% % end
% 
% for EV=1:EV_num
%     for i=1:24
%         if in(EV)==i
%             soc(1,EV)=ori_soc(1,EV)+cutresult(1,EV);
%         elseif in(EV)<i
%             soc(i,EV)=soc(i-1,EV)+cutresult(i,EV);
%         elseif (out(EV)-1)==i
%             break;
%         end
%     end
% end
% soc=round(soc*100/EV_cap,2);
