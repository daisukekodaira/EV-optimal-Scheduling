%% Data loading; Builidng Demand data
% Get "Buidling demand[kwh]" with Upper boundary, mean, lower boundary
B_data = csvread('KIAPI_D.csv',1,0);
B_data = B_data*weight;
% Extract Upper boundary, mean, lower boundary
% B_data = B_read(:,1:3)*50;
% B_data = B_data(:,1);

%% Data loading; EV data
EV_info=csvread("newdata.csv",1);
% 1)ID / 2)In / 3)Out / 4)soc[%] / 5)cap[kwh]

%Get soc [%]
% EV_info(:,4)=round(EV_info(:,4)*100.*EV_info(:,5)/100,2);
% 
% % min=>quater
% EVin=ceil(EV_info(:,2)/15);
% EVout=ceil(EV_info(:,3)/15);
% %prevent error
% EVin(find(EVin==0))=1;
% EVout(find(EVout==96))=95;
% EVout(find(EVin>EVout==1))=95;

% find((EV_info(:,2)==48)&(EV_info(:,3)==64))
dataset=sortrows(EV_info(1:EV.size,2:5));

%% set var
EV.in = dataset(:,1);
EV.out = dataset(:,2);
EV.soc = dataset(:,3);
EV.cap = dataset(:,4);
EV.plug = [EV.in EV.out];

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
% % % % % % % test set %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EV.cap=[100;100;100];
% EV.Tsoc=1;
% EV.soc=[0;10;80];
% EV.in=[1;1;1];
% EV.out=[7;12;12];
% EV.plug=[EV.in EV.out];
% 
% var_range = [20 -20];
% Tariff_B=[ones(1,4)*120 ones(1,2)*60 ones(1,4)*20 ones(1,2)*60 zeros(1,84)];
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Define G
G.plug=EV.plug;
idx=[];
for i=2:size(G.plug,1)
    if (G.plug(i,1)==G.plug(i-1,1)) && (G.plug(i,2)==G.plug(i-1,2))
        idx=[idx;i];
    end
end

G.plug(idx,:)=[];
G.in=G.plug(:,1);
G.out=G.plug(:,2);
% length(G.in)

G.size=length(G.in);
G.soc=EV.soc;
G.cap=EV.cap;
G.num=ones(size(G.soc));
i=length(idx);
a=[];
while i>0
    G.soc(idx(i)-1)=G.soc(idx(i)-1)+G.soc(idx(i));
    G.cap(idx(i)-1)=G.cap(idx(i)-1)+G.cap(idx(i));
    G.num(idx(i)-1)=G.num(idx(i)-1)+1;
    i=i-1;
end
G.soc(idx)=[];
G.cap(idx)=[];
G.num(idx)=[];
G.ub=ones(size(G.in))*var_range(1).*G.num;
G.lb=ones(size(G.in))*var_range(2).*G.num;