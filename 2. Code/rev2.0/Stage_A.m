G.size
a=50000;
b=100;
sum_Adur=sum(G.dur);
%% define var range || ##while start point##
%% f_tou & f_peak
% def P tou cost
qpf_tou=ones(sum_Adur,1);
temp=0;
for g=1:G.size
    qpf_tou(temp + 1 : temp + G.dur(g))=qpf_tou(temp + 1 : temp + G.dur(g)).*Tariff_B(G.in(g) : G.out(g)-1)';
    temp = temp + G.dur(g);
end

%def PL cost % FE
qpf_tou=[qpf_tou; 7200*weight; ones(G.size,1)*a];

%% set H & f
qpf=qpf_tou;
clear qpH_1;
clear qpf_tou;
%% define A
% charging requirment
% a1=[];
% b1=[];
% temp=0;
% for i=1:G.size
%     %number of car is only one in vev
%     if G.s(i)~=999
%         a_1=zeros(1,sum_Adur+1+G.size);
%         a_1(temp+1 : temp+G.dur(i)) = 1;
%         a1=[a1; a_1];
%         b1=[b1; G.s(i)];
%     else
%         idx = find(G.belong(:,1)==G.in(i));
%         dur = G.belong(idx,2) - G.belong(idx,1);
%
%         for j = 1 : length(idx)
%             a_1=zeros(1,sum_Adur+1+G.size);
%             a_1(temp+1 : temp+dur(j)) = 1;
%             a1=[a1; a_1];
%             b1=[b1; G.belong(idx(j),4)];
%
%             if (j>1)
%                 if (G.belong(idx(j),1)==G.belong(idx(j-1),1))
%                     a1(end-1,:)=[];
%                     b1(end-1,:)=[];
%                 end
%             end
%         end
%     end
%     temp = temp + G.dur(i);
% end

%% a2b2:soc const(lower) & a2b3:soc const(upper)
a2=zeros(sum_Adur,sum_Adur+1+G.size);
b2=zeros(sum_Adur,1);
b3=zeros(sum_Adur,1);
temp=0;
for i=1:G.size
    a2(temp+1 : temp + G.dur(i), temp+1 : temp+G.dur(i)) = tril(ones(G.dur(i)));
    b2(temp+1 : temp + G.dur(i)) = G.ie(i) - G.Emin(i,1 : G.dur(i));
    b3(temp+1 : temp + G.dur(i)) = G.cap(i) - G.ie(i);
    temp=temp+G.dur(i);
end

%% a4 : peak slack variable
a4=zeros(max(G.out)-min(G.in),sum_Adur+1+G.size);
b4=zeros(max(G.out)-min(G.in),1);
a4(:,sum_Adur+1)=-1;
j=1;
for t=min(G.in):max(G.out)-1
    temp=0;
    for i=1:G.size
        if (G.in(i)<=t)&&(G.out(i)>t)
            a4(j,temp+t+1-G.in(i))=1;
        end
        temp=temp+G.dur(i);
    end
    b4(j)=B_data(t)*-1;
    j=j+1;
end

%     qpoptions = optimoptions('quadprog','algorithm','interior-point-convex','Display','final-detailed','MaxIterations',300,'Display','off');
qpoptions = optimoptions('linprog','Algorithm','interior-point','Display','none');

% Const:Final energy, equality => FE가 아니라 다른 용어 필요 = 에너지의 차이를 최소화하는 의미로
a5=zeros(G.size,sum_Adur+1+G.size);
b5=zeros(G.size,1);
temp=0;
for i=1:G.size
    if G.s(i)~=999
        a5(i,temp+1 : temp+G.dur(i)) = 1;
        b5(i)=G.s(i);
    else
        idx = find(G.belong(:,1)==G.in(i));
        idx = idx(end);
        dur = G.belong(idx,2) - G.belong(idx,1);
        
        a5(i,temp+1 : temp+dur) = 1;
        b5(i)=G.belong(idx,4);
    end
    
    a5(i,temp+1 : temp+G.dur(i))=1;
    a5(i,sum_Adur+1+i)=1;
    temp = temp + G.dur(i);
end


%% qpub qplb
qpub=zeros(sum_Adur+1+G.size,1);
qplb=zeros(sum_Adur+1+G.size,1);
temp=0;
for i=1:G.size
    qpub(temp+1 : temp + G.dur(i))=G.cp(i,1:G.dur(i))';
    qplb(temp+1 : temp + G.dur(i))=G.dp(i,1:G.dur(i))';
    temp=temp+G.dur(i);
end
qpub(sum_Adur+1:end)=ones(1+G.size,1)*inf;
qplb(sum_Adur+1:end)=zeros(1+G.size,1);


%% set A & B
% -a1 -b1 : TE slack var (ineq)
% -a2 b2 : Energy lower (ineq)
%  a2 b3 : Energy upper (ineq)
%  a4 b4 : PL           (ineq)
%  a5 b5 : TE slack var (eq)

lp.x=[];
qp_iter=0;
save=1;
while 1
    
    %% a6: update constraint, while point #####
    if qp_iter==0
        a6=[]; b6=[];
    elseif err(tp,3)==1
        if err(tp,2)~=G.out(sch_num)
            a_6=zeros(1,sum_Adur+1+G.size);
            temp=0;
            if sch_num~=1
                temp=sum(G.dur(1:sch_num-1));
            end
            a_6(1,temp+1:temp+err(tp,2)-G.in(sch_num))=1;
            a6=[a6; a_6];
            prePA = sum(qpx_sw(sch_num, G.in(sch_num):err(tp,2)-1));
            b6=[b6; prePA - (lpsoc(err(tp,1),err(tp,2))-p.cap(err(tp,1)))];
        else
            a_6=zeros(1,sum_Adur+1+G.size);
            temp=0;
            if sch_num~=1
                temp=sum(G.dur(1:sch_num-1));
            end
            a_6(1,temp+p.dur(err(tp,1)-1)+1:temp+err(tp,2)-G.in(sch_num))=1;
            a6=[a6; a_6];
            prePA = sum(qpx_sw(sch_num, p.out(err(tp,1)-1):err(tp,2)-1));
            b6=[b6; prePA - (lpsoc(err(tp,1),err(tp,2))-p.cap(err(tp,1)))];
        end
    else
        if err(tp,2)~=G.out(sch_num)
            a_6=zeros(1,sum_Adur+1+G.size);
            temp=0;
            if sch_num~=1
                temp=sum(G.dur(1:sch_num-1));
            end
            a_6(1,temp+1:temp+err(tp,2)-G.in(sch_num))=-1;
            a6=[a6; a_6];
            prePA = sum(qpx_sw(sch_num, G.in(sch_num):err(tp,2)-1));
            b6=[b6; prePA - (lpsoc(err(tp,1),err(tp,2))-p.cap(err(tp,1)))];
        else
            a_6=zeros(1,sum_Adur+1+G.size);
            temp=0;
            if sch_num~=1
                temp=sum(G.dur(1:sch_num-1));
            end
            a_6(1,temp+p.dur(1)+1:temp+err(tp,2)-G.in(sch_num))=-1;
            a6=[a6; a_6];
            prePA = sum(qpx_sw(sch_num, p.out(1)+1:err(tp,2)-1));
            b6=[b6; prePA - (lpsoc(err(tp,1),err(tp,2))-0)];
            disp('stage-A negetive situation occur');
        end

    end
    
    qpA=[-a2;a2;a4;a6];
    qpB=[ b2;b3;b4;b6];
    qpAeq=[a5];
    qpBeq=[b5];
    
    %% Solve: quadprog
    %     [qpx,qpval,qpflag] = quadprog(qpH,qpf,qpA,qpB,qpAeq,qpBeq,qplb,qpub,[],qpoptions);
    [qpx,qpval,qpflag] = linprog(qpf,qpA,qpB,qpAeq,qpBeq,qplb,qpub,[],qpoptions);
    %     vars={'qpH','qpf','qpA','qpB','qpAeq','qpBeq','qplb','qpub','a1','a4','a6','b1','b4','b5','b6'};
    %     clear vars;
    % arrange QP result
    qpx(sum_Adur+2:end)=[];
    bound=qpx(end);
    qpx(end)=[];
    
    qpx_sw=zeros(G.size,96);
    temp=0;
    for i=1:G.size
        qpx_sw(i,G.in(i):G.out(i)-1) = qpx(1:G.dur(i));
        qpx(1:G.dur(i))=[];
    end
    %     qpx_sw=round(qpx_sw);
    qp.x=qpx_sw;
    %% ###LP: SOC distribution
    sum_flag=0;
    brflag=0;
    for sch_num=save:G.size
        %             for sch_num=4:G.size
       
        if G.num(sch_num)==1
            lp.x=[lp.x;qpx_sw(sch_num,:)];
            save=save+1;
            continue;
        end
        
        Stage_B;
        if brflag==-1
            break;
        end
%         sch_num
    end
    
    if size(lp.x,1)==EV.size
        break;
    end
    
    %% ##while end point##
    qp_iter=qp_iter+1;
end

disp( strcat (strcat('Schedule generation complete(EV: ',num2str(EV.size)),')' ) );