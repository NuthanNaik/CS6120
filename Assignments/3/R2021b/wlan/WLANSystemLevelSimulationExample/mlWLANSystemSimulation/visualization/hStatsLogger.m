classdef hStatsLogger < handle
    % hStatsLogger Implements the logging and visualization of statistics
    %   
    %   This class implements the functionality to visualize statistics at
    %   the end of the simulation
    %
    %   hStatsLogger(param) Creates statistics logging and visualization
    %   object.
    %
    %   hStatsLogger methods:
    %   getStatistics - Returns the statistics of the simulation
    %
    %   hStatsLogger properties:
    %   NumNodes  - Number of nodes
    %   NodeNames - Node names
    %   Nodes     - Node objects

    %   Copyright 2021 The MathWorks, Inc.

    properties (Access = private)
        % Number of nodes
        NumNodes;

        % Node names
        NodeNames;

        % Node objects
        Nodes;
    end

    methods
        function obj = hStatsLogger(param)
            %hStatsLogger create an object to log the statistics captured at
            %application, MAC, and physical layers for all the nodes.
            %
            %   hStatsLogger(PARAM) is a constructor that initializes the class
            %   properties and creates an object to log the statistics captured at
            %   application, MAC, and physical layers for all the nodes.
            %
            %   PARAM is a structure with following fields
            %       Nodes                 - It is a vector of node objects.
            %       NodeNames (optional)  - It is a string array. Each
            %       element in the array represents the name given to a
            %       node. By default, node names are like Node1, Node2 ...
            %       NodeN.

            obj.NumNodes = numel(param.Nodes);
            if isfield(param, 'NodeNames')
                obj.NodeNames = param.NodeNames;
            else
                obj.NodeNames = cell(1, obj.NumNodes);
                for n = 1:obj.NumNodes
                    if ~isempty(param.Nodes{n}.NodeName)
                        obj.NodeNames{n} = param.Nodes{n}.NodeName;
                    else
                        obj.NodeNames{n} = ['Node', num2str(param.Nodes{n}.ID)];
                    end
                end
            end
            obj.Nodes = param.Nodes;
        end

        function statistics = getStatistics(obj, varargin)
            %getStatistics Returns the statistics of the simulation
            %
            %   [STATISTICS] = getStatistics(OBJ) Returns the statistics
            %
            %   STATISTICS is a cell array with 3 elements, where each element is a
            %   table containing statistics captured in a frequency. The first
            %   element corresponds to the lowest frequency and the last element
            %   corresponds to the highest frequency.
            %
            %   [STATISTICS] = getStatistics(OBJ, ENABLETABLEPOPUP)
            %   returns the statistics and specifies whether to pop up the figures
            %   or not for statistic tables.

            enableTablePopup = false;
            if numel(varargin) > 0
                enableTablePopup = varargin{1};
            end

            % Calculate the number of unique frequencies
            numNodes = obj.NumNodes;
            allFrequencies = cell(1, numNodes);
            for idx = 1:numNodes
                allFrequencies{idx} = obj.Nodes{idx}.Frequencies;
            end
            frequencies = unique([allFrequencies{:}]);
            numUniqueFreqs = numel(frequencies);

            % Initialize
            nodeNames = obj.NodeNames;
            statsLog = repmat(struct, numNodes, numUniqueFreqs);
            statistics = cell(1, numUniqueFreqs);

            for idx = 1:numNodes
                app = obj.Nodes{idx}.Application;
                mac = obj.Nodes{idx}.MAC;
                phyTx = obj.Nodes{idx}.PHYTx;
                phyRx = obj.Nodes{idx}.PHYRx;

                numInterfaces = numel(mac);
                for freqidx = 1:numInterfaces
                    % Get all modules metrics
                    phyRxMetrics = phyRx(freqidx).getMetricsList();
                    phyTxMetrics = phyTx(freqidx).getMetricsList();
                    macMetrics = mac(freqidx).getMetricsList();
                    appMetrics = app.getMetricsList();
                    operatingFreqID = mac(freqidx).OperatingFreqID;
                    macPerACStats = {'MACInternalCollisionsAC', 'MACBackoffAC', 'MACDataTxAC', 'MACAggTxAC', 'MACTxRetriesAC', ...
                        'MACDataRxAC', 'MACAggRxAC', 'MACMaxQueueLengthAC', 'MACDuplicateRxAC', 'MACThroughputAC'};
                    appPerACStats = {'AppTxAC', 'AppRxAC', 'AppAvgPacketLatencyAC'};

                    if (mac(freqidx).MACAverageTimePerFrame ~= 0)
                        mac(freqidx).MACAverageTimePerFrame = mac(freqidx).MACAverageTimePerFrame/(mac(freqidx).MACTxSuccess);
                    end

                    if any(app.AppRxAC(:, operatingFreqID) ~= 0)
                        app.AppAvgPacketLatency(operatingFreqID) = app.AppAvgPacketLatency(operatingFreqID)/sum(app.AppRxAC(:, operatingFreqID));
                        latencyPerAC = app.AppAvgPacketLatencyAC(:, operatingFreqID);
                        latencyPerAC = latencyPerAC./app.AppRxAC(:, operatingFreqID);
                        latencyPerAC(isnan(latencyPerAC)) = 0;
                        app.AppAvgPacketLatencyAC(:, operatingFreqID) = latencyPerAC;
                    end

                    % Log metrics
                    for statIdx = 1:numel(appMetrics)
                        statsLog(idx, operatingFreqID).ActiveOperationInFreq = 1;
                        if ismember(appMetrics{statIdx}, appPerACStats)
                            statsLog = updatePerACStats(obj, appMetrics{statIdx}, app.(appMetrics{statIdx})(:, operatingFreqID), statsLog, idx, operatingFreqID);
                        else
                            statsLog(idx, operatingFreqID).(appMetrics{statIdx}) = app.(appMetrics{statIdx})(operatingFreqID);
                        end
                    end
                    for statIdx = 1:numel(macMetrics)
                        if ismember(macMetrics{statIdx}, macPerACStats)
                            statsLog = updatePerACStats(obj, macMetrics{statIdx}, mac(freqidx).(macMetrics{statIdx}), statsLog, idx, operatingFreqID);
                        else
                            statsLog(idx, operatingFreqID).(macMetrics{statIdx}) = mac(freqidx).(macMetrics{statIdx});
                        end
                    end
                    if any(mac(freqidx).MACDataTxBytesAC ~= 0)
                        statsLog(idx, operatingFreqID).MACThroughput = (statsLog(idx, operatingFreqID).MACDataTxBytes*8)/getCurrentTime(obj.Nodes{idx}); % in Mbps
                        throughputPerAC = (mac(freqidx).MACDataTxBytesAC*8)/getCurrentTime(obj.Nodes{idx}); % in Mbps
                        statsLog = updatePerACStats(obj, 'MACThroughputAC', throughputPerAC, statsLog, idx, operatingFreqID);
                    end
                    statsLog(idx, operatingFreqID).PacketLossRatio = 0;
                    if statsLog(idx, operatingFreqID).MACDataTx > 0
                        statsLog(idx, operatingFreqID).PacketLossRatio = (statsLog(idx, operatingFreqID).MACDataTx - statsLog(idx, operatingFreqID).MACTxSuccess)/statsLog(idx, operatingFreqID).MACDataTx;
                    end
                    for statIdx = 1:numel(phyTxMetrics)
                        statsLog(idx, operatingFreqID).(phyTxMetrics{statIdx}) = phyTx(freqidx).(phyTxMetrics{statIdx});
                    end
                    for statIdx = 1:numel(phyRxMetrics)
                        statsLog(idx, operatingFreqID).(phyRxMetrics{statIdx}) = phyRx(freqidx).(phyRxMetrics{statIdx});
                    end
                end
            end

            % Set the empty fields of the structures in the statistics cell
            % array to value 0
            allMetrics = fieldnames(statsLog(1, 1));
            for i = 1:numNodes
                for j = 1:numUniqueFreqs
                    for k = 1:numel(allMetrics)
                        if isempty(statsLog(i, j).(allMetrics{k}))
                            statsLog(i, j).(allMetrics{k}) = 0;
                        end
                    end
                end
            end
            % Fill statistics
            for i=1:numUniqueFreqs
                statistics{i} = struct2table(statsLog(1:numNodes, i),'RowNames',nodeNames);
            end

            if enableTablePopup
                for idx = 1:numUniqueFreqs
                    tmp = table2array(statistics{idx});
                    statisticsTable = array2table(tmp');
                    statisticsTable.Properties.RowNames = statistics{idx}.Properties.VariableNames;
                    statisticsTable.Properties.VariableNames = statistics{idx}.Properties.RowNames;
                    activeNodes = find(statistics{idx}.ActiveOperationInFreq);
                    bandAndChannel = obj.Nodes{activeNodes(1)}.BandAndChannel;
                    disp(['Statistics table for band ', char(num2str(bandAndChannel{1}(1))), ' and channel number ', char(num2str(bandAndChannel{1}(2)))]);
                    statisticsTable %#ok<NOPRT>
                end
            end
        end
    end

    methods (Access = private)
        function statsLog = updatePerACStats(~, statStr, perACCounters, statsLog, nodeIdx, operatingFreqID)
            numACs = 4;
            for idx = 1:numACs
                switch idx
                    case 1
                        acStr = '_BE';
                    case 2
                        acStr = '_BK';
                    case 3
                        acStr = '_VI';
                    case 4
                        acStr = '_VO';
                end
                perACStr = [statStr, acStr];
                statsLog(nodeIdx, operatingFreqID).(perACStr) = perACCounters(idx);
            end
        end
    end
end