lp_iter=0;
a=100;
%% give number to schedule
idx=find((EV.in==G.in(sch_num)));

%sch_num : %schedule number
%large P is schedule made by QP&PSO
P = qpx_sw(sch_num,:);

%small p is schedule for each EV
p.size=length(idx);
p.in=EV.in(idx);
p.out=EV.out(idx);
p.plug=[p.in p.out];
p.ie=EV.ie(idx);
p.cap=EV.cap(idx);
p.dur=p.out-p.in;
sum_Bdur=sum(p.dur);
%% objective function for Energy dist
% schedule / soc / final soc
% schedule, final soc(p.size °³), soc
lpH_1=eye(sum_Bdur + p.size, sum_Bdur + p.size);


% FOR final soc
lpH_1(sum_Bdur + 1:sum_Bdur + p.size, sum_Bdur + 1:sum_Bdur + p.size)=eye(p.size)*a;

%% set H & f
lpH=lpH_1;
lpf=[];
clear lpH_1;
%% constraint (A&B)
basicA=zeros(p.size,max(p.dur));

% 1) sum(p)==sum(P) | equality
A1=zeros(p.dur(end), sum_Bdur+p.size);
temp=0;
for i = 1:p.size
    A1(1:p.dur(i),temp+1:temp+p.dur(i))=eye(p.dur(i));
    temp=temp+p.dur(i);
end
B1=P(p.in(1):p.out(end)-1)';

% 2) target soc slack variable | equality
A2=[];
A2=zeros(p.size, sum_Bdur+p.size);
temp=0;
for i=1:p.size
    A2(i,temp+1:temp+p.dur(i))=1;
    A2(i,sum_Bdur+i)=1;
    temp=temp+p.dur(i);
end
B2=p.cap*TE-p.ie;
% % 3) soc slack variable | equality
% A3=zeros(sum_Bdur,sum_Bdur*2+p.size);
% B3=zeros(sum_Bdur,1);
% temp=0;
% for i=1:p.size
%     A3(temp+1:temp+p.dur(i)-1,temp+1:temp+p.dur(i)-1)=tril(ones(p.dur(i)-1));
%     B3(temp+1:temp+p.dur(i))=p.cap(i)/2-p.ie(i);
%     temp=temp+p.dur(i);
% end
% A3(:,sum_Bdur+1:sum_Bdur*2)=-eye(sum_Bdur);

%% set A,B & options
% A1: sum(p)==sum(P) | equality
% A2: target soc slack variable | equality
% A3: soc slack variable | equality
% A4: updated constraint

lpAeq=[A1;A2];
lpBeq=[B1;B2];
%         lpoptions=optimoptions('linprog','Algorithm','interior-point','Display','none');
lpoptions = optimoptions('quadprog','algorithm','interior-point-convex','Display','off');

%% lb & ub
lpub = [ones(sum_Bdur,1)*var_range(1); ones(p.size,1)*inf];
lplb = [ones(sum_Bdur,1)*var_range(2); ones(p.size,1)*(-inf)];

while 1
    
    %% 4) 2stage const update || inequality
    if lp_iter==0
        A4=[];
        B4=[];
    else
        if length(tp)>1
%             tp=tp(end);
            tp=fix(median(tp));
        end
        if err(tp,3)==1
            A_4=zeros(1,sum_Bdur+p.size);
            if err(tp,1)~=1
                temp=sum(p.dur(1:err(tp,1)-1));
            end
            A_4(temp+1:temp+err(tp,2)-p.in(err(tp,1)))=1;
            A4=[A4;A_4];
            prePB = sum(lpx_sw(err(tp,1), p.in(err(tp,1)):err(tp,2)-1));
            B4=[B4; prePB - (lpsoc(err(tp,1),err(tp,2))-p.cap(err(tp,1)))];
            
        else
            A_4=zeros(1,sum_Bdur+p.size);
            if err(tp,1)~=1
                temp=sum(p.dur(1:err(tp,1)-1));
            end
            A_4(temp+1:temp+err(tp,2)-p.in(err(tp,1)))=-1;
            A4=[A4;A_4];
            prePB = sum(lpx_sw(err(tp,1), p.in(err(tp,1)):err(tp,2)-1));
            B4=[B4; -(prePB - (lpsoc(err(tp,1),err(tp,2))-0))];
            
%             disp('stage-B negetive situation occur');
        end
    end

    lpA=[A4];
    lpB=[B4];
    
    %% solve
    [lpx,lpval,lpflag] = quadprog(lpH,lpf,lpA,lpB,lpAeq,lpBeq,lplb,lpub,[],lpoptions);
    % [lpx,fval,lpflag,output] = linprog([],A,B,Aeq,Beq,lb,ub,lpoptions);
    if (lpflag==-2)&&(lp_iter>0)
        brflag=-1;
        clear A4;
        clear B4;
        break;
    end
    lpx=round(lpx,2);
    
    %% evaluation
    % shifting
    lpx(end-p.size+1:end) = [];
    
    lpx_sw=zeros(p.size,96);
    temp=0;
    for i=1:p.size
        lpx_sw(i,p.in(i):p.out(i)-1) = lpx(1:p.dur(i));
        lpx(1:p.dur(i))=[];
    end
    
    %% check LP result
    lpsoc=zeros(p.size,96);
    for i=1:p.size
        lpsoc(i,p.in(i))=p.ie(i);
    end
    for i=1:p.size
        for t=1:p.out(i)-p.in(i)
            lpsoc(i,p.in(i)+t)=lpsoc(i,p.in(i)+t-1)+lpx_sw(i,p.in(i)+t-1);
        end
    end
    lpsoc=round(lpsoc,2);
    % kwh=>%
    lpsoc_per=lpsoc;
    lpsoc_per=lpsoc_per./EV.cap(idx)*100;
    lpsoc_per=floor(lpsoc_per*10)/10;
    
    %% update const
    
    if sum(sum(lpsoc_per>101))||sum(sum(lpsoc_per<-1))
        [ax ay]=find((lpsoc_per>101)==1);
        [bx by]=find((lpsoc_per<-1)==1);
        if isempty(ax)~=1 && isempty(bx)~=1
            err=[ax ay ones(length(ax),1);bx by -ones(length(bx),1)];
        elseif isempty(ax)~=1
            err=[ax ay ones(length(ax),1)];
        elseif isempty(bx)~=1
            err=[bx by -ones(length(bx),1)];
        end
        tp=find( err(:,2) == min(err(:,2)) );
    else
        lp.x=[lp.x;lpx_sw];
        clear A4,B4;
        save=save+1;
        break;
    end
    lp_iter=lp_iter+1;

end
