% n = 2; % the number of state variables (SOC on each EV = the number of EV(charger))
% m = 2; % the number of input variables (power for each EV charging = the number of EV)
% Hp = 3; % prediction horizon
% Hc = 2; % control horizon
% k = 3;  % current time step 
% 
clear all; clc; close all;
%% Deifne system structure
A = [1 1; 1 1]; % size = n*n
B = [1 1; 1 1]; % size = n*m
C = [1 1; 1 1]; % C = I 
D = [0];
sys = ss(A, B, C, D);  % IDsys = idss(A, B, C, D);

%% Specify the system Input/output
sys.InputName = {'PowerForEV1', 'PowerForEV2'};
sys.OutputName = {'SoCEV1', 'SoCEV2'};
sys.StateName = {'SoCEV1', 'SoCEV2'};
% The number of variables
sys.InputGroup.MV = 2;  % Manipulated Variables; 1 [power] 
% sys.InputGroup.UD = 0;  % Unmeasured disturbances;
sys.OutputGroup.MO = 2; % Measured outputs
% sys.OutputGroup.UO = 0; % Unmeasured outputs

% Suppress Command Window messages from the MPC controller.
old_status = mpcverbosity('off');

% Create Model Predictive Controller
Ts = 1; % control interval
MPCobj = mpc(sys,Ts);
get(MPCobj)

% Adjust horizon
MPCobj.PredictionHorizon = 15;
% Adjust Units
MPCobj.Model.Plant.OutputUnit = {'[kwh]','[kwh]'};

% constraints for manipulated values
MPCobj.MV.Min = [1; 1];  % power 
MPCobj.MV.Max = [2; 2]; % power
MPCobj.MV.RateMin = [0.1; 0.1]; %
MPCobj.MV.RateMax = [1; 1];

% Perform Simulation
T = 26;
r = [0 ; 100];
sim(MPCobj,T,r)
