function hPlotQueueLengths(visibilityFlag, strings, nodeID, queueLen, time)
%hPlotQueueLengths Plots the queue lengths in the simulation
%
%   This is an example helper function.
%
%   hPlotQueueLengths(FLAG, STRINGS, NODEID, QUEUELEN, TIME) plots the
%   queue lengths in the simulation
%
%   VISIBILITYFLAG is specified as either true or false. The value true
%   makes the plot visible. This is configured only when the simulation is
%   in progress.
%
%   STRINGS is a cell array of the node names for which the queue lengths
%   will be plotted.
%
%   NODEID is the ID of the node for which the queue lengths are plotted.
%
%   QUEUELEN is the length of the queue at the current simulation time.
%
%   TIME is the current simulation time.

%   Copyright 2021 The MathWorks, Inc.

persistent queueLengthsFig userReqFlag bePlot bkPlot viPlot voPlot nodeSelector prevNode numNodes

if isempty(userReqFlag) || (~isempty(queueLengthsFig) && ~isvalid(queueLengthsFig))
    userReqFlag = false;
end

% User requested to plot MAC queue lengths
if ~userReqFlag && visibilityFlag
    userReqFlag = true;
end

% User is not interested in plotting MAC queue lengths
if ~userReqFlag
    return;
end

% Create a new figure for the first time or figure is closed in between the
% simulation
if (isempty(queueLengthsFig) || isempty([bePlot bkPlot viPlot voPlot])) || ~isvalid(queueLengthsFig)
    [bePlot, bkPlot, viPlot, voPlot ] = deal(cell(1, 1));
    
    % Get screen resolution
    resolution = get(0, 'screensize');
    screenWidth = resolution(3);
    screenHeight = resolution(4);
    figureWidth = screenWidth*0.7;
    figureHeight = screenHeight*0.7;
    % Create figure
    queueLengthsFig = figure('Name', 'MAC Queue Lengths', 'Tag', 'DCFNetwork', ...
        'Position', [screenWidth*0.1, screenHeight*0.05, figureWidth, figureHeight], ...
        'Resize', 'off');
    hold on;
    bkPlotColor = [0 0.45 0.74];
    bePlotColor = [0.85 0.32 0.1];
    viPlotColor = [0.93 0.7 0.13];
    voPlotColor = [0.5 0.18 0.56];
    numNodes = numel(strings);
    
    % Pre allocate buffers to store per AC plots for each node
    bkPlot = cell(numNodes, 1);
    bePlot = cell(numNodes, 1);
    viPlot = cell(numNodes, 1);
    voPlot = cell(numNodes, 1);
    for idx = 1:numNodes
        % Create plots for each access category
        bkPlot{idx} = plot(0, 0, 'Marker', '*', 'LineStyle', '-', 'LineWidth', 1, 'Visible', 'off', 'Color', bkPlotColor);
        bePlot{idx} = plot(0, 0, 'Marker', 'o', 'LineStyle', '-', 'LineWidth', 1, 'Visible', 'off', 'Color', bePlotColor);
        viPlot{idx} = plot(0, 0, 'Marker', 'diamond', 'LineStyle', '-', 'LineWidth', 1, 'Visible', 'off', 'Color', viPlotColor);
        voPlot{idx} = plot(0, 0, 'Marker', 'square', 'LineStyle', '-', 'LineWidth', 1, 'Visible', 'off', 'Color', voPlotColor);
    end
    
    p = uipanel(queueLengthsFig,'Position', [0.13 0.925 0.2 0.04], 'BorderType', 'none');
    
    % Create textbox
    annotation(p,'textbox', [0 0.93 0.077 0.03], 'String','Node Selector:',...
        'LineStyle','none', 'FitBoxToText','off');
    % Create drop down for node selection
    nodeSelector = uicontrol(p, 'Style','popupmenu','String', strings, ...
        'Position', [100 3 155 27], ...
        'Callback', @plotNodeQueueLengths);
    prevNode = nodeSelector.Value;
    bePlot{prevNode}.Visible = 'on';
    bkPlot{prevNode}.Visible = 'on';
    viPlot{prevNode}.Visible = 'on';
    voPlot{prevNode}.Visible = 'on';
    
    % Create empty plots and add legend
    bkEmptyPlot = plot(NaN, 'Marker', '*', 'LineStyle', '-', 'LineWidth', 1, 'Color', bkPlotColor);
    beEmptyPlot = plot(NaN, 'Marker', 'o', 'LineStyle', '-', 'LineWidth', 1, 'Color', bePlotColor);
    viEmptyPlot = plot(NaN, 'Marker', 'diamond', 'LineStyle', '-', 'LineWidth', 1, 'Color', viPlotColor);
    voEmptyPlot = plot(NaN, 'Marker', 'square', 'LineStyle', '-', 'LineWidth', 1, 'Color', voPlotColor);
    legend([bkEmptyPlot, beEmptyPlot, viEmptyPlot, voEmptyPlot], {'Background Traffic', 'Best Effort Traffic', 'Video Traffic', 'Voice Traffic'}, 'Location', 'northeastoutside');
    % Add X and Y labels
    xlabel('Node Timeline (Microseconds)', 'FontSize', 12);
    ylabel('Number of Frames in Queue (all Destinations)', 'FontSize', 12);
end

% Return if the figure is closed in between simulation
if ~isvalid(queueLengthsFig)
    return;
end

% Plot selected node queue lengths
plotNodeQueueLengths([], []);

    function plotNodeQueueLengths(~, ~)
        % New node is selected
        if (nodeSelector.Value ~= prevNode)
            % Hide previous node plots
            bePlot{prevNode}.Visible = 'off';
            bkPlot{prevNode}.Visible = 'off';
            viPlot{prevNode}.Visible = 'off';
            voPlot{prevNode}.Visible = 'off';
            
            % Display current node plots
            bePlot{nodeSelector.Value}.Visible = 'on';
            bkPlot{nodeSelector.Value}.Visible = 'on';
            viPlot{nodeSelector.Value}.Visible = 'on';
            voPlot{nodeSelector.Value}.Visible = 'on';
            
            % Update previous node
            prevNode = nodeSelector.Value;
        end
        
        if nodeID ~= 0
            % Update the node plot
            if bePlot{nodeID}.YData(end) ~= queueLen(1)
                bePlot{nodeID}.XData = [bePlot{nodeID}.XData time];
                bePlot{nodeID}.YData = [bePlot{nodeID}.YData queueLen(1)];
            end
            if bkPlot{nodeID}.YData(end) ~= queueLen(2)
                bkPlot{nodeID}.XData = [bkPlot{nodeID}.XData time];
                bkPlot{nodeID}.YData = [bkPlot{nodeID}.YData queueLen(2)];
            end
            if viPlot{nodeID}.YData(end) ~= queueLen(3)
                viPlot{nodeID}.XData = [viPlot{nodeID}.XData time];
                viPlot{nodeID}.YData = [viPlot{nodeID}.YData queueLen(3)];
            end
            if voPlot{nodeID}.YData(end) ~= queueLen(4)
                voPlot{nodeID}.XData = [voPlot{nodeID}.XData time];
                voPlot{nodeID}.YData = [voPlot{nodeID}.YData queueLen(4)];
            end
        end
    end
end
