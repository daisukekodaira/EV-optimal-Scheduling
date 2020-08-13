clc, clear, close all
addpath(genpath('./pso_base'));
addpath('../')
savepath;

global EV
global weight

% for i=10:10:100
%     filename=strcat(strcat('x_EV(',num2str(i)),').mat');
%     tic
%     EV.size=i;
%     weight=1.6*i;
%     main;
%     time=toc;
%     clustered=length(Group.in);
%     save(filename,'x','B_data','time','clustered')
% end

for i=300:100:1000
    filename=strcat(strcat('x_EV(',num2str(i)),').mat');
    tic
    EV.size=i;
    weight=1.6*i;
    main;
    time=toc;
    clustered=length(Group.in);
    save(filename,'x','B_data','time','clustered')
end

for i=2000:1000:10000
    filename=strcat(strcat('x_EV(',num2str(i)),').mat');
    tic
    EV.size=i;
    weight=1.6*i;
    main;
    time=toc;
    clustered=length(Group.in);
    save(filename,'x','B_data','time','clustered')
end



% bar(B_data)
% sum(sum(x.third-x.second))

% soc_violated=zeros(size(x.third));
% for i=1:EV.size
%     soc_violated(i,EV.in(i))=EV.soc(i);
%    for j=EV.in(i):EV.out(i)-1
%        soc_violated(i,j+1)=soc_violated(i,j)+x.third(i,j);
%    end
% end
%
% soc=zeros(size(x.second));
% for i=1:EV.size
%     soc(i,EV.in(i))=EV.soc(i);
%    for j=EV.in(i):EV.out(i)-1
%        soc(i,j+1)=soc(i,j)+x.second(i,j);
%    end
% end