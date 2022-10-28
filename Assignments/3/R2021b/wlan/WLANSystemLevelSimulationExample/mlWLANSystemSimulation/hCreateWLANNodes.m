function wlanNodes = hCreateWLANNodes(nodeConfigs, trafficConfigs, varargin)
%hCreateWLANNodes Create WLAN nodes with the specified configurations
%
%   WLANNODES = hCreateWLANNodes(NODECONFIGS, TRAFFICCONFIGS) creates wlan
%   nodes with the specified node configurations, NODECONFIGS, and return
%   the created nodes.
%
%   WLANNODES is a cell array, where each element is an object of type
%   'hWLANNode'
%
%   NODECONFIGS is specified as a structure containing the following fields
%
%   NodePosition             - Position of node as a 3D vector
%   BandAndChannel           - Operating band and channel number
%   Frequency                - Operating frequency
%   Bandwidth                - Channel bandwidth
%   TxFormat                 - Physical layer frame format
%   MPDUAggregation          - Enable aggregation
%   DisableAck               - Disable acknowledgments
%   NumTxChains              - Number of space time streams
%   MaxSubframes             - Maximum number of A-MPDU subframes
%   TxMCS                    - Modulation and coding scheme
%   RTSThreshold             - Threshold for frame length below which RTS is not transmitted
%   MaxShortRetries          - Maximum retries for short frames
%   MaxLongRetries           - Maximum retries for long frames
%   Use6MbpsForControlFrames - Force 6 Mbps for control frames
%   BasicRates               - Non-HT rates supported by the network
%   EnableSROperation        - Enable spatial reuse operation
%   BSSColor                 - Basic service set (BSS) color identifier
%   OBSSPDThreshold          - OBSS PD threshold
%   TxPower                  - Transmission power in dB
%   TxGain                   - Transmission gain in dB
%   EDThreshold              - Energy detection threshold in dBm
%   RxGain                   - Receiver gain in dB
%   RxNoiseFigure            - Receiver noise figure
%   PHYAbstractionType       - PHY abstraction type
%   ReceiverRange            - Packet reception range of the receiving node
%   FreeSpacePathloss        - Flag to enable free space pathloss
%   DisableRTS               - Disable RTS transmission
%   CWMin                    - Minimum range of contention window for four ACs
%   CWMax                    - Maximum range of contention window for four ACs
%   AIFSSlots                - Arbitrary interframe slot values for four ACs
%   PowerControl             - Power control algorithm object
%   RateControl              - Rate control algorithm object
%
%   TRAFFICCONFIGS is a structure with the following fields:
%
%   SourceNode               - ID of the node generating the traffic
%   DestinationNode          - ID of the destination node for the traffic
%   PacketSize               - Size of the application packet in bytes
%   DataRateKbps             - Rate of application packet generation
%   AccessCategory           - Access category of the generated traffic
%
%   WLANNODES = hCreateWLANNodes(NODECONFIGS, TRAFFICCONFIGS, Name, Value)
%   creates wlan nodes with the specified property Name set to the
%   specified Value. You can specify additional name-value pair arguments
%   in any order as (Name1, Value1, ..., NameN, ValueN). When a name-value
%   pair is not specified, the default value of the arguments is used.
%
%   MACFRAMEABSTRACTION is a flag that represents whether the MAC layer
%   should generate and decode MAC frames or not. Set the value to false to
%   perform MAC frame generation/reception operations, otherwise set true.
%   The default value is true.
%
%   PHYABSTRACTIONTYPE represents the type of physical layer abstraction.
%   Set the value to "None" to perform physical layer waveform generation
%   and payload recovery operations, otherwise set one of the PHY
%   abstraction types "TGax Simulation Scenarios MAC Calibration" or "TGax
%   Evaluation Methodology Appendix 1" to run in abstracted mode (i.e no
%   waveform generation and decoding operations). The default value is set
%   to "TGax Evaluation Methodology Appendix 1"
%   NOTE: Setting MACFRAMEABSTRACTION to true and PHYABSTRACTIONTYPE to
%   'None' is an invalid combination as MAC frame generation/reception
%   operations are required for full physical layer processing.
%
%   CUSTOMPATHLOSS is a function handle holding the definition of path loss
%   algorithm

%   Copyright 2021 The MathWorks, Inc.

% Initialize PHY and MAC information
phyAndMACInfo = struct('MACFrameAbstraction', true, ...
    'PHYAbstractionType', 'TGax Evaluation Methodology Appendix 1', ...
    'CustomPathLoss', []);

phyAbstraction = true;

for arg = 1:2:nargin-3
    phyAndMACInfo.(varargin{arg}) = varargin{arg+1};
end

if strcmp(phyAndMACInfo.PHYAbstractionType, 'None')
    phyAbstraction = false;
end
validateAbstractionConfig(phyAndMACInfo);

% Suppress warnings we may expect during the simulation
suppressWarnings;

numNodes = numel(nodeConfigs);
% Initialize the cell array to store the WLAN nodes
wlanNodes = cell(1, numNodes);

% Validate configuration of each node
for nodeIdx = 1:numNodes
    config = nodeConfigs(nodeIdx);

    % Number of interfaces in the node
    numInterfaces = numel(config.BandAndChannel);
    for idx = 1:numInterfaces
        config.Frequency(idx) = ...
            hChannelToFrequency(config.BandAndChannel{idx}(2), config.BandAndChannel{idx}(1));
    end
    nodeConfigs(nodeIdx).Frequency = config.Frequency;

    % Handle configuration values when there are multiple interfaces
    config = handleMultiInterfaceConfigValues(config, numInterfaces);
    % Validate node configuration
    nodeConfigs(nodeIdx) = validateNodeConfig(config, numInterfaces);
end

isEvalMethod = arrayfun(@(x)strcmp(x.PHYAbstractionType,'TGax Evaluation Methodology Appendix 1'),phyAndMACInfo);
nodeFreqs = [nodeConfigs.Frequency];
uniqueFreqs = unique(nodeFreqs);

% TGax channel
if any(isEvalMethod)
    maxBandwidth = max([nodeConfigs.Bandwidth]);
    availableBWs = [20 40 80 160];
    availableCBWs = ["CBW20" "CBW40" "CBW80" "CBW160"];
    bwIdx = find(availableBWs>=maxBandwidth,1,'first');
    cbwToUse = availableCBWs(bwIdx);
    srToUse = availableBWs(bwIdx)*1e6;

    % Create a 2D vector of size N-by-M, where N is the number of nodes
    % and M specifies unique frequencies configured for all nodes.
    % Each element in the vector represents number of antennas.
    numAnts = nan(numNodes,numel(uniqueFreqs));
    for i = 1:numel(uniqueFreqs)
        for n = 1:numNodes
            activeFreq = nodeConfigs(n).Frequency==uniqueFreqs(i);
            if ~any(activeFreq)
                continue
            end
            numAnts(n,i) = nodeConfigs(n).NumTxChains(activeFreq);
        end
    end

    % Create a channel manager for each frequency
    for i = 1:numel(uniqueFreqs)
        fc = uniqueFreqs(i)*1e9; % Band (frequency) in GHz
        chan = wlanTGaxChannel('ChannelFiltering',false,'NumSamples',1, ...
          'SampleRate',srToUse,'ChannelBandwidth',cbwToUse,'CarrierFrequency',fc, ...
          'EnvironmentalSpeed',0, ...
          'TransmitReceiveDistance',15,'DelayProfile','Model-D');
        channelManager(i) = hTGaxChannelManager(chan,numAnts(:,i)); %#ok<AGROW>
    end
end

if phyAbstraction
    defaultPHYTxObj = hPHYTxAbstract;
    defaultPHYRxObj = hPHYRxAbstract;
else
    defaultPHYTxObj = hPHYTx;
    defaultPHYRxObj = hPHYRx;
end
% Create and configure each of the WLAN nodes
for nodeIdx = 1:numNodes
    config = nodeConfigs(nodeIdx);

    % Create the WLAN node
    node = hWLANNode('ID', nodeIdx, ...
        'Position', config.NodePosition, ...
        'NumberOfNodes', numNodes, ...
        'ReceiverRange', config.ReceiverRange, ...
        'PHYTx', defaultPHYTxObj, ...
        'PHYRx', defaultPHYRxObj);

    % Application layer
    app = hApplication(numNodes, 'NodeID', nodeIdx, ...
        'FillPayload', ~phyAndMACInfo.MACFrameAbstraction, 'MaxInterfaces', numel(uniqueFreqs)); % For abstracted MAC packets won't be generated
    node.Application = app;

    % MAC layer Tx queue capacity
    maxQueueLength = 256;

    % Number of interfaces in the node
    numInterfaces = numel(config.Frequency);

    for interfaceIdx = 1:numInterfaces
        % Configure the rate control algorithm at MAC
        if ~iscell(config.RateControl)
            rateControl = config.RateControl;
        else
            rateControl = config.RateControl{interfaceIdx};
        end
        if strcmp(rateControl, 'ARF')
            rateAlgorithm = hRateControlARF(numNodes, ...
                'TxFormat', hFrameFormats.(config.TxFormat), ...
                'NumTxChains', config.NumTxChains(interfaceIdx), ...
                'Bandwidth', config.Bandwidth(interfaceIdx));
        elseif strcmp(rateControl, 'FixedRate')
            rateAlgorithm = hRateControlFixed(numNodes, ...
                'FixedMCS', config.TxMCS(interfaceIdx), ...
                'TxFormat', hFrameFormats.(config.TxFormat), ...
                'NumTxChains', config.NumTxChains(interfaceIdx));
        else
            error(['Unknown rate control ' rateControl ...
                ' for node ' int2str(nodeIdx)]);
        end

        % Configure the power control algorithm at MAC
        if ~iscell(config.PowerControl)
            powerControl = config.PowerControl;
        else
            powerControl = config.PowerControl{interfaceIdx};
        end
        if strcmp(powerControl, 'FixedPower')
            powerControlAlgorithm = hPowerControlFixed('FixedPower', config.TxPower(interfaceIdx));
        else
            error(['Unknown power control algorithm ' powerControl ...
                ' for node ' int2str(nodeIdx)]);
        end

        % MAC layer
        mac = hEDCAMAC(numNodes, maxQueueLength, config.MaxSubframes, ...
            'NodeID', nodeIdx, ...
            'Bandwidth', config.Bandwidth(interfaceIdx), ...
            'TxFormat', hFrameFormats.(config.TxFormat), ...
            'MPDUAggregation', config.MPDUAggregation, ...
            'DisableAck', config.DisableAck, ...
            'CWMin', config.CWMin, ...
            'CWMax', config.CWMax, ...
            'AIFSSlots', config.AIFSSlots, ...
            'NumTxChains', config.NumTxChains(interfaceIdx), ...
            'DisableRTS', config.DisableRTS(interfaceIdx),...
            'RTSThreshold', config.RTSThreshold,...
            'MaxShortRetries', config.MaxShortRetries, ...
            'MaxLongRetries', config.MaxLongRetries, ...
            'Use6MbpsForControlFrames', config.Use6MbpsForControlFrames, ...
            'BasicRates', config.BasicRates, ...
            'RateControl', rateAlgorithm, ...
            'PowerControl', powerControlAlgorithm, ...
            'FrameAbstraction', phyAndMACInfo.MACFrameAbstraction);

        % Validate MAC configuration
        validateConfig(mac);

        if phyAbstraction
            % Physical layer transmitter
            phyTx = hPHYTxAbstract('NodeID', nodeIdx, ...
                'NodePosition', config.NodePosition, ...
                'TxGain', config.TxGain, ...
                'MaxSubframes', config.MaxSubframes);

            % Physical layer receiver
            if strcmp(phyAndMACInfo.PHYAbstractionType,'TGax Evaluation Methodology Appendix 1')
                chanIdx = (config.Frequency(interfaceIdx) == uniqueFreqs);
                lq = hTGaxLinkQualityModel(channelManager(chanIdx));
                lq.NoiseFigure = config.RxNoiseFigure;
                % Subsample subcarriers to speed up the simulation. 1 is no
                % subsampling. 4 uses every 4th subcarrier etc.
                lq.SubcarrierSubsampling = 4;
            else
                % No link quality model required
                lq = [];
            end
            phyRx = hPHYRxAbstract('NodeID', nodeIdx, ...
                'NumberOfNodes', numNodes, ...
                'EDThreshold', config.EDThreshold, ...
                'RxGain', config.RxGain, ...
                'AbstractionType', phyAndMACInfo.PHYAbstractionType, ...
                'LinkQuality', lq, ...
                'MaxSubframes', config.MaxSubframes, ...
                'ChannelBandwidth', config.Bandwidth(interfaceIdx));
        else
            % Physical layer transmitter
            phyTx = hPHYTx('NodeID', nodeIdx, ...
                'NodePosition', config.NodePosition, ...
                'TxGain', config.TxGain, ...
                'MaxSubframes', config.MaxSubframes);

            % Physical layer receiver
            phyRx = hPHYRx('NodeID', nodeIdx, ...
                'NumberOfNodes', numNodes, ...
                'EDThreshold', config.EDThreshold, ...
                'RxGain', config.RxGain, ...
                'RxNoiseFigure', config.RxNoiseFigure, ...
                'MaxSubframes', config.MaxSubframes, ...
                'ChannelBandwidth', config.Bandwidth(interfaceIdx));
        end

        % Channel
        if ~isempty(phyAndMACInfo.CustomPathLoss)
            % Function handle to custom pathloss model provided
            tgaxIndoorPLFn = phyAndMACInfo.CustomPathLoss;
            channel = hChannel('ReceiverID', nodeIdx, 'ReceiverPosition', config.NodePosition, ...
                'ApplyCustomPathlossModel', true, 'PathlossFn', tgaxIndoorPLFn, 'Abstracted', phyAbstraction);
        else
            % Use node specified pathloss model
            channel = hChannel('ReceiverID',nodeIdx, 'ReceiverPosition', config.NodePosition, ...
                'ApplyFreeSpacePathloss', config.FreeSpacePathloss, 'Abstracted', phyAbstraction);
        end
        freqID = find(config.Frequency(interfaceIdx) == uniqueFreqs);
        addInterface(node, freqID, config.Frequency(interfaceIdx), config.BandAndChannel{interfaceIdx}, ...
            mac, phyTx, phyRx, channel);
    end

    % Initialize the WLAN node and include it in the output list
    init(node);
    wlanNodes{nodeIdx} = node;
end

% Install the configured applications at each node
installApplications(wlanNodes, trafficConfigs);

end

function installApplications(wlanNodes, trafficConfigs)
%installApplications Install the configured applications on each node
%
%   installApplications(WLANNODES, TRAFFICCONFIGS) adds the configured
%   applications specified by TRAFFICCONFIGS onto each node.
%
%   WLANNODES is a cell array containing objects of type hWLANNode.
%
%   TRAFFICCONFIGS is a cell array containing structures of type
%   wlanTrafficConfig specifying the application traffic configuration.

% Number of nodes
numNodes = numel(wlanNodes);

% Configure application traffic on the nodes
for nodeIdx = 1:numNodes
    nodeId = wlanNodes{nodeIdx}.ID;
    appConfigIdxList = find(nodeId == [trafficConfigs(:).SourceNode]);
    for appIdx = 1:numel(appConfigIdxList)
        appCfg = trafficConfigs(appConfigIdxList(appIdx));
        if (appCfg.DestinationNode > numNodes) && (appCfg.DestinationNode ~= 65535)
            disp(['Not installing application on node ' num2str(nodeId) ...
                ' with invalid destination node ' num2str(appCfg.DestinationNode)])
            continue;
        end

        % Install an application on the node
        app = networkTrafficOnOff('PacketSize', appCfg.PacketSize, 'DataRate', appCfg.DataRateKbps, 'OnTime', inf);
        addApplication(wlanNodes{nodeIdx}.Application, app, appCfg);
    end
end

end

function config = validateNodeConfig(config, numInterfaces)
% Validate the node configuration

    % Validate TxFormat
    if ~(ismember(config.TxFormat, ["NonHT", "HTMixed", "VHT", "HE_SU", "HE_EXT_SU"]))
        error('TxFormat must be set to one of "NonHT", "HTMixed", "VHT", "HE_SU", or "HE_EXT_SU"');
    end
    % Validate NodePosition
    if ~isnumeric(config.NodePosition) || (numel(config.NodePosition) ~= 3)
        error('NodePosition must be a vector of [x,y,z] format, in units of meters');
    end
    % Validate MPDUAggregation
    if ~islogical(config.MPDUAggregation) && ~(isnumeric(config.MPDUAggregation) && any(config.MPDUAggregation == [0, 1]))
        error('MPDUAggregation must be a logical value');
    end
    % Validate DisableAck
    if ~islogical(config.DisableAck) && ~(isnumeric(config.DisableAck) && any(config.DisableAck == [0, 1]))
        error('DisableAck must be a logical value');
    end
    % Validate MaxSubframes
    if (config.MaxSubframes < 1) || (config.MaxSubframes > 256)
        error('MaxSubframes must be a value in the range [1,256]');
    end
    % Validate RTSThreshold
    if (config.RTSThreshold < 0) || (config.RTSThreshold > 65536)
        error('RTSThreshold must be a value in the range [0,65536]');
    end
    % Validate DisableRTS
    if ~islogical(config.DisableRTS) && ~(isnumeric(config.DisableRTS) && any(config.DisableRTS == [0, 1]))
        error('DisableRTS must be a logical value');
    end
    % Validate MaxShortRetries
    if (config.MaxShortRetries < 1) || (config.MaxShortRetries > 255)
        error('MaxShortRetries must be a value in the range [1,255]');
    end
    % Validate MaxLongRetries
    if (config.MaxLongRetries < 1) || (config.MaxLongRetries > 255)
        error('MaxLongRetries must be a value in the range [1,255]');
    end
    % Validate BasicRates
    if ~(all(ismember(config.BasicRates, [6 9 12 18 24 36 48 54])))
        error('BasicRates must be a vector containing values from the set [6 9 12 18 24 36 48 54]');
    end
    % Validate Use6MbpsForControlFrames
    if ~islogical(config.Use6MbpsForControlFrames) && ~(isnumeric(config.Use6MbpsForControlFrames) && any(config.Use6MbpsForControlFrames == [0, 1]))
        error('Use6MbpsForControlFrames must be a logical value');
    end
    % Validate BandAndChannel
    if ~iscell(config.BandAndChannel)
        error('BandAndChannel must be a cell array with each element containing row vectors of size 2');
    end
    % Validate CWMin
    if (numel(config.CWMin) ~= 4) || any(config.CWMin < 1) || any(config.CWMin > 1023)
        error('CWMin must be a row vector of size 4, with each element in the range [1,1023]');
    end
    % Validate CWMax
    if (numel(config.CWMax) ~= 4) || any(config.CWMax < 1) || any(config.CWMax > 1023)
        error('CWMax must be a row vector of size 4, with each element in the range [1,1023]');
    end
    % Validate AIFSSlots
    if (numel(config.AIFSSlots) ~= 4) || any(config.AIFSSlots < 2) || any(config.AIFSSlots > 15)
        error('AIFSSlots must be a row vector of size 4, with each element in the range [2,15]');
    end
    % Validate RateControl
    if ~(ismember(config.RateControl, ["ARF", "FixedRate"]))
        error('RateControl must be one of "ARF" or "FixedRate"');
    end
    % Validate PowerControl
    if ~(ismember(config.PowerControl, "FixedPower"))
        error('PowerControl must be "FixedPower"');
    end
    % Validate FreeSpacePathloss
    if ~islogical(config.FreeSpacePathloss) && ~(isnumeric(config.FreeSpacePathloss) && any(config.FreeSpacePathloss == [0, 1]))
        error('FreeSpacePathloss must be a logical value');
    end

    for interfaceIdx = 1:numInterfaces
        % Validate Bandwidth
        if ~any(config.Bandwidth(interfaceIdx) == [20, 40, 80, 160])
            error('Bandwidth must be one of 20, 40, 80, or 160');
        end
        band = config.BandAndChannel{interfaceIdx}(1);
        switch config.TxFormat
            case {"HE_EXT_SU" "NonHT"}
                if (config.Bandwidth(interfaceIdx) ~= 20)
                    error('hCreateWLANNodes:UnsupportedBandwidth','For HE-EXT-SU format and Non-HT format bandwidth must be 20');
                end
            case "VHT"
                if (band == 2.4) && any(config.Bandwidth(interfaceIdx) == [80, 160])
                    error('hCreateWLANNodes:UnsupportedBandwidth','For VHT format bandwidth must be 20 or 40 when operating in 2.4 GHz band');
                end
            case "HTMixed"
                if all(config.Bandwidth(interfaceIdx) ~= [20 40])
                    error('hCreateWLANNodes:UnsupportedBandwidth','For HT-MF format bandwidth must be 20 or 40');
                end
        end

        % Validate BandAndChannel
        if (numel(config.BandAndChannel{interfaceIdx}) ~= 2)
            error('BandAndChannel must be a cell array with each element containing row vectors of size 2');
        end

        if ~iscell(config.RateControl)
            rateControl = config.RateControl;
        else
            rateControl = config.RateControl{interfaceIdx};
        end

        % Validate MCS on TxFormat if it is fixed rate
        if strcmp(rateControl, 'FixedRate')
            switch config.TxFormat
                case {"HE_SU", "HE_MU"}
                    if (config.TxMCS(interfaceIdx) > 11)
                        error('hCreateWLANNodes:UnsupportedMCSvalue',...
                            'For HE format MCS value must not be greater than 11');
                    end
                case "HE_EXT_SU"
                    if (config.TxMCS(interfaceIdx) > 2)
                        error('hCreateWLANNodes:UnsupportedMCSvalue',...
                            'For HE-EXT-SU format MCS value must not be greater than 2');
                    end
                case "VHT"
                    if (config.TxMCS(interfaceIdx) > 9)
                        error('hCreateWLANNodes:UnsupportedMCSvalue',...
                            'For VHT format, MCS value must not be greater than 9');
                    end
                    switch config.Bandwidth(interfaceIdx)
                        case 20
                            if (config.TxMCS(interfaceIdx) == 9) && ~any(config.NumTxChains(interfaceIdx) == [3 6])
                                error('hCreateWLANNodes:UnsupportedMCSvalue',...
                                    'For VHT format at bandwidth 20, MCS value 9 is only allowed for number of transmit chains 3 or 6');
                            end
                        case 80
                            if (config.TxMCS(interfaceIdx) == 6) && any(config.NumTxChains(interfaceIdx) == [3 7])
                                error('hCreateWLANNodes:UnsupportedMCSvalue',...
                                    'For VHT format at bandwidth 80, MCS value 6 is not allowed for number of transmit chains 3 or 7');
                            end

                            if (config.TxMCS(interfaceIdx) == 9) && config.NumTxChains(interfaceIdx) == 6
                                error('hCreateWLANNodes:UnsupportedMCSvalue',...
                                    'For VHT format at bandwidth 80, MCS value 9 is not allowed for number of transmit chains 6');
                            end
                        case 160
                            if (config.TxMCS(interfaceIdx) == 9) && config.NumTxChains(interfaceIdx) == 3
                                error('hCreateWLANNodes:UnsupportedMCSvalue',...
                                    'For VHT format at bandwidth 160, MCS value 9 is not allowed for number of transmit chains 3');
                            end
                    end
                case "HTMixed"
                    % Validate NumTxChains
                    if (config.NumTxChains(interfaceIdx) > 4)
                        error('hCreateWLANNodes:UnsupportedNumTxChains',...
                            'For HT format, number of transmit chains must not be greater than 4');
                    end
                    % Validate given MCS
                    if (config.TxMCS(interfaceIdx) > 7)
                        error('hCreateWLANNodes:UnsupportedMCSvalue',...
                            'For HT format, allowed MCS values are [0-7]. MCS values greater than 7 will be auto-calculated based on NumTxChains value.');
                    end
                    % Interpret MCS value from NumTxChains and given MCS value in HT format
                    config.TxMCS(interfaceIdx) = ((config.NumTxChains(interfaceIdx) - 1) * 8) + ...
                        config.TxMCS(interfaceIdx);
                case "NonHT"
                    if (config.TxMCS(interfaceIdx) > 7)
                        error('hCreateWLANNodes:UnsupportedMCSvalue',...
                            'For Non-HT format, MCS value must not be greater than 7');
                    end
            end
        end
    end
end

function config = handleMultiInterfaceConfigValues(config, numInterfaces)
% If a node has multiple interfaces and a single value is given for any of
% these configuration parameters (TxMCS, NumTxChains, TxPower, Bandwidth,
% and DisableRTS), then use the same value for all interfaces.

    % TxMCS
    if numel(config.TxMCS) ~= numInterfaces && isscalar(config.TxMCS)
        config.TxMCS = repmat(config.TxMCS, 1, numInterfaces);
    end

    % NumTxChains
    if numel(config.NumTxChains) ~= numInterfaces && isscalar(config.NumTxChains)
        config.NumTxChains = repmat(config.NumTxChains, 1, numInterfaces);
    end

    % TxPower
    if numel(config.TxPower) ~= numInterfaces && isscalar(config.TxPower)
        config.TxPower = repmat(config.TxPower, 1, numInterfaces);
    end

    % Bandwidth
    if numel(config.Bandwidth) ~= numInterfaces && isscalar(config.Bandwidth)
        config.Bandwidth = repmat(config.Bandwidth, 1, numInterfaces);
    end

    % DisableRTS
    if numel(config.DisableRTS) ~= numInterfaces && isscalar(config.DisableRTS)
        config.DisableRTS = repmat(config.DisableRTS, 1, numInterfaces);
    end
end

function validateAbstractionConfig(phyAndMACInfo)
% Validate MAC and PHY abstraction configurations

    if ~islogical(phyAndMACInfo.MACFrameAbstraction) && ~(isnumeric(phyAndMACInfo.MACFrameAbstraction) && ...
            any(phyAndMACInfo.MACFrameAbstraction == [0, 1]))
        error('MACFrameAbstraction must be a logical value')
    end

    % Validate PHY and MAC module info
    if isnumeric(phyAndMACInfo.PHYAbstractionType) || ...
            ~(ismember(phyAndMACInfo.PHYAbstractionType, ["TGax Simulation Scenarios MAC Calibration" "TGax Evaluation Methodology Appendix 1" "None"]))
        error('PHYAbstractionType must be one of "TGax Simulation Scenarios MAC Calibration", "TGax Evaluation Methodology Appendix 1", or "None"');
    end

    if strcmp(phyAndMACInfo.PHYAbstractionType, 'None') && phyAndMACInfo.MACFrameAbstraction
        error('Full physical layer requires frame generation and decoding operations at MAC. Set the value of "MacFrameAbstraction" to false to run the simulation')
    end
end

function suppressWarnings
% Suppress warnings we may expect during the simulation

    warningsToSuppress = [
        "wlan:wlanPSDULength:TxTimeRoundedToNextBoundary", ...
        "wlan:wlanMPDUDecode:UnsupportedBAVariant", ...
        "wlan:wlanMPDUDecode:NotEnoughDataToParseField", ...
        "wlan:wlanMPDUDecode:MaxAMSDULengthExceeded", ...
        "wlan:wlanMPDUDecode:NotEnoughDataToParseFrame", ...
        "wlan:wlanMPDUDecode:MalformedSupportedRatesIE", ...
        "wlan:wlanMPDUDecode:MalformedIELength", ...
        "wlan:wlanMPDUDecode:UnsupportedFrameType", ...
        "wlan:wlanMPDUDecode:UnsupportedFrameSubtype", ...
        "wlan:wlanMPDUDecode:UnknownRateReceived", ...
        "wlan:wlanMPDUDecode:NotEnoughDataToParseMPDU", ...
        "wlan:wlanFormatDetect:LSIGCheckFail", ...
        "wlan:trackingOFDMDemodulate:NotEnoughSamples", ...
        "wlan:wlanPSDULength:NSYMRoundedToNextSymbol"];

    arrayfun(@(x)warning('off',x),warningsToSuppress);
end
