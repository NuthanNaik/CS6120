rng(51,'combRecursive');             % Seed for random number generator
simulationTime = 1000;              % Simulation time in milliseconds
showLiveStateTransitionPlot = true; % Enable live state transition plot for all nodes
displayStatistics = true;           % Display statistics at the end of the simulation

% To access all of the helper files in this example, add the
% mlWLANSystemSimulation folder to the MATLAB path
addpath(genpath(fullfile(pwd,'mlWLANSystemSimulation')));

% Change this to increas number of nodes
numNodes = 2;
% Add X, Y, Z positions of each node
nodePositions = [10 0 0; 20 0 0]; % In meters


% Default configuration for all of the nodes
load('wlanNodeConfig.mat');
nodeConfig = repmat(wlanNodeConfig,1,numNodes);

% Configure the AP
nodeConfig(1).NodePosition = nodePositions(1,:);
nodeConfig(1).TxFormat = 'HE_SU';
nodeConfig(1).BandAndChannel = {[5 36]};
nodeConfig(1).Bandwidth = 20;                    % MHz
nodeConfig(1).MPDUAggregation = true;
nodeConfig(1).TxMCS = 2;
nodeConfig(1).NumTxChains = 1;
nodeConfig(1).DisableRTS = false; 
nodeConfig(1).DisableAck = false;

% Configure the STA
nodeConfig(2).NodePosition = nodePositions(2,:);
nodeConfig(2).TxFormat = 'HE_SU';
nodeConfig(2).BandAndChannel = {[5 36]};
nodeConfig(2).Bandwidth = 20;                    % MHz
nodeConfig(2).MPDUAggregation = true;
nodeConfig(2).TxMCS = 2;
nodeConfig(2).NumTxChains = 1;
nodeConfig(2).DisableRTS = false; 
nodeConfig(2).DisableAck = false;

% Load the application traffic configuration for WLAN nodes
load('wlanTrafficConfig.mat');

% Copy the default configuration for all of the nodes
trafficConfig = repmat(wlanTrafficConfig,1,numNodes);

% Configure downlink application traffic
trafficConfig(1).SourceNode = 1;        % AP node ID
trafficConfig(1).DestinationNode = 2;   % STA node ID
trafficConfig(1).DataRateKbps = 100000;
trafficConfig(1).PacketSize = 1500;     % In bytes
trafficConfig(1).AccessCategory = 0;    % Best Effort (0), Background (1), Video (2), and Voice (3)

% Configure uplink application traffic
trafficConfig(2).SourceNode = 2;        % STA node ID
trafficConfig(2).DestinationNode = 1;   % AP node ID
trafficConfig(2).DataRateKbps = 100000;
trafficConfig(2).PacketSize = 1500;     % In bytes
trafficConfig(2).AccessCategory = 0;    % Best Effort (0), Background (1), Video (2), and Voice (3)

% MACFrameAbstraction = true;
MACFrameAbstraction = false;
% PHYAbstractionType  = "TGax Evaluation Methodology Appendix 1";
PHYAbstractionType  = "None";

wlanNodes = hCreateWLANNodes(nodeConfig,trafficConfig,...
'MACFrameAbstraction',MACFrameAbstraction,...
'PHYAbstractionType',PHYAbstractionType);

% Initialize the visualization parameters
visualizationInfo = struct;
visualizationInfo.Nodes = wlanNodes;
visualizationInfo.NodeNames = {'AP','STA'};
statsLogger = hStatsLogger(visualizationInfo);

% Configure state transition visualization
if showLiveStateTransitionPlot
    hPlotStateTransition(visualizationInfo);
end

% Initialize the wireless network simulator
networkSimulator = hWirelessNetworkSimulator(wlanNodes);


scheduleEvent(networkSimulator,@() pause(0.001),[],0,5);

tt1=datetime;
run(networkSimulator,simulationTime);
tt2=datetime;


clear hPlotStateTransition;

statistics = getStatistics(statsLogger,displayStatistics);
save('statistics.mat','statistics');

hPlotNetworkStats(statistics,wlanNodes);

rmpath(genpath(fullfile(pwd,'mlWLANSystemSimulation')));

fprintf('Timetaken for simulation = %f seconds', diff(datenum([tt1;tt2]))*24*3600);