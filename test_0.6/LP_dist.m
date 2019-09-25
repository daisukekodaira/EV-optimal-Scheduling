%% give number to schedule
EVresult.sch=[];
idxlist=[];

for sch_num=1:G.size
    idx=find(EV.in==G.in(sch_num));
    if length(idx)~=1
        
        %sch_num : %schedule number
        %large P is schedule made by QP&PSO
        P = qp.x_sw(sch_num,:);
        
        %small p is schedule for each EV
        p.size=length(idx);
        p.dur=G.out(sch_num)-G.in(sch_num);
        p.in=EV.in(idx);
        p.out=EV.out(idx);
        p.soc=EV.soc(idx);
        p.cap=EV.cap(idx);
        
        %% objective function for Energy dist
        lpH_1=zeros(p.dur*(p.size)*2 + p.size, p.dur*(p.size)*2 + p.size);
        for g=1:p.size
            P2=zeros(p.dur,p.dur);
            for i=1:p.dur
                if (i>=p.in(g))&&(i<=p.out(g)-1)
                    P2(i,i)=1*c;
                else
                end
            end
            lpH_1(p.dur*(g-1)+1:p.dur*g, p.dur*(g-1)+1:p.dur*g)=P2;
        end
        % FOR final soc
        for i=1:p.size
            lpH_1(p.dur*p.size+i,p.dur*p.size+i)=a;
        end
        % FOR (soc-50%)^2
        for i=1:p.dur*p.size
            lpH_1(p.dur*p.size+p.size+i,p.dur*p.size+p.size+i)=b;
        end
        
        %% set H & f
        lpH=lpH_1;
        lpf=[];
        
        %% constraint (A&B)
        basicA=zeros(p.size,p.dur);
        
        % 1) sum(sum(P)) == qp.x_sw, "equality"
        A1=[];
        B1=[];
        tempA=basicA;
        for i=1:p.size
            tempA(i,1:p.out(i)-p.in(i))=1;
        end
        for i=1:p.dur
            tempa=basicA;
            temp=tempA(:,i);
            tempa(:,i)=temp;
            A1=[A1; reshape(tempa',[p.dur*p.size,1])' zeros(1,p.size*(p.dur+1))];
            B1=[B1; P(G.in(sch_num)+i-1)];
        end
        clear temp
        clear tempa
        
        % 2) sum(P) == S, "equality"
        A2=[];
        B2=[];
        for i=1:p.size
            A_2=zeros(p.size,p.dur);
            A_2(i, p.in(i) : p.out(i)-1)=100/p.cap(i);
            A_2=[reshape(A_2',[p.dur*p.size,1])' zeros(1,p.size*(p.dur+1))];
            A_2(p.dur*p.size+i)=1;
            A2=[A2; A_2];
            B_2=p.cap(i)-p.soc(i);
            B2=[B2; B_2];
        end
        
        % 3) each EV soc tracking, [-A3 B3] is lower, [A3 B4] is upper, "inequality"
        A3=[];
        B3=[];
        for g=1:p.size
            for t=1:p.out(g)-p.in(g)
                A_3=basicA;
                A_3(g,1:1+t-1)=1;
                A_3=[reshape(A_3',[p.dur*p.size,1])' zeros(1,p.size*(p.dur+1))];
                A_3(p.size*(p.dur+1)+ t + p.dur*(g-1))=-1;
                A3=[A3;A_3];
                B3=[B3; p.cap(g)/2-p.soc(g)];
            end
        end
        
        %% set A,B & options
        % A1: sum(p)==sum(P) | equality
        % A2: target soc slack variable | equality
        % A3: soc slack variable | equality
        
        lpA=[];
        lpB=[];
        lpAeq=[A1; A2; A3];
        lpBeq=[B1; B2; B3];

%         lpoptions=optimoptions('linprog','Algorithm','interior-point','Display','none');
        lpoptions = optimoptions('quadprog','algorithm','interior-point-convex','Display','off','MaxIterations',300);
        
        %% lb & ub
        lpub = [ones(p.size*p.dur,1)*var_range(1); ones(p.size*(p.dur+1),1)*inf];
        lplb = [ones(p.size*p.dur,1)*var_range(2); ones(p.size*(p.dur+1),1)*(-inf)];
        
        %% solve
        
        [lpx,lpval,lpflag] = quadprog(lpH,lpf,lpA,lpB,lpAeq,lpBeq,lplb,lpub,[],lpoptions);
        % [lpx,fval,lpflag,output] = linprog([],A,B,Aeq,Beq,lb,ub,lpoptions);
        
        %shifting
        lpx(end-p.size*(p.dur+1)+1:end)=[];
        lp.x=lpx';
        lp.flag=lpflag;
        temp_x=reshape(lpx',[p.dur,p.size])';
        for i=1:p.size
            if p.out(i)~=G.out(sch_num)
                temp_x(i,p.out(i)-p.in(i)+1:p.dur)=0;
            end
        end
        %
        lp.x_sw=zeros(p.size,96);
        lp.x_sw(:,G.in(sch_num):G.out(sch_num)-1)=temp_x;
        
    else
        lp.x_sw=qp.x_sw(sch_num,:);
    end
    % % % % % % % %
    % if sch_num==2
%     lp.x_sw(1,p.in(1)+2)=-23;
%     lp.x_sw(2,p.in(2)+1)=-39;
% end
% % % % % % % % 
    EVresult.sch=[EVresult.sch; lp.x_sw];
    idxlist=[idxlist; idx];
end

%% check LP result
lp.soc=zeros(EV.size,96);
for ev=1:EV.size
    lp.soc(ev,EV.in(idxlist(ev)))=EV.soc(idxlist(ev));
end
for ev=1:EV.size
    for t=1:EV.out(idxlist(ev))-EV.in(idxlist(ev))
        lp.soc(ev,EV.in(idxlist(ev))+t)=lp.soc(ev,EV.in(idxlist(ev))+t-1)+EVresult.sch(ev,EV.in(idxlist(ev))+t-1);
    end
end

%% round the result
qp.x=round(qp.x,2);
qp.x_sw=round(qp.x_sw,2);
qp.X=round(qp.X,2);
qp.soc=round(qp.soc,2);

lp.x=round(lp.x,2);
lp.x_sw=round(lp.x_sw,2);
lp.soc=round(lp.soc,2);

%%
% % kwh=>%
% lp.soc=lp.soc./EV.cap(idxlist)*100;
% if plotflag==1
%     figure(2)
%     for i=1:size(lp.soc,1)
%         plot(1:96,lp.soc(i,:))
%         hold on
%     end
% end
%% update var range
% iterflag : 1 = perfect solution
% iterflag : -1 = need to change constraint upper bound

if sum(sum(lp.soc>100))||sum(sum(lp.soc<0))
    % change upper bound
    if sum(sum(lp.soc>100))
        [erridx.a erridx.b]=find((lp.soc>100)==1);
        tp=find( erridx.b == min(erridx.b)); %update target point
        err_update=[];
        
        err_update=(lp.soc(erridx.a(tp),erridx.b(tp))-p.cap(erridx.a));
        gidx=find(G.in==EV.in(idxlist(erridx.a(tp))));
        if (Prange.up(gidx,erridx.b(tp)-1)-err_update)<=0
            Prange.up(gidx,erridx.b(tp)-1)=0;
        else
            Prange.up(gidx,erridx.b(tp)-1)=Prange.up(gidx,erridx.b(tp)-1)-err_update;
        end
        lp.update=[Prange.up; Prange.low];
        iterflag=-1;
        
        % change lower bound
    elseif sum(sum(lp.soc<0))
        [erridx.a erridx.b]=find((lp.soc<0)==1);
        tp=find( erridx.b == min(erridx.b)); %update target point
        err_update=[];
        
        err_update=(lp.soc(erridx.a(tp),erridx.b(tp))-p.cap(erridx.a));
        gidx=find(G.in==EV.in(idxlist(erridx.a(tp))));
        
        if (Prange.low(gidx,erridx.b(tp)-1)-err_update)>=0
            Prange.low(gidx,erridx.b(tp)-1)=0;
        else
            Prange.low(gidx,erridx.b(tp)-1)=Prange.low(gidx,erridx.b(tp)-1)-err_update;
        end
        lp.update=[Prange.up; Prange.low];
        iterflag=-1;
    end
    abc=1;
else
    iterflag=1;
end