a=1000000;
b=100;
c=1;
d=1;
%% define var range || ##while start point##
qp_iterflag=-1;
qp_iter=0;
qp_update=0; % initialize a6&b6

%% H&f(P(96*G.size) || PL(1) || TS(G.size))
%% f_tou & f_peak
qpf_temp=zeros(G.size,96);
for g=1:G.size
    qpf_temp(g,G.in(g):G.out(g)-1)=1;
    qpf_tou=reshape(qpf_temp',[96*G.size,1]);
end
qpf_tou=qpf_tou.*repmat(Tariff_B,1,G.size)';

% add slack vars
qpf_tou=[qpf_tou; 7200*weight; ones(G.size,1)*a];
%     qpf_tou=[zeros(96*G.size,1); 0; zeros(G.size,1)];
% f_tou=[f_tou; 7200];
% 7200 is peak cost weight

%% set H & f
%     qpH=qpH_1;
% f=f1+f2*w_t;
qpf=qpf_tou;
clear qpH_1;
clear qpf_tou;
%% define A, inequality const
% Const:Final SOC, equality
a1=[];
b1=[];
for i=1:G.size
    a_1=zeros(G.size,96);
    a_1(i, G.in(i) : G.out(i)-1)=1;
    a_1=[reshape(a_1',[96*G.size,1])' 0 zeros(1,G.size)];
    a_1(96*G.size+1+i)=1; % : slack var
    a1=[a1; a_1];
end
b1=G.cap-G.soc;
clear a_1;
%% a4:soc const(lower) & a5:soc const(upper)
a4=[];
b4=[];
b5=[];
for i=1:G.size
    a_4=zeros(G.out(i)-G.in(i),97*G.size+1);
    a_4(:,G.in(i)+(i-1)*96:G.out(i)+(i-1)*96-1)=tril(ones(G.out(i)-G.in(i)));
    a4=[a4; a_4];
    b4=[b4; ones(size(a_4,1),1)*G.soc(i)];
    b5=[b5; ones(size(a_4,1),1)*(G.cap(i)-G.soc(i))];
end
clear a_4;
%% a3 : peak slack variable
a3=[];
b3=[];

for t=min(G.in):max(G.out)-1
    P_mat=qpf_temp;
    temp=P_mat(:,t);
    P_mat=P_mat*0;
    P_mat(:,t)=temp;
    ptemp=[reshape(P_mat',[96*G.size,1])' -1 zeros(1,G.size)];
    a3=[a3; ptemp];
    b3=[b3; B_data(t)*(-1)];
end

% for t=min(G.in):max(G.out)
%     P_mat=qpf_temp*-1;
%     temp=P_mat(:,t);
%     P_mat=P_mat*0;
%     P_mat(:,t)=temp;
%     ptemp=[reshape(P_mat',[96*G.size,1])' 1 zeros(1,G.size)];
%     a3=[a3; ptemp];
%     b3=[b3; B_data(t)];
% end

clear qpf_temp;

%     qpoptions = optimoptions('quadprog','algorithm','interior-point-convex','Display','final-detailed','MaxIterations',300,'Display','off');
qpoptions = optimoptions('linprog','Algorithm','interior-point','Display','none');

%% set A & B
% a1&b1 : TS slack var
% a2&b2 : reverse flow
% a3&b3 : peak limit
% a4&b4 : soc lower
% a5&b5 : soc upper

qpA=[a3; a4*(-1); a4];
qpB=[b3; b4; b5];
qpAeq=[a1];
qpBeq=[b1];

qpub=[repelem(G.ub,96,1); inf; ones(G.size,1)*inf];
qplb=[repelem(G.lb,96,1); 0; zeros(G.size,1)];

% test input
qpA=[a3; a4*(-1); a4];
qpB=[b3; b4; b5];
qpAeq=[a1];
qpBeq=[b1];
%% Solve: quadprog
[qpx,qpval,qpflag] = linprog(qpf,qpA,qpB,qpAeq,qpBeq,qplb,qpub,[],qpoptions);
vars={'qpH','qpf','qpA','qpB','qpAeq','qpBeq','qplb','qpub','a1','a4','a6','b1','b4','b5','b6'};
clear vars;
% arrange QP result
qpx(end-G.size+1:end)=[];
bound=qpx(end);
qpx(end)=[];
qpx_sw=reshape(qpx,[96,G.size])';
qpx_sw=round(qpx_sw,2);

disp(strcat(strcat('Schedule generation complete(EV: '),num2str(EV.size),')'));