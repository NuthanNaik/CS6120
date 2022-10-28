function hPlotStateTransition(varargin)
%hPlotStateTransition Plots the simulation time-line statistics
%
%   This is an example helper function.
%
%   hPlotStateTransition(SETUPINFO) Create the visualization as per the
%   setup information specified in SETUPINFO
%
%   SETUPINFO is a structure with following fields
%       Nodes - Contains information about the nodes
%       NodeNames (optional) - This is an optional field, a string array.
%       When present, each element in the array represents the name given
%       to a node. By default, node names are like Node1, Node2 ... NodeN.
%   
%   hPlotStateTransition(NODEID, STATEINDEX, TIME, DURATION) plot the
%   simulation time-line statistics for the given inputs.
%
%   NODEID is a scalar value representing node ID if the node has one
%   interface. If the node has more than 1 frequency, this value must be a
%   vector of the form [nodeID, frequencyID].
%
%   STATEINDEX is the index of state. 1 indicates Contend, 2 indicates Tx,
%   3 indicates Rx
%
%   TIME is the state entry time-stamp corresponding to the given
%   STATEINDEX.
%
%   DURATION is the time spent in the state corresponds to the given
%   STATEINDEX.

%   Copyright 2021 The MathWorks, Inc.

persistent statsFig nodeNames freqInfo

% State colors
contendColor = [0.9, 0.7, 0.4];
txColor = [0.7, 0.9, 0.6];
idleEIFSColor = [1, 1, 1];
rxColorUs = [0.1098 0.4353 0.9216];
rxColorOthers = [0.7294 0.8510 0.9608];

% State indexes
contendIndex = 1;
txIndex = 2;
rxIndex = 3;
actualRxIndex = 5;
barHeight = 1;

if nargin > 1 % Plot the data
    
    % Return if the figure is closed in between simulation or not created
    if isempty(statsFig) || ~isvalid(statsFig)
        return;
    end
    
    nodeInfo = varargin{1};
    stateIndex = varargin{2};
    time = varargin{3};
    duration = varargin{4};
    
    % Select color based on state index
    if stateIndex == contendIndex
        fillColor = contendColor;
    elseif stateIndex == txIndex
        fillColor = txColor;
    elseif stateIndex == rxIndex
        fillColor = rxColorOthers;
    elseif stateIndex == actualRxIndex
        fillColor = rxColorUs;
    end
    
    nID = nodeInfo(1); % Node ID
    if length(nodeInfo) > 1
        freqID = nodeInfo(2); % Frequency id
        tickId = find(((freqInfo(:, 1) == nID) & (freqInfo(:, 3) == freqID)), 1);
    else
        tickId = nID;
    end
    interfaceYPosition = statsFig.CurrentAxes.YTick;
    % Update state transition
    rectangle(statsFig.CurrentAxes, 'Position', [time, interfaceYPosition(tickId)-barHeight/2, duration, barHeight], 'FaceColor', fillColor);
else % Setup the visualization
    
    visualizationInfo = varargin{1};

    % Get screen resolution
    resolution = get(0, 'screensize');
    screenWidth = resolution(3);
    screenHeight = resolution(4);
    figureWidth = screenWidth*0.7;
    figureHeight = screenHeight*0.7;
    % Create figure
    statsFig = figure('Name', 'MAC State Transitions Over Time', 'Tag', 'EDCANetwork', ...
        'Position', [screenWidth*0.1, screenHeight*0.05, figureWidth, figureHeight]);
    hold on;
        
    numNodes = numel(visualizationInfo.Nodes);
    if isfield(visualizationInfo, 'NodeNames')
        nodeNames = visualizationInfo.NodeNames;
    else
        % Default naming of node if node names are not supplied
        nodeNames = cell(numNodes, 1);
        for n = 1:numNodes
            if ~isempty(visualizationInfo.Nodes{n}.NodeName)
                nodeNames{n} = visualizationInfo.Nodes{n}.NodeName;
            else
                nodeNames{n} = ['Node', num2str(visualizationInfo.Nodes{n}.ID)];
            end
        end
    end
    
    numInterfaces = 3; % Max frequencies per node
    freqInfo = zeros(numNodes*numInterfaces, 3);
    count = 1;
    for idx=1:numNodes
        numFreq =  length(visualizationInfo.Nodes{idx}.Frequencies);
        freqInfo(count:count+numFreq-1, 1) = visualizationInfo.Nodes{idx}.ID; % Node ID
        freqInfo(count:count+numFreq-1, 2) = sort(visualizationInfo.Nodes{idx}.Frequencies)'; % Frequency
        count = count + numFreq;
    end
    count = count - 1;
    freqInfo = freqInfo(1:count, :);
    frequencyList = unique(freqInfo(:, 2));
    for idx=1:size(freqInfo, 1)
        freqInfo(idx, 3) = find(freqInfo(idx, 2) == frequencyList); % Frequency id
    end
    
    % Calculate the tick list and corresponding labels
    tickBase = 0;
    tickIdx = 1;
    yTicksList = zeros(count, 1);
    yTickLabels = cell(count, 1);
    for idx=1:numNodes
        numFreq = length(visualizationInfo.Nodes{idx}.Frequencies);
        mainIdx = floor((numFreq + 1) /2);
        for inIdx=1:numFreq
            tickBase = tickBase + barHeight * 1.25;
            yTicksList(tickIdx) = tickBase;
            
            if mainIdx == inIdx
                yTickLabels{tickIdx} = strcat('\bf{', nodeNames{idx}, '}', ' \rm{', num2str(freqInfo(tickIdx, 2)), " GHz}");
            else
                yTickLabels{tickIdx} = strcat(num2str(freqInfo(tickIdx, 2)), " GHz");
            end
            tickIdx = tickIdx + 1;
        end
        tickBase  = tickBase + barHeight;
    end
    
    % Set the tick labels
    ymax = max(yTicksList) + barHeight;
    ylim([0 ymax]);
    yticks(yTicksList);
    statsFig.CurrentAxes.YTickLabel = yTickLabels;
    
    % Create empty plots for annotation
    p(1) = bar(NaN, 'FaceColor', contendColor);
    p(2) = bar(NaN, 'FaceColor', txColor);
    p(3) = bar(NaN, 'FaceColor', rxColorOthers);
    p(4) = bar(NaN, 'FaceColor', idleEIFSColor);
    p(5) = bar(NaN, 'FaceColor', rxColorUs);
    
    % Add the legend and axis labels
    legend(p, {'Contention', 'Transmission', 'Reception(destined to others)', 'Idle/EIFS/SIFS', 'Reception(destined to node)'}, 'Location', 'northeastoutside');
    pan xon;
    xlabel('Node Timeline (Microseconds)', 'FontSize', 12);
    ylabel('Node Names', 'FontSize', 12);
    
    % Button to view MAC queue lengths plot
    uicontrol('Style','pushbutton', 'String','Observe MAC queue lengths', ...
        'Position', [20 20 155 27], 'Callback', {@plotQueueLengthsCallback, nodeNames});
end
end

function plotQueueLengthsCallback(~, ~, nodeNames)
    hPlotQueueLengths(true, nodeNames, 0, 0, 0);
end
