clc, clear, close all
addpath('../')

%% set parameter
timespan=2;
step=0.1;
EV_num=5;
EV_cap=60;
% EV_cap=1000;
boundary=1800;
fsoc=0.8;
power = [200 -1000];

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

%% Quadratic programming
X_st=zeros(96,3); % schedule save

% run ex
st=1;
plug_in=[EVin(1:EV_num,st) EVout(1:EV_num,st)];
ori_soc=ini_soc(1:EV_num,st);
% boundary=max(B_data_sample);
boundary=20000;
plug_inw=repelem([1 96],EV_num)
[x,fval,exitflag,in,out,op_size,energy,mat,mat_b]=QP_test(B_data_sample,plug_in,ori_soc, EV_num,EV_cap,boundary,Tariff_B,fsoc,power);
% x=round(x,2);
sum(mat*x==mat_b)
%% check result
idx=length(x)/96;
x_shift=reshape(x,[96,idx])';
X=sum(x_shift);
B_imp=X+B_data_sample';

yyaxis left
plot(COST(:,1))
title('Plots with Different y-Scales')
xlabel('Values from 0 to 25')
ylabel('PEAK')

yyaxis right
plot(COST(:,2))
ylabel('TOU')
%% check the result
soc=zeros(24,EV_num,1);

% for i=1:EV_num
%     soc(in(i),i)=ori_soc(i);
% end

% result_QP ÀÚ¸£±â
cutresult=x;
% for i=1:EV_num
%     cutresult(in(i):out(i)-1,i) = x(in(i)+24*(i-1):out(i)-1+24*(i-1));
% end

for EV=1:EV_num
    for i=1:24
        if in(EV)==i
            soc(1,EV)=ori_soc(1,EV)+cutresult(1,EV);
        elseif in(EV)<i
            soc(i,EV)=soc(i-1,EV)+cutresult(i,EV);
        elseif (out(EV)-1)==i
            break;
        end
    end
end
soc=round(soc*100/EV_cap,2);
