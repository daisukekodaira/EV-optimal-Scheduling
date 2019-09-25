clear,clc, close all
addpath('../')
EV_cap=50;
% X = xlsread('X.csv'); %[96x250]
% P = xlsread('P.csv');  %[96x250]
% [RDD,RDP]=SPPA(X,P,24); %prob point가 250개든 3개든 상관안하는듯. 단, X와 P의 사이즈가 같아야함.
% %그렇다면 각 지점과 확률을 어떻게 도출할것인가?

%% Data Read: Demand
B_read = csvread('ResultData.csv',1,6);
B_cut = B_read(:,1:3);                   %get only nessesary
B_std=( B_cut(:,1)-B_cut(:,2) )/1.96;    %calculate stand deviation

%% Data Read: EV
EV_info=csvread("EV_data96_sto.csv",1);
%in time
EVin(:,1) = EV_info(:,3);
EVin(:,2) = EV_info(:,4);
EVin(:,3) = EV_info(:,5);
EVin_std= ( EVin(:,1)-EVin(:,2) )/1.96;
%out time
EVout(:,1) = EV_info(:,6);
EVout(:,2) = EV_info(:,7);
EVout(:,3) = EV_info(:,8);
EVout_std= ( EVout(:,1)-EVout(:,2) )/1.96;
%soc[%] => [kwh]
ini_soc(:,1) = EV_info(:,9);
ini_soc(:,2) = EV_info(:,10);
ini_soc(:,3) = EV_info(:,11);
ini_soc_std= ( ini_soc(:,1)-ini_soc(:,2) )/1.96;

ini_soc=round(ini_soc*EV_cap/100,2);

%% Create PDF: Demand
y_d=normpdf(1:max(B_cut(:,3)),B_cut(:,1),B_std(:));

%% Create PDF: Demand
y_in=normpdf(1:max(EVin(:,3)),EVin(:,1),EVin_std(:));
y_out=normpdf(1:max(EVout(:,3)),EVout(:,1),EVout_std(:));
y_soc=normpdf(1:max(ini_soc(:,3)),ini_soc(:,1),ini_soc_std(:));

%% round
y_d=round(y_d,3);
y_in=round(y_in,3);
y_out=round(y_out,3);
y_soc=round(y_soc,3);

%% Sampling: EV
N_sample=10000;
scenario_EV=zeros(3,N_sample);
i=1;
    %row1 : random sampling result of EV in time
    %row2 : random sampling result of EV out time
    %row3 : random sampling result of EV initial SOC
    %column : each colunm means each scenario
scenario_EV(1,:)=randsample(size(y_in,2), N_sample, true, y_in(i,:));
scenario_EV(2,:)=randsample(size(y_out,2), N_sample, true, y_out(i,:));
scenario_EV(3,:)=randsample(size(y_soc,2), N_sample, true, y_soc(i,:));

%% Sampling: Demand
N_sample=1000;
hour=96;
scenario_demand=zeros(hour,N_sample);

for i=1:hour
    %row : random sampling result of Demand
    %column : each colunm means each scenario
    scenario_demand(i,:)=randsample(size(y_d,2), N_sample, true, y_d(i,:));
end

%% graph
% for i=1:2:8
% subplot(4,2,i)
% histogram(sample_result(:,2*(i-1)+1))
% subplot(4,2,i+1)
% plot(y_d(2*(i-1)+1,:))
% end
