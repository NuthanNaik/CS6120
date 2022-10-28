classdef hWLANNode < comm_sysmod.internal.wirelessNode
%hWLANNode Create an object for WLAN node
%   WLANNODE = hWLANNode creates an object for WLAN node having
%   application, MAC and physical layers. This node also has a channel and
%   interference modeling. The node can also have multiple interfaces, each
%   with its own MAC, PHY, and Channel. The interfaces can be added using
%   addInterface method.
%
%   WLANNODE = hWLANNode(Name, Value) creates an object for WLAN node
%   with the specified property Name set to the specified Value. You can
%   specify additional name-value pair arguments in any order as (Name1,
%   Value1, ..., NameN, ValueN).
%
%   hWLANNode methods:
%
%   init            - Initialize the node parameters
%   runNode         - Run the node
%   pushChannelData - Push data from shared channel into Rx buffer
%   addInterface    - Add interface to the node
%
%   hWLANNode properties:
%
%   NumberOfNodes    - Number of nodes in the simulation
%   ReceiverRange    - Packet reception range of the receiving node
%   IsMeshEnabled    - Node is mesh enabled and may generate 4-address MAC frame

%   Copyright 2021 The MathWorks, Inc.

properties
    %NumberOfNodes Number of nodes in the simulation
    %   Used to preallocate resources such as receive buffers. Specify this
    %   property as an integer. This indicates the total number of nodes
    %   operating in the network simulation.
    NumberOfNodes = 10;

    %ReceiverRange Packet reception range of the receiving node
    %   Specify this property as an integer in meters. Can be used to
    %   reduce the processing complexity of simulation
    ReceiverRange = 10000;

    %IsMeshEnabled Node is mesh enabled and may generate 4-address MAC frame
    %   If this flag is set, MAC will check mesh routing and if required
    %   will use 4-address header for transmitting data. Otherwise, will
    %   use 3-address header.
    IsMeshEnabled = false;
end

properties (Hidden, Access = public)
    %Application WLAN application layer object
    %   Specify this property as an object of type <a
    %   href="matlab:help('hApplication')">hApplication</a>. This object
    %   contains methods and properties related to application layer.
    Application;

    %MAC WLAN MAC layer object
    %   This property is a vector of objects of type <a
    %   href="matlab:help('hEDCAMAC')">hEDCAMAC</a>. This object
    %   contains methods and properties related to WLAN MAC layer. This is
    %   a scalar when the node type is 'Single'. Otherwise, this property
    %   is specifies as a vector of objects.
    MAC;

    %PHYTx WLAN physical layer transmitter object
    %   This property is a vector of abstracted PHY objects <a
    %   href="matlab:help('hPHYTxAbstract')">hPHYTxAbstract</a> or full PHY
    %   objects href="matlab:help('hPHYTx')">hPHYTx</a>. This object
    %   contains methods and properties related to WLAN PHY transmitter.
    %   This is a scalar when the node type is 'Single'. Otherwise, this
    %   property is specified as a vector of objects.
    PHYTx;

    %PHYRx WLAN physical layer receiver object
    %   This property is a vector of abstracted PHY objects <a
    %   href="matlab:help('hPHYRxAbstract')">hPHYRxAbstract</a> or full PHY
    %   objects href="matlab:help('hPHYRx')">hPHYRx</a>. This object
    %   contains methods and properties related to WLAN PHY receiver. This
    %   is a scalar when the node type is 'Single'. Otherwise, this
    %   property is specifies as a vector of objects.
    PHYRx;

    %Channel WLAN channel model object
    %   This property is a vector of object of type <a
    %   href="matlab:help('hChannel')">hChannel</a>. This object
    %   contains methods and properties related to WLAN channel model. This
    %   is a scalar when the node type is 'Single'. Otherwise, this
    %   property is specifies as a vector of objects with each object
    %   corresponding to a separate network interface in the node
    Channel;

    %Frequencies Operating frequencies of the node in different interfaces
    %   This property is a vector of numeric values. Each value specifies
    %   the operating frequency of the node in GHz. Each value is
    %   associated with specific interface of the node.
    Frequencies;

    %BandAndChannel Operating band and channel numbers of the node in
    %different interfaces
    %   This property is a cell array of numeric values. Each cell
    %   represents the operating band and channel number of each interface.
    BandAndChannel;

    %PacketLatency Packet latency of each application packet received
    %   This property is a vector of numeric values. Each
    %   value specifies the latency computed for every packet received in
    %   microseconds.
    PacketLatency = 0;

    %PacketLatencyIdx Current index of the packet latency vector
    %   This property is a numeric value. This property specifies current
    %   index of the packet latency vector.
    PacketLatencyIdx = 0;
end

properties (Constant, Hidden)
    %MaxUsers Maximum number of users a node can support in downlink MU
    MaxUsers = 9;
end

properties (SetAccess = private)
    %RxBuffer Rx buffer contains the received signals to be processed
    RxBuffer;

    %RxBufferIdx Index used to identify the current position of the Rx
    %buffer
    RxBufferIdx = 0;

    %CurrentTime Current simulation time
    CurrentTime = 0;

    %TxBuffer Buffer contains the data to be transmitted from the node
    TxBuffer;

    %NumInterfaces Number of network interfaces in the node
    NumInterfaces = 0;
end

properties (Access = private)
    %Metadata Structure containing the PHY metadata
    Metadata;

    %WLANSignal Structure containing the PHY metadata and MAC metadata
    WLANSignal;

    %MACFrameCFG Structure containing the MAC metadata
    MACFrameCFG;

    %Vector Structure containing the Tx/Rx vector parameters
    Vector;
end

% Mesh properties
properties
    % Specify the address of the next hop for each destination node in the
    % network. It is specified as nX4 cell array, where n represents the
    % number of rows. Each row corresponds to a specific node in the
    % network. First column specifies the destination node ID, second
    % column specifies the destination node address, third column specifies
    % the address of the next hop and fourth column specifies the interface
    % ID on which packet needs to be forwarded.
    ForwardTable = {0 0 0 0};
    TableLen = 0;
end

properties (Constant)
    MACQueuePacket = struct('MSDULength', 0, ...
        'AC', 0, ... % Access category range [0 3]. Add 1 for indexing.
        'NextHopID', 0, ... % Immediate destination node ID
        'NextHopAddress', '000000000000', ... % MAC Frame RA. Corresponds to immediate destination node address
        'SourceAddress', '000000000000', ... % Original packet source
        'DestinationID', 0, ... % Final destination ID
        'DestinationAddress', '000000000000', ... % Final destination
        'Timestamp', 0, ... % Packet generation time stamp at origin
        'MeshSequenceNumber', 0, ... % Mesh sequence number
        'Data', zeros(2304, 1, 'uint8'));

    %MaxSequenceNumber mesh sequence number is a 4-byte value. The
    %maximum value is 2^32-1.
    MaxSequenceNumber = 2^32-1;
end

properties (Access = private)
    %MeshSequenceCounter Sequence counter per each source address.
    %First column represents the source address and the second column
    %represents the counter value. The counter gets updated for each
    %new packet transmission from the corresponding source address.
    MeshSequenceCounter = cell(1, 2);

    %EmptyDt Default value for list of next invoke times
    EmptyDt = zeros(1, 0);
end

properties (SetAccess = private)
    %RxDuplicatePackets Number of duplicate packets received
    RxDuplicatePackets = cell(1, 2);

    %PacketCache Packet cache used to detect the duplicate packets
    % This is a cell array. Each element specifies the original source
    % address and previously received mesh sequence number.
    PacketCache = cell(1, 2);
end

methods
    % Constructor
    function obj = hWLANNode(varargin)
        % Initialize with defaults, in case user doesn't configure
        obj.Application = hApplication(obj.NumberOfNodes);
        obj.MAC = hEDCAMAC(obj.NumberOfNodes, 256, 64);
        obj.Channel = hChannel;
        obj.Frequencies = zeros(1, 0);
        obj.PHYTx = hPHYTxAbstract;
        obj.PHYRx = hPHYRxAbstract;

        % Name-value pairs
        for idx = 1:2:nargin-1
            obj.(varargin{idx}) = varargin{idx+1};
        end
    end

    % Auto-completion
    function v = set(obj, prop)
        v = obj.([prop, 'Values']);
    end

    function set.NumberOfNodes(obj, value)
        validateattributes(value, {'numeric'}, {'scalar', 'positive', ...
            'integer'}, mfilename, 'NumberOfNodes');
        obj.NumberOfNodes = value;
    end

    function set.Application(obj, value)
        validateattributes(value, {'hApplication'}, {'scalar'}, ...
            mfilename, 'Application');
        obj.Application = value;
    end

    function init(obj)
        maxSubframes = obj.MAC(1).MaxSubframes;
        obj.Vector = struct('IsEmpty', true, 'EnableSROperation', false, 'BSSColor', 0, 'LimitTxPower',false,...
            'OBSSPDThreshold', 0, 'NumTransmitAntennas', 1, 'NumSpaceTimeStreams', 0, 'FrameFormat', 0, 'AggregatedMPDU', false, ...
            'ChannelBandwidth', 0, 'MCSIndex', zeros(obj.MaxUsers, 1), 'PSDULength', zeros(obj.MaxUsers, 1), ...
            'RSSI', 0, 'MessageType', 0, 'AllocationIndex', 0, 'StationIDs', zeros(obj.MaxUsers, 1));

        obj.Metadata = struct('Timestamp', zeros(maxSubframes, obj.MaxUsers), 'Vector', obj.Vector, ...
            'PayloadInfo', repmat(struct('OverheadDuration', 0,'Duration', 0,'NumOfBits', 0), [1,maxSubframes]), ...
            'SourcePosition', zeros(1, 3), 'PreambleDuration', 0, 'HeaderDuration', 0, ...
            'PayloadDuration', 0, 'Duration', 0, 'ChannelWidth', 0, 'SignalPower', 0, 'SourceID', 0, ...
            'SubframeCount', 0, 'SubframeLengths', zeros(1, maxSubframes), 'SubframeIndexes', zeros(1, maxSubframes), ...
            'NumHeaderAndPreambleBits', 0, 'StartTime', 0, 'SequenceNumbers', zeros(maxSubframes, obj.MaxUsers));

        obj.MACFrameCFG = struct('IsEmpty', true, 'FrameType', 'Data', 'FrameFormat', 'Non-HT', ...
            'Duration', 0, 'Retransmission', false(maxSubframes, obj.MaxUsers), ...
            'FourAddressFrame', false(maxSubframes, obj.MaxUsers), 'Address1', '000000000000', 'Address2', '000000000000', ...
            'Address3', repmat('0', maxSubframes, 12, obj.MaxUsers), 'Address4', repmat('0', maxSubframes, 12, obj.MaxUsers), ...
            'MeshSequenceNumber', zeros(maxSubframes, obj.MaxUsers), 'AckPolicy', 'No Ack', ...
            'TID', 0, 'SequenceNumber', zeros(maxSubframes, obj.MaxUsers), 'MPDUAggregation', false, ...
            'PayloadLength', zeros(maxSubframes, obj.MaxUsers), ...
            'MPDULength', zeros(maxSubframes, obj.MaxUsers), ...
            'PSDULength', zeros(obj.MaxUsers, 1), 'FCSPass', true(maxSubframes, obj.MaxUsers), ...
            'DelimiterFails', false(maxSubframes, obj.MaxUsers));

        obj.WLANSignal = struct('IsEmpty', true, ...
            'Waveform', [], ...
            'Metadata', obj.Metadata, ...
            'MACFrame', obj.MACFrameCFG);

        for idx = 1:obj.NumInterfaces
            % Generate a separate address for each network interface
            [macAddressDec, ~] = hNodeInfo(1, [obj.ID idx]);
            macAddressHex = reshape(dec2hex(macAddressDec, 2)', 1, []);
            obj.MAC(idx).MACAddress = macAddressHex;
        end

        % Initialize the transmitting and receiving buffers for each
        % interface within the node by mapping with its operating frequency
        obj.TxBuffer = cell(obj.NumInterfaces, 2);
        obj.TxBuffer(:, 1) = num2cell(obj.Frequencies);
        obj.TxBuffer(:, 2) = {obj.WLANSignal};
        obj.RxBuffer = cell(obj.NumInterfaces, 2);
        obj.RxBuffer(:, 1) = num2cell(obj.Frequencies);
        % Allow storing simultaneous transmissions from all other nodes
        obj.RxBuffer(:, 2) = {cell(1, obj.NumberOfNodes-1)};
        obj.RxBufferIdx = zeros(1, obj.NumInterfaces);
    end
end

methods
    function nextInvokeTime = runNode(obj, elapsedTime)
        %runNode Runs the WLAN node
        %
        %   NEXTINVOKETIME = runNode(OBJ, ELAPSEDTIME) runs the functionality
        %   of WLAN node (having MAC and PHY layers) by updating the
        %   elapsed time and returns the time to run the node again.
        %
        %   NEXTINVOKETIME is the time (in microseconds) after which the RUN
        %   function must be invoked again.
        %
        %   OBJ is an object of type hWLANNode.
        %
        %   ELAPSEDTIME is the time elapsed in microseconds between two
        %   successive calls of this function.

        % Initialize
        nextInvokeTimes = obj.EmptyDt;
        nextIdx = 1;

        % Update simulation time
        obj.CurrentTime = obj.CurrentTime + elapsedTime;
        for interfaceIdx = 1:obj.NumInterfaces
            obj.MAC(interfaceIdx).CurrentTime = obj.CurrentTime;
            obj.PHYRx(interfaceIdx).CurrentTime = obj.CurrentTime;
        end

        % Run the application layer
        nextAppInvokeTime = runApplication(obj.Application, elapsedTime, @obj.pushData);
        nextInvokeTimes(nextIdx) = nextAppInvokeTime;
        nextIdx = nextIdx + 1;

        for interfaceIdx = 1:obj.NumInterfaces
            interfaceElapsedTime = elapsedTime;

            % Rx buffer has data to be processed
            if obj.RxBufferIdx(interfaceIdx) ~= 0
                rxBuffer = obj.RxBuffer{interfaceIdx, 2};
                for idx = 1:obj.RxBufferIdx(interfaceIdx)
                    % Process the received data
                    interfaceInvokeTime = run(obj, interfaceIdx, interfaceElapsedTime, rxBuffer{idx});
                    nextInvokeTimes(nextIdx:nextIdx+1) = interfaceInvokeTime;
                    % Increment the nextInvokeTimes vector index by 2 to
                    % fill MAC and PHY invoke times in next iteration.
                    nextIdx = nextIdx+2;
                    % Set the elapsed time as 0, because all the data in the Rx
                    % buffer should be processed at the same timestamp
                    interfaceElapsedTime = 0;
                end
                obj.RxBufferIdx(interfaceIdx) = 0;
                % Rx buffer has no data to process
            else
                % Update the elapsed time to all the layers
                interfaceInvokeTime = run(obj, interfaceIdx, interfaceElapsedTime, obj.WLANSignal);
                nextInvokeTimes(nextIdx:nextIdx+1) = interfaceInvokeTime;
                nextIdx = nextIdx+2;
            end
        end
        % Get the next invoke time
        nextInvokeTimes = nextInvokeTimes(1:nextIdx-1);
        nextInvokeTime = min(nextInvokeTimes(nextInvokeTimes ~= -1));
        if isempty(nextInvokeTime)
            nextInvokeTime = -1;
        end
    end

    function addInterface(obj, freqID, frequency, bandAndChannel, mac, phyTx, phyRx, channel)
    %addInterface Add an interface to the node with the given frequency
    %
    %   addInterface(OBJ, FREQID, FREQUENCY, BANDANDCHANNEL, MAC, PHYTX,
    %   PHYRX, CHANNEL) adds an interface to the node with the given inputs
    %   MAC, PHY and CHANNEL objects at the given FREQUENCY.
    %
    %   OBJ is an object of type <a
    %   href="matlab:help('hWLANNode')">hWLANNode</a>
    %
    %   FREQID is a frequency identifier of the interface. Each interface
    %   has a unique frequency ID
    %
    %   FREQUENCY represents the operating frequency of the interface in
    %   GHz
    %
    %   BANDANDCHANNEL is the operating band and channel number of the
    %   interface. It is a cell array of vector in the format {[x, y]}
    %   where x = band, y = channel number. The value of x can be 2.4, 5,
    %   or 6. The value of y can be any valid channel number.
    %
    %   MAC is an object of type <a
    %   href="matlab:help('hEDCAMAC')">hEDCAMAC</a>. This object contains
    %   methods and properties related to WLAN MAC layer.
    %
    %   PHYTX can be an abstracted PHY object <a
    %   href="matlab:help('hPHYTxAbstract')">hPHYTxAbstract</a> or full PHY
    %   object href="matlab:help('hPHYTx')">hPHYTx</a>. This object
    %   contains methods and properties related to WLAN PHY transmitter.
    %
    %   PHYRX can be an abstracted PHY objects <a
    %   href="matlab:help('hPHYRxAbstract')">hPHYRxAbstract</a> or full PHY
    %   objects href="matlab:help('hPHYRx')">hPHYRx</a>. This object
    %   contains methods and properties related to WLAN PHY receiver.
    %
    %   CHANNEL is an object of type <a
    %   href="matlab:help('hChannel')">hChannel</a>. This object contains
    %   methods and properties related to WLAN channel model.

        % Validate the frequency
        validateattributes(frequency, {'numeric'}, {'scalar', 'positive'}, ...
            mfilename, 'Frequencies');

        % Get the interface index
        index = (frequency == obj.Frequencies);
        if ~any(index)
            obj.NumInterfaces = obj.NumInterfaces + 1;
            interfaceIdx = obj.NumInterfaces;
        else
            interfaceIdx = find(index);
        end

        % Validate the MAC
        validateattributes(mac, {'hEDCAMAC'}, {'scalar'}, ...
            mfilename, 'mac');

        % Validate the PHY Tx
        validateattributes(phyTx, {'hPHYTxAbstract', 'hPHYTx'}, {'scalar'}, ...
            mfilename, 'phyTx');

        % Validate the PHY Rx
        validateattributes(phyRx, {'hPHYRxAbstract', 'hPHYRx'}, {'scalar'}, ...
            mfilename, 'phyRx');

        % Validate the PHY Rx
        validateattributes(channel, {'hChannel'}, {'scalar'}, ...
            mfilename, 'channel');

        if ~(frequency >= 2.412 && frequency <= 2.484) && ... % 2.4GHz
            ~(frequency >= 5.180 && frequency <= 5.900) &&  ...% 5GHz
            ~(frequency >= 5.925 && frequency <= 7.125) % 6GHz
            error('Operating frequencies (GHz) of the node must be between [2.412, 2.484] or [5.180, 5.900] or [5.925, 7.125]');
        end

        % Update the interface information
        mac.OperatingFreqID = freqID;
        mac.OperatingFrequency = frequency;
        phyRx.OperatingFreqID = freqID;
        phyRx.OperatingFrequency = frequency;
        phyTx.OperatingFreqID = freqID;
        phyTx.OperatingFrequency = frequency;
        channel.Frequency = frequency;
        obj.Frequencies(interfaceIdx) = frequency;
        obj.BandAndChannel{interfaceIdx} = bandAndChannel;
        obj.MAC(interfaceIdx) = mac;
        obj.PHYTx(interfaceIdx) = phyTx;
        obj.PHYRx(interfaceIdx) = phyRx;
        obj.Channel(interfaceIdx) = channel;
    end

    % Get current simulation time
    function time = getCurrentTime(obj)
        time = obj.CurrentTime;
    end
end

methods (Access = private)
    function bufferFull = pushData(obj, appPacket)
    %pushData Push application data into all the instances of the
    %MAC layer operating on different frequencies

        % Initialize flag as false by default
        bufferFull = false;

        % Update the application packet with mesh addresses
        if obj.IsMeshEnabled
            % Add mesh information to the application packet
            [macQueuePacket, sourceInterfaceIdx] = addMeshInfo(obj, appPacket);

            % Check whether the destination address is group address or not
            groupAddress = isGroupAddress(obj, macQueuePacket.DestinationAddress);

            % Push the data into all the interfaces when the destination
            % address is a group address (multicasting/broadcasting).
            if groupAddress
                sourceInterfaceIdx = 1:obj.NumInterfaces;
            end

            % Check if the MAC buffers for each interface is full
            emptyBuffers = true(1, numel(sourceInterfaceIdx));
            for idx=1:numel(sourceInterfaceIdx)
                % Get the source MAC interface
                freqID = obj.MAC(sourceInterfaceIdx(idx)).OperatingFreqID;
                obj.Application.AppTxAC(appPacket.PriorityID+1, freqID) = obj.Application.AppTxAC(appPacket.PriorityID+1, freqID) + 1;
                obj.Application.AppTxBytes(freqID) = obj.Application.AppTxBytes(freqID) + appPacket.PacketLength;
                if edcaQueueManagement(obj.MAC(sourceInterfaceIdx), 'isQueueFull', appPacket)
                    emptyBuffers(idx) = false;
                end
            end
            % Return if MAC buffers for all interfaces are full
            if ~any(emptyBuffers)
                bufferFull = true;
                obj.Application.AppTxOverflow(sourceInterfaceIdx) = obj.Application.AppTxOverflow(sourceInterfaceIdx) + 1;
                return
            end

        else
            % When mesh is disabled, only the first interface is active
            % used for transmission. Push the data into the first
            % interface of the source node.
            sourceInterfaceIdx = 1;

            % Update App Tx statistics
            freqID = obj.MAC(sourceInterfaceIdx).OperatingFreqID;
            obj.Application.AppTxAC(appPacket.PriorityID+1, freqID) = obj.Application.AppTxAC(appPacket.PriorityID+1, freqID) + 1;
            obj.Application.AppTxBytes(freqID) = obj.Application.AppTxBytes(freqID) + appPacket.PacketLength;
            % Return if MAC buffers are full
            if edcaQueueManagement(obj.MAC(sourceInterfaceIdx), 'isQueueFull', appPacket)
                obj.Application.AppTxOverflow(freqID) = obj.Application.AppTxOverflow(freqID) + 1;
                bufferFull = true;
                return
            end

            [destinationAddressDec, ~] = hNodeInfo(1, [appPacket.DestinationID sourceInterfaceIdx]);
             destinationAddressHex = reshape(dec2hex(destinationAddressDec, 2)', 1, []);

            % Update the common fields
            macQueuePacket = obj.MACQueuePacket;
            macQueuePacket.MSDULength = appPacket.PacketLength;
            macQueuePacket.AC = appPacket.PriorityID;
            macQueuePacket.DestinationID = appPacket.DestinationID;
            macQueuePacket.DestinationAddress = destinationAddressHex;
            macQueuePacket.NextHopID = appPacket.DestinationID;
            macQueuePacket.NextHopAddress = destinationAddressHex;
            macQueuePacket.Data = appPacket.Data;
        end
        % Add packet timestamp
        macQueuePacket.Timestamp = getCurrentTime(obj);
        isSuccess = false(1, numel(sourceInterfaceIdx));
        for idx = 1:numel(sourceInterfaceIdx)
            % Get the source MAC interface to push the application packet
            mac = obj.MAC(sourceInterfaceIdx(idx));
            % Packet origin source address
            macQueuePacket.SourceAddress = mac.MACAddress;
            if obj.IsMeshEnabled
                % Mesh sequence number
                macQueuePacket.MeshSequenceNumber = getMeshSequenceNumber(obj, mac.MACAddress);
            end
            freqID = mac.OperatingFreqID;
            if macQueuePacket.DestinationID ~= 65535
                % Update application packets transmitted per destination
                obj.Application.AppTxPerDestination(macQueuePacket.DestinationID, freqID) = obj.Application.AppTxPerDestination(macQueuePacket.DestinationID, freqID) + 1;
            end
            % Push the application data into the MAC queue
            isSuccess(idx) = edcaQueueManagement(mac, 'enqueue', macQueuePacket);
        end
    end

    function nextInvokeTime = run(obj, interfaceIdx, elapsedTime, wlanRxSignal)
        %run Runs the node with the received signal and returns the next invoke
        %time in microseconds

        % Reset Tx buffer
        obj.TxBuffer{interfaceIdx, 2}.Metadata.SubframeCount = 0;

        % MAC object
        mac = obj.MAC(interfaceIdx);
        % PHY Tx object
        phyTx = obj.PHYTx(interfaceIdx);
        % PHY Rx object
        phyRx = obj.PHYRx(interfaceIdx);
        % Channel object
        channel = obj.Channel(interfaceIdx);

        % Pass the received WLAN waveform through the channel to apply
        % path loss and interference
        if ~wlanRxSignal.IsEmpty
            % Pass the received signal through the channel
            wlanRxSignal = run(channel, wlanRxSignal);
        end

        % Received a WLAN waveform and the receiver is switched on for the
        % node
        if phyRx.RxOn
            % Invoke the PHY receiver module
            [nextPHYTime, indicationToMAC, frameToMAC] = run(phyRx, elapsedTime, wlanRxSignal);

            % Pass the decoded data to MAC layer
            mac.RxData = frameToMAC;

            % Invoke the MAC layer
            [nextMACInvokeTime, macReqToPHY, frameToPHY] = run(mac, indicationToMAC, elapsedTime);

            % Update PHY Rx mode
            if ~mac.PHYMode.IsEmpty
                setPHYMode(phyRx, mac.PHYMode);
            end

            if ~mac.PacketToApp.IsEmpty
                % Handle the decoded MSDUs from the MAC
                handleReceivedPacket(obj, mac);
            end

            % Invoke the PHY transmitter module (pass MAC requests to PHY)
            run(phyTx, macReqToPHY, frameToPHY);
        else
            % Reset the MAC Rx data
            mac.RxData = mac.EmptyFrame;

            % Invoke the MAC layer
            [nextMACInvokeTime, macReqToPHY, frameToPHY] = run(mac, phyTx.PHYConfirmIndication, elapsedTime);

            % Log any interference detected at phy receiver in transmission
            % mode
            nextPHYTime = run(phyRx, elapsedTime, wlanRxSignal);

            % Update PHY Rx mode
            if ~mac.PHYMode.IsEmpty
                setPHYMode(phyRx, mac.PHYMode);
            end
            % Invoke the PHY transmitter module (Pass MAC requests to PHY)
            run(phyTx, macReqToPHY, frameToPHY);
        end

        % Update the transmitted waveform along with the metadata
        if ~phyTx.TransmitWaveform.IsEmpty
            obj.TxBuffer{interfaceIdx, 2} = phyTx.TransmitWaveform;
            phyTx.TransmitWaveform.IsEmpty = true;
        end

        % Update the next invoke time as minimum of next invoke times of
        % all the modules
        nextInvokeTime = [nextPHYTime nextMACInvokeTime];
    end

    function forwardAppData(obj, macPacket, packetIdx, isGroup)
        % Initialize the MAC queue packet structure
        macQueuePacket = obj.MACQueuePacket;
        % Update the fields
        macQueuePacket.MSDULength = macPacket.MSDULength(packetIdx);
        macQueuePacket.AC = macPacket.AC;
        macQueuePacket.NextHopID = macPacket.DestinationID;
        macQueuePacket.NextHopAddress = macPacket.DestinationMACAddress;
        macQueuePacket.SourceAddress = macPacket.MeshSourceAddress(packetIdx, :);
        macQueuePacket.MeshSequenceNumber = macPacket.MeshSequenceNumber(packetIdx);
        macQueuePacket.Timestamp = macPacket.Timestamp(packetIdx);
        if isempty(macPacket.Data)
            macQueuePacket.Data = []; % For abstracted MAC frame
        else
            macQueuePacket.Data = macPacket.Data(packetIdx, :); % For full MAC frame
        end
        % Update the destination address with group address
        if isGroup
            macQueuePacket.DestinationAddress = macPacket.DestinationMACAddress;
            macQueuePacket.DestinationID = macPacket.DestinationID;
        else
            macQueuePacket.DestinationAddress = macPacket.MeshDestinationAddress(packetIdx, :);
            % Get the destination ID from the final destination address
            [~, destNode] = hNodeInfo(2, macQueuePacket.DestinationAddress);
            macQueuePacket.DestinationID = destNode(1);
        end

        % Get the next hop addresses for transmitting the data
        [forwardInterfaceIdx, ~, nextHopAddress] = nextHop(obj, macQueuePacket.DestinationID);

        % Next hop is the broadcast address
        if isGroup
            forwardInterfaceIdx = 1:obj.NumInterfaces;
        else
            % Update the addresses of the received application data
            macQueuePacket.NextHopAddress = nextHopAddress;
                macQueuePacket.NextHopID = hex2dec(nextHopAddress(end-1:end));
        end

        for idx = 1:numel(forwardInterfaceIdx)
            % Get the source MAC interface to push the application packet
            mac = obj.MAC(forwardInterfaceIdx(idx));
            freqID = mac.OperatingFreqID;
            % Update application packets transmitted per AC
            obj.Application.AppTxAC(appPacket.PriorityID+1, freqID) = obj.Application.AppTxAC(appPacket.PriorityID+1, freqID) + 1;
            % Push the packet into MAC queue to forward it to the next hop
            edcaQueueManagement(mac, 'enqueue', macQueuePacket);
        end
    end

    function receiveAppData(obj, macPacket, packetIdx, freqID)
        % Initialize
        appPacket = hApplication.ApplicationPacket;
        % Update the application packet fields
        appPacket.PacketLength = macPacket.MSDULength(packetIdx);
        appPacket.PriorityID = macPacket.AC;
        appPacket.DestinationID = macPacket.DestinationID;
        appPacket.Timestamp = macPacket.Timestamp(packetIdx);
        if isempty(macPacket.Data)
            appPacket.Data = []; % For abstracted MAC frame
        else
            appPacket.Data = macPacket.Data(packetIdx, :); % For full MAC frame
        end
        % Give received packet to application layer
        receivePacket(obj.Application, appPacket, freqID);
    end

    function handleReceivedPacket(obj, mac)
        % Give each application packet (MSDU) to application
        for packetIdx = 1:mac.PacketToApp.MSDUCount
            % Check whether the final destination is group address or not
            isGroupAddr = isGroupAddress(obj, mac.PacketToApp.DestinationMACAddress);

            % Received packet is in 4-address format or destination
            % address is group address
            if obj.IsMeshEnabled && (mac.PacketToApp.FourAddressFrame(packetIdx) || isGroupAddr)
                % Group address
                if isGroupAddr
                    % Check whether the packet is already received
                    % or not
                    isDuplicate = isDuplicateFrame(obj, ...
                        mac.PacketToApp.MeshSourceAddress(packetIdx, :), ...
                        mac.PacketToApp.MeshSequenceNumber(packetIdx));
                    if ~isDuplicate
                        % Receive the application packet
                        receiveAppData(obj, mac.PacketToApp, packetIdx, mac.OperatingFreqID);
                        % Forward the packet in all the MAC
                        % interfaces
                        forwardAppData(obj, mac.PacketToApp, packetIdx, isGroupAddr);
                    end
                else
                    if strcmp(mac.MACAddress, mac.PacketToApp.MeshDestinationAddress(packetIdx, :))
                        % Packet destined to us. Give to application layer
                        receiveAppData(obj, mac.PacketToApp, packetIdx, mac.OperatingFreqID);
                    else
                        % Forward the application data towards the
                        % destination node
                        forwardAppData(obj, mac.PacketToApp, packetIdx, isGroupAddr);
                    end
                end
            else
                % Receive the application packet
                receiveAppData(obj, mac.PacketToApp, packetIdx, mac.OperatingFreqID);
            end
            % Calculate the received application packet latency
            obj.PacketLatencyIdx = obj.PacketLatencyIdx + 1;
            obj.PacketLatency(obj.PacketLatencyIdx) = getCurrentTime(obj) -  mac.PacketToApp.Timestamp(packetIdx); % in microseconds
            % Update the packet latency at the application layer
            obj.Application.AppAvgPacketLatency(mac.OperatingFreqID) = ...
                obj.Application.AppAvgPacketLatency(mac.OperatingFreqID) + obj.PacketLatency(obj.PacketLatencyIdx);
            % Update the packet latency per AC
            obj.Application.AppAvgPacketLatencyAC(mac.PacketToApp.AC+1, mac.OperatingFreqID) = ...
                obj.Application.AppAvgPacketLatencyAC(mac.PacketToApp.AC+1, mac.OperatingFreqID) + obj.PacketLatency(obj.PacketLatencyIdx);
        end
    end

    function flag = isGroupAddress(~, destinationAddress)
    %isGroupAddress Returns true when the destination address is broadcast
    %or group address of the current node

        bits = bitget(hex2dec(destinationAddress(1:2)), 1:8);
        flag = bits(1);
    end
end

methods
    %% Plug-in code for easy customization
    function pushChannelData(obj, txPosition, rxFrequency, rxData)
        %pushChannelData Check whether this node has to receive and process
        %this packet
        %
        %   OBJ is an object of type hWLANNode.
        %
        %   TXPOSITION is the position of the transmitter node.
        %
        %   RXFREQUENCY Frequency on which the RXDATA is received.
        %
        %   RXDATA Data received from the channel on the RXFREQUENCY.

        % Calculate the distance between sender and receiver in meters
        distance = norm(txPosition - obj.Position);

        % Copy the received data into the Rx buffer when received in the
        % same operating frequency and the transmitting node is within the
        % range of receiving node
        for idx = 1:obj.NumInterfaces
            if (obj.RxBuffer{idx, 1} == rxFrequency) && (distance <= obj.ReceiverRange)
                rxBufIdx = obj.RxBufferIdx(idx);
                obj.RxBuffer{idx, 2}{rxBufIdx+1} = rxData;
                obj.RxBufferIdx(idx) = obj.RxBufferIdx(idx) + 1;
                break;
            end
        end
    end

    function [forwardInterfaceID, destinationAddress, nextHopAddress] = ...
            nextHop(obj, destinationID)
        % Destination is the broadcast ID
        if (destinationID == 65535)
            % Packet forwards into all the available interfaces
            forwardInterfaceID = 0;
            destinationAddress = 'FFFFFFFFFFFF'; % Broadcast address
            nextHopAddress = 'FFFFFFFFFFFF'; % Broadcast address
        else
            % Get the path of the specified destination node
            nodeIds = cell2mat(obj.ForwardTable(:, 1));
            pathIdx = destinationID == nodeIds;

            % No path exists for the specified destination node
            if all(pathIdx == 0)
                error('No further path exists')
            end

            % Source interface index
            forwardInterfaceID = obj.ForwardTable{pathIdx, 4};
            % Destination address
            destinationAddress = obj.ForwardTable{pathIdx, 2};
            % Immediate next hop address
            nextHopAddress = obj.ForwardTable{pathIdx, 3};
        end
    end

    function meshSequenceNumber = getMeshSequenceNumber(obj, sourceAddress)
        % Get the index for source address mesh sequence counter
        srcIdx = strcmpi(obj.MeshSequenceCounter(:, 1), sourceAddress);
        if any(srcIdx)
            % Update the mesh sequence counter
            obj.MeshSequenceCounter{srcIdx, 2} = obj.MeshSequenceCounter{srcIdx, 2} + 1;
            % Round off the counter to 1 when reaches to its maximum
            % value
            if obj.MeshSequenceCounter{srcIdx, 2} > obj.MaxSequenceNumber
                obj.MeshSequenceCounter{srcIdx, 2} = 1;
            end
            meshSequenceNumber = obj.MeshSequenceCounter{srcIdx, 2};
        else
            % Start the mesh sequence counter
            obj.MeshSequenceCounter = [obj.MeshSequenceCounter; ...
                {sourceAddress 1}];
            meshSequenceNumber = 1;
        end
    end

    function [macQueuePacket, sourceInterfaceIdx] = addMeshInfo(obj, appPacket)
        %addMeshInfo Forms the MAC queue packet by adding the routing
        %details and mesh sequence number to the given application packet

        % Initialize the MAC queue packet
        macQueuePacket = obj.MACQueuePacket;

        % Update the common fields
        macQueuePacket.MSDULength = appPacket.PacketLength;
        macQueuePacket.AC = appPacket.PriorityID;
        macQueuePacket.Data = appPacket.Data;

        % Get the next hop addresses for transmitting the data
        [sourceInterfaceIdx, destinationAddress, nextHopAddress] = ...
            nextHop(obj, appPacket.DestinationID);

        % Update the destination address
        macQueuePacket.DestinationID = appPacket.DestinationID;
        macQueuePacket.DestinationAddress = destinationAddress;

        % If final destination is not in the next hop, then update the
        % next hop address
        if ~strcmp(nextHopAddress, destinationAddress)
            macQueuePacket.NextHopAddress = nextHopAddress;
            [~, nextHopNode] = hNodeInfo(2, nextHopAddress);
            macQueuePacket.NextHopID = nextHopNode(1);
            % Update the next hop as the final destination address
        else
            macQueuePacket.NextHopAddress = destinationAddress;
            macQueuePacket.NextHopID = appPacket.DestinationID;
        end
        macQueuePacket.Timestamp = appPacket.Timestamp;
    end

    function isDuplicate = isDuplicateFrame(obj, sourceAddress, sequenceNumber)
        %isDuplicateFrame Check whether the frame is already received or
        %not

        % Initialize
        isDuplicate = false;

        % Original source address
        txIdx = strcmpi(obj.PacketCache(:, 1), sourceAddress);
        % Received the packet from the original source
        if any(txIdx)
            % Received a duplicate packet with maximum sequence number
            if (obj.PacketCache{txIdx, 2} == 0) && sequenceNumber == obj.MaxSequenceNumber
                isDuplicate = true;
                return;
            end
            % Received duplicate packet with old sequence number
            if sequenceNumber <= obj.PacketCache{txIdx, 2}
                isDuplicate = true;
                obj.RxDuplicatePackets{txIdx, 2} = obj.RxDuplicatePackets{txIdx, 2} + 1;
            else
                % Reset the mesh sequence number when reaches to its
                % maximum value
                if sequenceNumber == obj.MaxSequenceNumber
                    sequenceNumber = 0;
                end
                % Update the newly received sequence number
                obj.PacketCache{txIdx, 2} = sequenceNumber;
            end
        else
            % Add the new original source address into the packet cache
            obj.PacketCache = [obj.PacketCache; {sourceAddress, sequenceNumber}];
            obj.RxDuplicatePackets = [obj.RxDuplicatePackets; {sourceAddress, 0}];
        end
    end
end
end
