function[x,fval,exitflag,in,out,op_size,needenergy,a1,b1]=QP_test(B_data,plug_in,ori_soc, EV_num,EV_cap, bound, Tariff,fsoc,power,w_t)
in=plug_in(:,1);
out=plug_in(:,2);

%% 데이터 전처리
for i=1:96
    if sum(find(i==plug_in(:,1))) >= 1
        exist op_size;
        if ans == 0
            op_size=[i];
        else
            op_size=[op_size; i];
        end
    end
end
op_size=[op_size op_size];

for i=1:size(op_size,1)
    temp_ans=find(op_size(i)==plug_in(:,1));
    temp_iter=size(temp_ans,1);
    
    for tp=1:temp_iter
        exist temp;
        if ans==0;
            temp=plug_in(temp_ans(tp),2);
        else
            temp=[temp; plug_in(temp_ans(tp),2)];
        end
        
    end
    op_size(i,2)=max(temp);
    clear temp
end

%% P^2, 차 한대만. => plug in, out 체크해서 쭉 넣으면 될듯.
H_1=zeros(96*size(op_size,1),96*size(op_size,1));
for EV=1:size(op_size,1)
    exist P2;
    if ans==0
        P2=zeros(96,96);
    end
    for i=1:96
        if (i>=op_size(EV,1))&&(i<=op_size(EV,2)-1)
            P2(i,i)=1;
        else
        end
    end
    
    H_1(96*(EV-1)+1:96*EV, 96*(EV-1)+1:96*EV)=P2;
    clear P2
end

%% f_1(D*P) & f_2(TOU)
f1=zeros(96*size(op_size,1),1);
f2=zeros(96*size(op_size,1),1);

f_1=zeros(96,1);
for EV=1:size(op_size,1)
    for i=1:96
        if (i>=op_size(EV,1))&&(i<=op_size(EV,2)-1)
            f_1(i)=1;
        else
        end
    end
    f1(1+96*(EV-1):96*EV,1) = f_1.*B_data;
    f2(1+96*(EV-1):96*EV,1) = f_1.*Tariff';
    f_1=zeros(96,1);
end
reshape(f1,[96,length(op_size)]);
%% set H & f
% f1=f1/max(B_data);
% f2=f2/max(Tariff);

H=H_1;
% f=f1+f2*w_t;
f=f1;

%% define A, inequality const
needenergy=zeros(96,96);
for EV=1:EV_num
    needenergy(in(EV),out(EV)-in(EV))=needenergy(in(EV),out(EV)-in(EV))+EV_cap*fsoc-ori_soc(EV);
end

% required energy const
for en=1:size(op_size,1)
    a_1=zeros(length(op_size),96);
    for dr=1:96
        if needenergy(op_size(en,1),dr)~=0
            a_1(en, op_size(en,1) : op_size(en,1)+dr-1)=1;
            b_1=needenergy(op_size(en,1),dr);
            a_1=reshape(a_1',[96*length(op_size),1])';
            exist a1;
            if ans==0
                a1=[a_1];
                b1=[b_1];
            else
                a1=[a1; a_1];
                b1=[b1; b_1];
            end
            a_1=zeros(length(op_size),96);
        end
    end
end

a1=a1*(-1);
b1=b1*(-1);
% A=a1;
% B=b1;


% a2 : peak boundary_reverse flow
op_mat=zeros(length(op_size),96);
for row=1:length(op_size)
    for col=1:96
        if (col>=op_size(row,1))&(col<op_size(row,2))
            op_mat(row,col)=1;
        end
    end
end

for i=1:96
    temp=zeros(size(op_mat));
    temp(:,i)=ones(size(temp,1),1);
    a_2=op_mat.*temp;
    sum(sum(a_2));
    if ans>0
        a_2=reshape(a_2',[96*length(op_size),1])';
        %         b_2=B_data(i)-min(B_data);
        b_2=B_data(i);
        b_3=bound-B_data(i);
        exist a2;
        if ans==0
            a2=a_2;
        else
            a2=[a2;a_2];
        end        
        exist b2;
        if ans==0
            b2=b_2;
        else
            b2=[b2;b_2];
        end
        exist b3;
        if ans==0
            b3=b_3;
        else
            b3=[b3;b_3];
        end
    end
end

a2=a2*(-1);
% A=[A; a2];
% B=[B; b2];
A=a2;
B=b2;

% a3 : peak boundary_limitation
a3=a2*(-1);
A=[A; a3];
B=[B; b3];

% a4:soc const(up) & a5:soc const(lower)

a_4 = zeros(size(op_size(:,1),1),96);
for EV=1:size(op_size(:,1),1)
    idx=find(plug_in(EV)==op_size(:,1));
    a_4(idx, plug_in(EV,1) : plug_in(EV,2)-1)=1;
    b_4=EV_cap-ori_soc(EV);
    a_4=reshape(a_4',[96*length(op_size),1])';
    b_5=ori_soc(EV);
    exist a4;
    if ans==0
        a4=a_4;
    else
        a4=[a4; a_4];
    end
    if ans==0
        b4=b_4;
    else
        b4=[b4; b_4];
    end
        if ans==0
        b5=b_5;
    else
        b5=[b5; b_5];
    end
    a_4 = zeros(size(op_size(:,1),1),96);
end
a5=a4*(-1);

A=[A; a4; a5];
B=[B; b4; b5];

%% P boundary
bound_mat=zeros(length(op_size),96);
for row=1:EV_num
    for col=1:96
        if (col>=plug_in(row,1))&(col<plug_in(row,2))
            idx=find(plug_in(row,1)==op_size(:,1));
            bound_mat(idx,col)=bound_mat(idx,col)+1;
        end
    end
end
 bound_mat=reshape(bound_mat',[96*size(bound_mat,1),1]);
%%


% set charge/discharge value
ub=bound_mat*power(1);
lb=bound_mat*power(2);

%% 다음과 같이 표시 없이 'interior-point-convex' 알고리즘을 사용하도록 옵션을 설정합니다.
options = optimoptions('quadprog','algorithm','interior-point-convex','Display','final-detailed','MaxIterations',300)%'Display','off');
%     options = optimoptions('quadprog','algorithm','interior-point-convex','Display','final-detailed','MaxIterations',200);
%% quadprog를 호출합니다.
%     [x,fval,exitflag] = quadprog(H,f,A,B,Aeq,Beq,lb,ub,[],options);
[x,fval,exitflag] = quadprog(H,f,A,B,a1,b1,lb,ub,[],options);
%required check
rr=reshape(x,[96,length(op_size)])';
for row=1:96
    for col=1:96
        if needenergy(row,col)~=0
            idx=find(row==op_size(:,1));
            exist c_a;
            if ans==0
                c_a=sum(rr(idx,row:row+col-1));
            else
                c_a=[c_a sum(rr(idx,row:row+col-1))];
            end
            exist c_b;
            if ans==0
                c_b=needenergy(row,col);
            else
                c_b=[c_b needenergy(row,col)];
            end
        end
    end
end
%result
c_r=round([c_a' c_b'],2);
c_r(:,1)>=c_r(:,2);
find(0==ans)
figure(1)
plot(c_r)
xlabel("EV number");
ylabel("Required Energy for each EV");
title("Check if the optimization result satisfy the required energy as planned")
legend("Result of optimization","Required energy");

end

