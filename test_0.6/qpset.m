a=10000;
b=100;
c=1;
% Now peak slack variable is unactivated
%% H&f
% qpH_1=zeros(96*G.size,96*G.size);
qpH_1=zeros(97*G.size+1,97*G.size+1);
for g=1:G.size
    P2=zeros(96,96);
    for i=1:96
        if (i>=G.in(g))&&(i<=G.out(g)-1)
            P2(i,i)=1*c;
        else
        end
    end
    qpH_1(96*(g-1)+1:96*g, 96*(g-1)+1:96*g)=P2;
end
for i=1:G.size
    qpH_1(96*G.size+1+i,96*G.size+1+i)=a;
end

% f_tou & f_peak
qpf_temp=zeros(G.size,96);
for g=1:G.size
    qpf_temp(g,G.in(g):G.out(g)-1)=1;
    qpf_tou=reshape(qpf_temp',[96*G.size,1]);
end
qpf_tou=qpf_tou.*repmat(Tariff_B,1,G.size)';

% add slack vars
qpf_tou=[qpf_tou; 0; zeros(G.size,1)];
% f_tou=[f_tou; 7200];
% 7200 is peak cost weight

%% set H & f
qpH=qpH_1;
% f=f1+f2*w_t;
qpf=qpf_tou;

%% define A, inequality const
% required energy const, equality
a1=[];
b1=[];
for i=1:G.size
    a_1=zeros(G.size,96);
    a_1(i, G.in(i) : G.out(i)-1)=100/G.cap(i);
    a_1=[reshape(a_1',[96*G.size,1])' 0 zeros(1,G.size)];
    a_1(96*G.size+1+i)=1;
    a1=[a1; a_1];
    b_1=100-G.soc(i)*100/G.cap(i);
    b1=[b1; b_1];
end

% a4:soc const(lower) & a5:soc const(upper)
a4=[]; 
b4=[];
b5=[];
for g=1:G.size
    for t=1:G.out(g)-G.in(g)
        a_temp=zeros(G.size,96);
        a_temp(g,G.in(g):G.in(g)+t-1)=1;
        a_temp=[reshape(a_temp',[96*G.size,1])' 0 zeros(1,G.size)];
        a4=[a4;a_temp];
        b4_temp=G.soc(g);
        b4=[b4; b4_temp];
        b5_temp=G.cap(g)-G.soc(g);
        b5=[b5; b5_temp];
    end
end

% a2 : reverse flow
a2=[];
b2=[];
for t=min(G.in):max(G.out)-1
    P_mat=qpf_temp;
    temp=P_mat(:,t);
    P_mat=P_mat*0;
    P_mat(:,t)=temp;
    ptemp=[reshape(P_mat',[96*G.size,1])' 0 zeros(1,G.size)];
    a2=[a2; ptemp];
    b2=[b2; B_data(t)];
end

% a3 : peak slack variable
a3=[];
b3=[];

for t=min(G.in):max(G.out)
    P_mat=qpf_temp;
    temp=P_mat(:,t);
    P_mat=P_mat*0;
    P_mat(:,t)=temp;
    ptemp=[reshape(P_mat',[96*G.size,1])' -1 zeros(1,G.size)];
    a3=[a3; ptemp];
    b3=[b3; B_data(t)*(-1)];
end


qpoptions = optimoptions('quadprog','algorithm','interior-point-convex','Display','final-detailed','MaxIterations',300,'Display','off');
% qpoptions = optimoptions('linprog','Algorithm','interior-point','Display','none');

%% define var range || ##while start point##
iterflag=-1;
iteridx=0;
while iterflag==-1
    P_const.up=reshape(Prange.up',[96*size(Prange.up,1),1]);
    P_const.low=reshape(Prange.low',[96*size(Prange.low,1),1]);
    
    % set charge/discharge value
    qpub=[P_const.up; 1000; ones(G.size,1)*1000];
    qplb=[P_const.low; -1000; ones(G.size,1)*(-1)*1000];
    
    % set A & B
    % a1&b1 : S const
    % a2&b2 : reverse flow
    % a3&b3 : peak limit
    % a4&b4 : soc lower
    % a5&b5 : soc upper
    
    qpA=[a2*(-1); a4*(-1); a4];
    qpB=[b2; b4; b5];
    qpAeq=[a1];
    qpBeq=[b1];
    
    %% Solve: quadprog
    [qpx,qpval,qpflag] = quadprog(qpH,qpf,qpA,qpB,qpAeq,qpBeq,qplb,qpub,[],qpoptions);
    % [qpx,qpval,qpflag] = linprog(f,A,B,Aeq,Beq,lb,ub,[],qpoptions);
    
    % arrange QP result
    qpx(end-G.size+1:end)=[];
    bound=qpx(end);
    qpx(end)=[];
    qp.x=qpx';
    qp.x_sw=reshape(qpx,[96,G.size])';
    qp.X=sum(qp.x_sw); % Sum of available EVs charge/discharge amount with the 15 min instances
    
    % soc check
    qp.soc=zeros(G.size,96);
    for g=1:G.size
        qp.soc(g,G.in(g))=G.soc(g);
    end
    for g=1:G.size
        for t=1:G.out(g)-G.in(g)
            qp.soc(g,G.in(g)+t)=qp.soc(g,G.in(g)+t-1)+qp.x_sw(g,G.in(g)+t-1);
        end
    end
    %% LP: SOC distribution
    LP_dist;
    
    %% ##while end point##
    iteridx=iteridx+1
end