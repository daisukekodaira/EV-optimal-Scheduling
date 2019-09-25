%% Data loading; Builidng Demand data
% Get "Buidling demand[kwh]" with Upper boundary, mean, lower boundary
B_read = csvread('ResultData.csv',1,6);
% Extract Upper boundary, mean, lower boundary
B_data = B_read(:,1:3)*50;
B_data = B_data(:,1);

%% Data loading; EV data
EV_info=csvread("newdata.csv",1);
% Get ID
EVID = EV_info(:,1);
% Get Plug-in time, min time interval
EVin = EV_info(:,2);
% Get Plug-out time, min time interval
EVout = EV_info(:,3);

%Get soc [%]
EVsoc = EV_info(:,4)*100; 
% Change the unit from SOC[%] to SOC[kwh]
EV.cap = EV_info(:,5);
EVsoc=round(EVsoc.*EV.cap/100,2);

% min=>quater
EVin=ceil(EVin/15);
EVout=ceil(EVout/15);
%prevent error
EVin(find(EVin==0))=1;
EVout(find(EVout==96))=95;
EVout(find(EVin>EVout==1))=95;

%% set var
EV.cap = EV.cap(1:EV.size);
EV.soc=EVsoc(1:EV.size);
EV.plug=[EVin(1:EV.size), EVout(1:EV.size)];
EV.in=EVin(1:EV.size);
EV.out=EVout(1:EV.size);

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

savebound=[1 99999999999111];

% % % % % % test set %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
EV.cap=[100;100;100];
EV.Tsoc=1;
EV.soc=[0;0;80];
EV.in=[1;1;1];
EV.out=[7;7;7];
EV.plug=[EV.in EV.out];

var_range = [20 -20];
Tariff_B=[120 120 60 20 20 60 zeros(1,90)];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Define G
G.in=[];
for i=1:96
    if sum(find(i==EV.in)) >= 1
        G.in=[G.in; i];
    end
end
G.out=G.in;
G.size=length(G.in);

for i=1:G.size
    temp_ans=find(G.in(i)==EV.in);
    temp_iter=size(temp_ans,1);
    
    for tp=1:temp_iter
        exist temp;
        if ans==0;
            temp=EV.out(temp_ans(tp));
        else
            temp=[temp; EV.out(temp_ans(tp))];
        end
        
    end
    G.out(i)=max(temp);
    clear temp
end
G.plug=[G.in G.out];

% define each group EV num & capacity & initial soc => make virtual EV
G.num=zeros(G.size,1);
G.cap=zeros(G.size,1);
G.soc=zeros(G.size,1);
G.S=zeros(G.size,1);
for i=1:EV.size
    idx=find(G.in==EV.in(i));
    G.num(idx)=G.num(idx)+1;
    G.cap(idx)=G.cap(idx)+EV.cap(i);
    G.soc(idx)=G.soc(idx)+EV.soc(i);
    G.S(idx)=G.S(idx)+EV.cap(i)*EV.Tsoc -EV.soc(i);
end

% define Prange: changable P varrange
P_num=zeros(G.size,96);
for g=1:EV.size
    idx=find(G.in==EV.in(g));
    P_num(idx,EV.in(g):EV.out(g)-1)=P_num(idx,EV.in(g):EV.out(g)-1)+1;
end
Prange.up=P_num*var_range(1);
Prange.low=P_num*var_range(2);