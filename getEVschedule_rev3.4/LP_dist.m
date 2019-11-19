lp_iterflag=-1;
lp_iter=0;

while lp_iterflag==-1
    %% give number to schedule
    idx=find((EV.in==G.in(sch_num))&(EV.out==G.out(sch_num)));
    
    %sch_num : %schedule number
    %large P is schedule made by QP&PSO
    P = qpx_sw(sch_num,:);
    
    %small p is schedule for each EV
    p.size=length(idx);
    p.in=EV.in(idx);
    p.out=EV.out(idx);
    p.plug=[p.in p.out];
    p.soc=EV.soc(idx);
    p.cap=EV.cap(idx);
    p.dur=p.out-p.in;
    LP_idx=find((Group.in==p.in(1))&(Group.out==p.out(1)));
    EV_idx=find((EV.in==p.in(1))&(EV.out==p.out(1)));
    %% objective function for Energy dist
    % schedule / soc / final soc
    % schedule, final soc(p.size °³), soc
    lpH_1=eye(max(p.dur)*p.size + sum(p.dur) + p.size, max(p.dur)*p.size + sum(p.dur) + p.size);
    
    % FOR (soc-50%)^2
    lpH_1(max(p.dur)*p.size+1:max(p.dur)*p.size+sum(p.dur),max(p.dur)*p.size+1:max(p.dur)*p.size+sum(p.dur))=eye(sum(p.dur))*b;
    
    % FOR final soc
    lpH_1(max(p.dur)*p.size+sum(p.dur)+ 1:max(p.dur)*p.size+sum(p.dur)+ p.size,max(p.dur)*p.size+sum(p.dur)+ 1:max(p.dur)*p.size+sum(p.dur)+ p.size)=eye(p.size)*a;
    
    %% set H & f
    lpH=lpH_1;
    lpf=[];
    %% constraint (A&B)
    basicA=zeros(p.size,max(p.dur));
    
    % 1) sum(p)==sum(P) | equality
    A1=[repmat(eye(max(p.dur)),1,p.size) zeros(max(p.dur),sum(p.dur) + p.size)];
    B1=P(G.in(sch_num):G.out(sch_num)-1)';
    
    % 2) target soc slack variable | equality
    A2=[];
    for i=1:p.size
        A_2=basicA;
        A_2(i, 1 : p.dur(i))=1;
        A_2=[reshape(A_2',[max(p.dur)*p.size,1])' zeros(1,sum(p.dur)+p.size)];
        A_2(max(p.dur)*p.size + sum(p.dur) + i)=1;
        A2=[A2; A_2];
    end
    B2=p.cap-p.soc;
    %% 3) soc slack variable | equality
    A3=[];
    B3=[];
    for g=1:p.size
        for t=1:p.dur(g)
            A_3=basicA;
            A_3(g,1:1+t-1)=1;
            A_3=[reshape(A_3',[max(p.dur)*p.size,1])' zeros(1,sum(p.dur)+p.size)];
            if g==1
                A_3(p.size*max(p.dur) + t) = -1;
            else
                A_3(p.size*max(p.dur) + t + sum(p.dur(1:g-1)))=-1;
            end
            A3=[A3;A_3];
            %                 B3=[B3; p.cap(g)/2-p.soc(g)];
            B3=[B3; p.cap(g)-p.soc(g)];
        end
    end
    
    %% 4) 2stage const update || inequality
    if lp_iter<1
        A4=[];
        B4=[];
    else
        if err_update(3)>=0
            for i=1:length(err_idx)
                A_4=basicA;
                A_4(err_idx(i),1:err_update(2)-err_update(1)+1)=1;
                A_4=[reshape(A_4',[max(p.dur)*p.size,1])' zeros(1,sum(p.dur)+p.size)];
                
                B_4=sum( lpx_sw(err_idx(i),err_update(1):err_update(2)) )-err_update(3);
                A4=[A4; A_4];
                B4=[B4; B_4];
            end
        else
            for i=1:length(err_idx)
                A_4=basicA;
                A_4(err_idx(i),1:err_update(2)-err_update(1)+1)=-1;
                A_4=[reshape(A_4',[max(p.dur)*p.size,1])' zeros(1,sum(p.dur)+p.size)];
                
                B_4=sum( lpx_sw(err_idx(i),err_update(1):err_update(2)) )-err_update(3);
                A4=[A4; A_4];
                B4=[B4; B_4*(-1)];
            end
        end
    end
    %% set A,B & options
    % A1: sum(p)==sum(P) | equality
    % A2: target soc slack variable | equality
    % A3: soc slack variable | equality
    % A4: updated constraint
    
    lpA=[A4];
    lpB=[B4];
    lpAeq=[A1; A2; A3];
    lpBeq=[B1; B2; B3];
    %         lpAeq=[A1; A3];
    %         lpBeq=[B1; B3];
    
    %         lpoptions=optimoptions('linprog','Algorithm','interior-point','Display','none');
    lpoptions = optimoptions('quadprog','algorithm','interior-point-convex','Display','off');
    
    %% lb & ub
    lpub = [ones(p.size*max(p.dur),1)*var_range(1); ones(sum(p.dur)+p.size,1)*inf];
    lplb = [ones(p.size*max(p.dur),1)*var_range(2); ones(sum(p.dur)+p.size,1)*(-inf)];
    
    %% solve
    [lpx,lpval,lpflag] = quadprog(lpH,lpf,lpA,lpB,lpAeq,lpBeq,lplb,lpub,[],lpoptions);
    % [lpx,fval,lpflag,output] = linprog([],A,B,Aeq,Beq,lb,ub,lpoptions);
    lpx=round(lpx,2);
    if (lpflag~=1)&&(lpflag~=2)
        lp_iterflag=2;
        break;
    end
    
    %% evaluation
    %shifting
    lpx(end-sum(p.dur)-p.size+1:end) = [];
    temp_x=reshape(lpx',[max(p.dur),p.size])';
    for i=1:p.size
        if p.out(i)~=G.out(sch_num)
            temp_x(i,p.out(i) - p.in(i)+1:max(p.dur)) = 0;
        end
    end
    %
    lpx_sw = zeros(p.size,96);
    lpx_sw(:,G.in(sch_num):G.out(sch_num)-1)=temp_x;
    
    %% check LP result
    lpsoc=zeros(p.size,96);
    for ev=1:p.size
        lpsoc(ev,p.in(ev))=p.soc(ev);
    end
    for ev=1:p.size
        for t=1:p.out(ev)-p.in(ev)
            lpsoc(ev,p.in(ev)+t)=lpsoc(ev,p.in(ev)+t-1)+lpx_sw(ev,p.in(ev)+t-1);
        end
    end
    
    % kwh=>%
    lpsoc_per=lpsoc;
    lpsoc_per=lpsoc_per./EV.cap(idx)*100;
    
    %% update const
    if sum(sum(lpsoc_per>100))||sum(sum(lpsoc_per<0))
        [aa bb]=find((lpsoc_per>100)==1);
        [cc dd]=find((lpsoc_per<0)==1);
        err=[aa bb;cc dd];
        tp=find( err(:,2) == min(err(:,2)) );
        %             t_idx=find(err(:,1)==min(err(:,1)));
        %             tp=find(err(t_idx,2) == min(err(t_idx,2)));
        temp=0;
        for i=1:length(tp)
            if (lpsoc(err(tp(i),1),err(tp(i),2)))>0
                temp=temp + lpsoc(err(tp(i),1),err(tp(i),2))-p.cap(err(tp(i),1));
            else
                temp=temp + lpsoc(err(tp(i),1),err(tp(i),2))-0;
            end
        end
        if (temp<0.1)&&(temp>0)
            temp=0.1*d;
        elseif (temp>-0.1)&&(temp<0)
            temp=-0.1*d;
        end
        % [in_time duration amount]
        err_update=[G.in(sch_num) err(tp(1),2)-1 temp];
        qp_err_update=[qp_err_update; err_update];
        err_idx=[err(tp,1)'];
        err_x=lpx_sw;
        err_schnum=sch_num;
        update_issue=1;        
    else
        except(LP_idx)=true;
    end
    
    if (qp_iter==0)&&(lp_iter==0)
        x.third(EV_idx,:)=lpx_sw;
    end
    
    lp_iter=lp_iter+1;
    if except(LP_idx)==1
        x.first(LP_idx,:)=P;
        x.second(EV_idx,:)=lpx_sw;
        clear temp;
        break;
    end
end
