function[Y]=def_y(P,EV)
%% Define drawer
ya=P(2,13)*0;
Y=repelem(ya,EV.size,1);

%% check P
for ev = 1:EV.size
    
    Y(ev)=sum(P(ev,EV.in(ev):EV.out(ev)-1));
end
end