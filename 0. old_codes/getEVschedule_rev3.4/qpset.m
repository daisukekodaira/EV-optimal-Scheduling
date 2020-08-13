a=1000000;
b=100;
c=1;
d=1;
giveup=0;
Group=G;
%% define var range || ##while start point##
qp_iterflag=-1;
qp_iter=0;
qp_update=0; % initialize a6&b6
%except: 각 스케줄 별 분배 문제의 성공 여부
except=zeros(1,Group.size); %except: 예외처리 목록
qp.update=zeros(1,Group.size); %qp.update: 예외처리 실행 여부(true: 실행 후. false: 실행 전)

% Now peak slack variable is unactivated
while qp_iterflag==-1
    %% renew G
    for i=1:Group.size
        if (except(i)~=false)&&(qp.update(i)==false)
            temp=find((G.in==Group.in(i))&(G.out==Group.out(i)));
            G.in(temp)=[];
            G.out(temp)=[];
            G.size=length(G.in);
            G.plug(temp,:)=[];
            G.num(temp)=[];
            G.cap(temp,:)=[];
            G.soc(temp)=[];
            G.lb(temp)=[];
            G.ub(temp)=[];
            qp.update(i)=true;
            qp_update=1;
            B_data=B_data+x.first(i,:)';
        end
    end
    if sum(except)==Group.size
        qp_iterflag=1; %if iterflag=1 => terminate while loop
        break;
    end
    
    %% H&f(P(96*G.size) || PL(1) || TS(G.size))
    %     qpH_1=zeros(97*G.size+1,97*G.size+1);
    %     qpH_1(1:96*G.size,1:96*G.size)=eye(96*G.size);
    %
    %     qpH_1(96*G.size+1+1:96*G.size+1+G.size,96*G.size+1+1:96*G.size+1+G.size)=eye(G.size)*a;
    %
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
    
    clear qpf_temp;
    
    %     qpoptions = optimoptions('quadprog','algorithm','interior-point-convex','Display','final-detailed','MaxIterations',300,'Display','off');
    qpoptions = optimoptions('linprog','Algorithm','interior-point','Display','none');
    
    
    %% a6: update constraint
    if (qp_iter<=0) || (qp_update==1)
        a6=[]; %a6&b6 : update constraint
        b6=[];
        qp_update=0;
    elseif (isempty(qp_err_update)~=1)
        %a6&b6 : S update
        a_6=zeros(G.size,96);
        if qp_iter==4
            asp=1;
        end
        qp_err_update=qp_err_update(1,:);
        %         t_idx=find((G.in==qp_err_update(1))&(G.out==qp_err_update(2)));
        t_idx=1;
        if qp_err_update(3)>0
            a_6(t_idx, qp_err_update(1) : qp_err_update(2))=1;
            b_6=sum(qpx_sw(t_idx, qp_err_update(1) : qp_err_update(2)))-qp_err_update(3);
        else
            a_6(t_idx, qp_err_update(1) : qp_err_update(2))=-1;
            b_6=qp_err_update(3)-sum(qpx_sw(t_idx,qp_err_update(1) : qp_err_update(2)));
        end
        a_6=[reshape(a_6',[96*G.size,1])' 0 zeros(1,G.size)];
        a6=[a6; a_6];
        b6=[b6; b_6];
    end
    if (qp_iter>1) && (length(b6)>1)
        if (a6(end)==a6(end-1)) && (b6(end)==b6(end-1))
            d=d+1;
        end
    end
    if (qp_iter>2) && (length(b6)>2)
        if (a6(end-1)==a6(end-2)) && (b6(end-1)==b6(end-2)) && (a6(end)~=a6(end-1)) && (b6(end)~=b6(end-1))
            d=1;
        end
    end
    qp_err_update=[];
    
    %% set A & B
    % a1&b1 : TS slack var
    % a2&b2 : reverse flow
    % a3&b3 : peak limit
    % a4&b4 : soc lower
    % a5&b5 : soc upper
    qpub=[repelem(G.ub,96,1); inf; ones(G.size,1)*inf];
    qplb=[repelem(G.lb,96,1); 0; zeros(G.size,1)];
    
    qpA=[a3; a4*(-1); a4; a6];
    qpB=[b3; b4; b5; b6];
    qpAeq=[a1];
    qpBeq=[b1];
    
    qpA=[a3; a4*(-1); a4; a6];
    qpB=[b3; b4; b5; b6];
    qpAeq=[a1];
    qpBeq=[b1];
    
    %% Solve: quadprog
    %     [qpx,qpval,qpflag] = quadprog(qpH,qpf,qpA,qpB,qpAeq,qpBeq,qplb,qpub,[],qpoptions);
    [qpx,qpval,qpflag] = linprog(qpf,qpA,qpB,qpAeq,qpBeq,qplb,qpub,[],qpoptions);
    vars={'qpH','qpf','qpA','qpB','qpAeq','qpBeq','qplb','qpub','a1','a4','a6','b1','b4','b5','b6'};
    clear vars;
    % arrange QP result
    qpx(end-G.size+1:end)=[];
    bound=qpx(end);
    qpx(end)=[];
    qpx_sw=reshape(qpx,[96,G.size])';
    qpx_sw=round(qpx_sw,2);
    
    for i=1:G.size
        qpx_sw(i,1:G.in(i)-1)=0;
        qpx_sw(i,G.out(i):end)=0;
    end
    
    %% ###LP: SOC distribution
    for sch_num=1:G.size
        QP_idx=find((Group.in==G.in(sch_num))&(Group.out==G.out(sch_num)));
        EV_idx=find((EV.in==G.in(sch_num))&(EV.out==G.out(sch_num)));
        if (G.num(sch_num)==1)&&(except(QP_idx)==false)
            if giveup~=1
            except(QP_idx)=true;
            x.first(QP_idx,:)=qpx_sw(sch_num,:);
            x.second(EV_idx,:)=qpx_sw(sch_num,:);
            x.third(EV_idx,:)=qpx_sw(sch_num,:);
            clear temp;
            continue;
            else
                x.first=[x.first; qpx_sw(sch_num,:)];
                x.second=[x.secondq; px_sw(sch_num,:)];
                x.third=[x.third; qpx_sw(sch_num,:)];
            end
        elseif (G.num(sch_num)==1)&&(except(QP_idx)==true)
            continue;
        end
        LP_dist_v0;
%         if except(QP_idx) ~=1
%            break; 
%         end
    end
    
    
    %% ##while end point##
    qp_iter=qp_iter+1;
end
if giveup==1
    x.first=[x.first; qpx_sw(sch_num,:)];
    x.second=[x.secondq; px_sw(sch_num,:)];
    x.third=[x.third; qpx_sw(sch_num,:)];
end

disp( strcat (strcat('Schedule generation complete(EV: ',num2str(EV.size)),')' ) );