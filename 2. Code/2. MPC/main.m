yalmip('clear')
clear all

% ----------------------------------------------------
% Status x(t): SoC [kwh] at time instance t
% Inputs u(t): Charging power [kw] at time instance t
% -----------------------------------------------------

% Model data
A = eye(2);
B = eye(2);
nx = 2; % Number of states
nu = 2; % Number of inputs

% MPC data
Q = 1; % coefficient for current state
R = 1;  % coefficient for current input
N = 7;  % control holizontal steps

% Set state variables
x = zeros(nx, 1); % initialize as all "0"
% Set input variables to be optimized for control hilontal steps  
u = sdpvar(repmat(nu,1,N),repmat(1,1,N));

% Initialization
constraints = []; 
objective = 0;  
% Constraints
xMax = 5;   % upper boundary for States
xMin = 0;   % lower boudanry for States
uMax = 1;   % upper boundary for Inputs
uMin = 0;   % lower boundary for Inputs

% Calculate Cost
for k = 1:N
     x = A*x + B*u{k};
    objective = objective + norm(Q*x,1) + norm(R*u{k},1);
    constraints = [constraints, uMin <= u{k}<= uMax, xMin<=x<=xMax];
end

% Get feasible solution
optimize(constraints,-objective);

%% Display the graph
% Calculate the state x(t) with optimized inputs u(t)
state = zeros(nx,N);
for k = 1:N
     state(:, k+1) = A*state(:, k) + B*value(u{k});
     input(:, k) = value(u{k});
end
% Describe
scaleXx = 0:N;
scaleXu = 0.5:1:N;
plot(scaleXx, state(1,:), 'b-o', ...  % States for EV1
       scaleXu, input(1,:), 'k-x', ...    % Inputs for EV1
       scaleXx, state(2,:), 'b-o', ...  % States for EV2
       scaleXu, input(2,:), 'b-x', ...    % Inputs for EV2
       scaleXx, uMax*ones(1, size(scaleXx,2)), 'k:', ...  % Upper boudanry of Inputs (power)
       scaleXx, xMax*ones(1, size(scaleXx,2)), 'b:', ...    % Upper boudanry of States (Soc)
       scaleXx, uMin*ones(1, size(scaleXx,2)), 'k:');  % Lower boudanry of Inputs (power)
title('Charging schedule');
xlabel('Time horizon [hour]');
ylabel('Soc [kwh]');
legend('EV1 SoC [kwh]', ...
           'EV1 charging [kw]', ...
           'EV2 SoC [kwh]', ...
           'EV2 charging [kw]', ...
           'Power limit [kw]', ...
           'Soc limit [kwh]');
axis([0 N+1 xMin-0.5 xMax+0.5]);



