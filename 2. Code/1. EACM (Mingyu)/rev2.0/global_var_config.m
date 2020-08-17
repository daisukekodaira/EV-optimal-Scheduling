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
EV.ie = dataset(:,3);
EV.cap = dataset(:,4);
EV.plug = [EV.in EV.out];

%% Data Loading; Tariffs for Building by KEPCO
Tariff_B = csvread('Industrial (B).General(B) high-voltage(A) option I.csv');
Tariff_B = repelem(Tariff_B(1,2:25),4);

%% Define G
% G.plug=EV.plug;
G.plug=[];
G.belong=[];
G.num=[];
G.ie=[];
G.s=[];
G.cap=[];
for i=min(EV.in):max(EV.in)
    idx=find(EV.plug(:,1)==i);
    if length(idx)>1
        G.plug=[G.plug; i max(EV.out(idx))];
        G.num=[G.num; length(idx)];
        G.ie=[G.ie; sum(EV.ie(idx))];
        G.cap=[G.cap; sum(EV.cap(idx))];
        G.s=[G.s; 999];
        temp=0;
        for j=1:length(idx)
            G.belong=[G.belong; i*ones(size(idx(j))) EV.out(idx(j)) idx(j) EV.cap(idx(j))*TE-EV.ie(idx(j))+temp];
            temp=temp+EV.cap(idx(j))*TE-EV.ie(idx(j));
        end
        
    elseif isempty(idx)~=1
        idx=find(EV.in==i);
        G.plug=[G.plug; i EV.out(idx)];
        G.num=[G.num;1];
        G.ie=[G.ie; EV.ie(idx)];
        G.cap=[G.cap; EV.cap(idx)];
        G.s=[G.s; EV.cap(idx)*TE-EV.ie(idx)];
    end
end

G.in=G.plug(:,1);
G.out=G.plug(:,2);
G.size=length(G.in);
G.dur=G.out-G.in;
G.Emin=zeros(G.size,max(G.dur));
G.cp=zeros(G.size,max(G.dur));
G.dp=zeros(G.size,max(G.dur));
for i=1:G.size
    if G.num(i)==1
        idx=find(EV.in==G.in(i));
        G.Emin(i,1:EV.out(idx)-EV.in(idx))=EV.cap(idx);
        G.Emin(i,1:EV.out(idx)-EV.in(idx))=1;
        G.cp(i,1:EV.out(idx)-EV.in(idx))=var_range(1);
        G.dp(i,1:EV.out(idx)-EV.in(idx))=var_range(2);
    else
        idx=find(G.belong(:,1)==G.in(i));
        for j=1:G.num(i)
            %             G.Emin(i,1:G.belong(idx(j),2)-G.belong(idx(j),1))=...
            %                 G.Emin(i,1:G.belong(idx(j),2)-G.belong(idx(j),1))+EV.cap(G.belong(idx(j),3));
            G.Emin(i,1:G.belong(idx(j),2)-G.belong(idx(j),1))=...
                G.Emin(i,1:G.belong(idx(j),2)-G.belong(idx(j),1))+1;
            
            G.cp(i,1:G.belong(idx(j),2)-G.belong(idx(j),1))=...
                G.cp(i,1:G.belong(idx(j),2)-G.belong(idx(j),1))+var_range(1);
            
            G.dp(i,1:G.belong(idx(j),2)-G.belong(idx(j),1))=...
                G.dp(i,1:G.belong(idx(j),2)-G.belong(idx(j),1))+var_range(2);
        end
    end
end
for i=1:G.size
    if G.Emin(i,1)==G.Emin(i,G.dur(i))
        G.Emin(i,1:G.dur(i))=0;
    else
        G.Emin(i,1:G.dur(i))=flip(G.Emin(i,1:G.dur(i))-1)*60*TE;
    end
end