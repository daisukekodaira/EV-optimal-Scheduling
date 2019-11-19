clc, clear, close all
addpath(genpath('./pso_base'));
addpath('../')
savepath;

global weight
global EV

%get path
for i=10:50:1000
    if (rem(i,100)==0)
        continue
    end
    filename=strcat(strcat('optimal_EV(',num2str(i)),').mat');
    tic
    EV.size=i;
    weight=1.6*i;
    main;
    time=toc;    
    save(filename,'qpx_sw','time','B_data');
end

% %get path
% for i=200:100:1000
%     filename=strcat(strcat('optimal_EV(',num2str(i)),').mat');
%     tic
%     EV.size=i;
%     weight=1.6*i;
%     main;
%     time=toc;
%     save(filename,'qpx_sw','time','B_data');
% end
% 
% % soc_violated=zeros(size(x.third));
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