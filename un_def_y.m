function[Y]=def_y(P,EV_num,plug_in)
%% Define drawer
ya=P(2,13)*0;
Y=repelem(ya,EV_num,1);

%% check P
for EV = 1:EV_num
    
    Y(EV)=sum(P(EV,plug_in(EV,1):plug_in(EV,2)-1));
end
end