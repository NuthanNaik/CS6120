classdef hPHYRxAbstract < hPHYRxInterface
%hPHYRxAbstract Create an object for WLAN PHY receiver
%   WLANPHYRX = hPHYRxAbstract creates a WLAN PHY Receiver object for PHY
%   decoding.
%
%   WLANPHYRX = hPHYRxAbstract(Name, Value) creates a WLAN PHY
%   Receiver object with the specified property Name set to the specified
%   Value. You can specify additional name-value pair arguments in any
%   order as (Name1, Value1, ..., NameN, ValueN).
%
%   hPHYRxAbstract methods:
%
%   run         - Run the physical layer receive operations
%   setPHYMode  - Handle the PHY mode set request from the MAC layer
%
%   hPHYRxAbstract properties:
%
%   NodeID              - Node ID of the receiving WLAN device
%   NumberOfNodes       - Number of nodes from which signal might come
%   EDThreshold         - Energy detection threshold in dBm
%   RxGain              - Receiver gain in dB
%   AbstractionType     - PHY abstraction type

%   Copyright 2021 The MathWorks, Inc.

properties
    %AbstractionType PHY abstraction type
    %   Specify the PHY abstraction as either of the two strings,
    %   'TGax Evaluation Methodology Appendix 1',
    %   'TGax Simulation Scenarios MAC Calibration'.
    AbstractionType = 'TGax Evaluation Methodology Appendix 1';
end

properties (Hidden)
    %MaxSubframes Maximum number of subframes that can be present in an
    %A-MPDU
    MaxSubframes = 64;
    
    %ChannelBandwidth Total channel bandwidth available for the node
    ChannelBandwidth = 20;
end

% Information specific to a WLAN signal currently being decoded
properties (Access = private)
    % WLAN frame format of the signal being decoded
    RxFrameFormat;
    
    % Counter for subframes processed till now in the received signal
    RxSubFrameCount = 0;
    
    % Number of subframes in the received signal, got as metadata of signal
    NoOfSubFrames = 1;
    
    % Byte boundary of start indexes subframes
    SubFrameIndices;
    
    % Subframe lengths starting from frame indexes
    SubFrameLengths;

    % CCA idle flag to indicate channel state
    CCAIdle = 1;
    
    % Timer for receiving preamble and header, payload of a WLAN waveform
    % (in microseconds). When preamble & header is being received, it
    % contains the time till end of that preamble. While receiving
    % a subframe / payload, it contains the corresponding end time.
    ReceptionTimer = 0;

    % Structure storing information of signal of interest
    SignalOfInterest;

    % User index for single user processing. Index '1' will be used in
    % case of single user and downlink multi-user reception. Indices
    % greater than '1' will be used in case of downlink multi-user
    % transmission and uplink multi-user reception.
    UserIndexSU = 1;
end

properties (Access = private)
    % PHY abstraction type, true indicates 'TGax Evaluation
    % Methodology Appendix 1' and false indicates
    % 'TGax Simulation Scenarios MAC Calibration'.
    AbstractionTypeTGAXAppendix1 = true;
end

% PHY receiver configuration objects
properties (Access = private)
    % Non-HT configuration object
    NonHTConfig;
    
    % HT configuration object
    HTConfig;
    
    % VHT configuration object
    VHTConfig;
    
    % HE-SU configuration object
    HESUConfig;
end
    
% PHY receiver components
properties (Access = private)    
    % tgaxPERAbstraction object
    PERAbstraction;
    
    % tgaxLinkQuality object
    LinkQuality;

    % Interference object
    Interference;
end

% Hold the results of a decoded signal
properties (Access = private)
    % PHY Rx buffer to store the received PSDU.
    RxData;

    % Received data length in bytes
    RxDataLength = 0;
end

properties (Constant, Hidden)
    % Maximum number of users
    MaxMUUsers = 9;

    % Maximum PSDU length in bytes with 8x8 MIMO, over 160MHz bandwidth
    MaxPSDULength = 6500631;
end

properties (SetAccess = private, Hidden)
    % Received WLAN waveform
    WLANSignal;
    
    % Structure holding metadata for the received packet
    Metadata;

    % SignalDecodeStage Decoding stage of the WLAN waveform reception
    % 0 - Waveform processing not started
    % 1 - Process the end of preamble and header
    % 2 - Process the end of actively received payload / MPDU in an AMPDU
    % 3 - End of waveform duration and so signal has to be removed
    SignalDecodeStage = 0;
    
    % Logical indicating a pre-computed probability of packet segment
    % success can be used
    UsePacketSuccessProbCache = false;
    
    % Pre-computed probability of packet segment success
    PacketSuccessProbCache = 0;
end

properties (Hidden)
    % Flag to indicate whether receiver antenna is on
    RxOn = true;

    % Structure of Rx-Vector (the same as Tx-Vector)
    RxVector;
    
    % Structure holding the MAC frame properties
    MACFrameCFG;
    
    % Structure holding the MAC frame and its metadata
    EmptyFrame;
    
    %PHYMode Structure holding the configuration for PHY mode
    %   This is an input structure from MAC to configure the PHY Rx mode.
    PHYMode = struct('IsEmpty', true, ...
        'PHYRxOn', true, ...
        'EnableSROperation', 0, ...
        'BSSColor', 0, ...
        'OBSSPDThreshold', 0);
    
    % Current simulation time in microseconds
    CurrentTime = 0;
    
    % Operating frequency ID
    OperatingFreqID = 1;

    %OperatingFrequency Frequency of operation in GHz
    OperatingFrequency = 5.180;
    
    % Default of structure storing information for signal of interest
    SignalBufferDefault = struct('Waveform', complex([]), 'SourceID',-1,  ...
            'IsActive',false, ...
            'RxPower',0, ...
            'EndTime',-1, ...
            'Metadata', signalMetadataPrototype);
end

% Spatial reuse properties
properties (Hidden)
    % Overlapping Basic Service Set Packet Detect Threshold (dBm)
    OBSSPDThreshold = -82;

    % Basic Service Set (BSS) color of the node
    BSSColor = 0;

    % BSS color decoded from the received waveform
    RxBSSColor = 0;
    
    % Tx Power limit flag. This will be set to true when received frame
    % is decoded as Inter-BSS frame and the signal power is less than
    % OBSSPDThreshold.
    LimitTxPower = false;
    
    % Spatial reuse flag
    EnableSROperation = 0;
end

methods
    % Constructor
    function obj = hPHYRxAbstract(varargin)
    % Perform one-time calculations, such as computing constants

        % Name-value pairs
        for idx = 1:2:numel(varargin)
            obj.(varargin{idx}) = varargin{idx+1};
        end
        
        % Initialize PHY configuration objects for different formats
        obj.NonHTConfig = wlanNonHTConfig;
        obj.HTConfig = wlanHTConfig;
        obj.VHTConfig = wlanVHTConfig('ChannelBandwidth', 'CBW20');
        obj.HESUConfig = wlanHESUConfig;
        obj.SignalOfInterest = obj.SignalBufferDefault;
        obj.PERAbstraction = hTGaxLinkPerformanceModel();
        obj.Interference = hInterference('BufferSize', obj.NumberOfNodes - 1, 'SignalMetadataPrototype' , signalMetadataPrototype , 'ExtractMetadataFn', @extractMetadata);
        obj.RxData = []; %zeros(obj.MaxPSDULength*8, obj.MaxMUUsers, 'uint8');
        obj.EDThresoldInWatts = power(10.0, (obj.EDThreshold - 30)/ 10.0); % Converting from dBm to watts
        obj.SubFrameIndices = zeros(1,obj.MaxSubframes);
        obj.SubFrameLengths = zeros(obj.MaxSubframes, 1);
        
        obj.MACFrameCFG = struct('IsEmpty', true, ...
            'FrameType', 'Data', ...
            'FrameFormat', hFrameFormats.NonHT, ...
            'Duration', 0, ...
            'Retransmission', false(obj.MaxSubframes, obj.MaxMUUsers), ...
            'FourAddressFrame', false(obj.MaxSubframes, obj.MaxMUUsers), ...
            'Address1', '000000000000', ...
            'Address2', '000000000000', ...
            'Address3', repmat('0', obj.MaxSubframes, 12, obj.MaxMUUsers), ...
            'Address4', repmat('0', obj.MaxSubframes, 12, obj.MaxMUUsers), ...
            'MeshSequenceNumber', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'AckPolicy', 'No Ack', ...
            'SequenceNumber', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'TID', 0, ...
            'BABitmap', '0000000000000000', ...
            'MPDUAggregation', false, ...
            'PayloadLength', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'MPDULength', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'PSDULength', zeros(obj.MaxMUUsers, 1), ...
            'FCSPass', true(obj.MaxSubframes, obj.MaxMUUsers), ...
            'DelimiterFails', false(obj.MaxSubframes, obj.MaxMUUsers));
        obj.EmptyFrame = struct('IsEmpty', true, ...
            'MACFrame', obj.MACFrameCFG, ...
            'Data', [], ...
            'PSDULength', 0, ...
            'Timestamp', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'SubframeBoundaries', zeros(obj.MaxSubframes, 2), ...
            'NumSubframes', 0, ...
            'SequenceNumbers', zeros(obj.MaxSubframes, obj.MaxMUUsers));
        obj.RxVector = struct('IsEmpty', true, ...
            'EnableSROperation', false, ...
            'BSSColor', 0, ...
            'LimitTxPower', false, ...
            'OBSSPDThreshold', 0, ...
            'NumTransmitAntennas', 1, ...
            'NumSpaceTimeStreams', 0, ...
            'FrameFormat', 0, ...
            'AggregatedMPDU', false, ...
            'ChannelBandwidth', 0, ...
            'MCSIndex', double(zeros(1, obj.MaxMUUsers)'), ...
            'PSDULength', double(zeros(1, obj.MaxMUUsers)'), ...
            'RSSI', 0, ...
            'MessageType', 0, ...
            'AllocationIndex', 0, ...
            'StationIDs', double(zeros(1, obj.MaxMUUsers)'), ...
            'TxPower', zeros(obj.MaxMUUsers, 1));
        obj.Metadata = struct('Timestamp', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'Vector', obj.RxVector, ...
            'PayloadInfo', repmat(struct('OverheadDuration', 0,'Duration', 0,'NumOfBits', 0), [1,obj.MaxSubframes]), ...
            'SourcePosition', zeros(1, 3), ...
            'PreambleDuration', 0, ...
            'HeaderDuration', 0, ...
            'PayloadDuration', 0, ...
            'Duration', 0, ...
            'SignalPower', 0, ...
            'SourceID', 0, ...
            'SubframeCount', 0, ...
            'SubframeLengths', zeros(1, obj.MaxSubframes), ...
            'SubframeIndexes', zeros(1, obj.MaxSubframes), ...
            'NumHeaderAndPreambleBits', 0, ...
            'StartTime', 0, ...
            'SequenceNumbers', zeros(obj.MaxSubframes, obj.MaxMUUsers));
        obj.WLANSignal = struct('IsEmpty', true, ...
            'Waveform', [], ...
            'Metadata', obj.Metadata, ...
            'MACFrame', obj.MACFrameCFG);
    end

    % Set PHY abstraction type
    function set.AbstractionType(obj, value)
        validatestring(value, {'TGax Evaluation Methodology Appendix 1', ...
            'TGax Simulation Scenarios MAC Calibration'}, mfilename, 'AbstractionType');
        obj.AbstractionType = value;
        assignTgaxAbstractionFlag(obj, value)
    end
    
    
    function [nextInvokeTime, indicationToMAC, frameToMAC] = run(obj, elapsedTime, wlanSignal)
    %run physical layer receive operations for a WLAN node and returns the
    %next invoke time, indication to MAC, and decoded data bits along with
    %the decoded data length
    %
    %   [NEXTINVOKETIME, INDICATIONTOMAC, FRAMETOMAC] = run(OBJ,
    %   ELAPSEDTIME, WLANSIGNAL) receives and processes the waveform
    %
    %   NEXTINVOKETIME is the next event time, when this method must be
    %   invoked again.
    %
    %   INDICATIONTOMAC is an output structure to be passed to MAC layer
    %   with the Rx indication (CCAIdle/CCABusy/RxStart/RxEnd/RxErr). This
    %   output structure is valid only when its property IsEmpty is set to
    %   false. The type of this structure corresponds to RxVector property
    %   of this object.
    %
    %   FRAMETOMAC is an output structure to be passed to MAC layer. This
    %   output structure is valid only when its property IsEmpty is set to
    %   false. The type of this structure corresponds to EmptyFrame
    %   property of this object.
    %
    %   ELAPSEDTIME is the time elapsed since the previous call to this.
    %
    %   WLANSIGNAL is an input structure which contains the WLAN
    %   signal received from the channel. This is a valid signal when
    %   the property IsEmpty is set to false in the structure.
    %
    %   Structure 'WLANSIGNAL' contains the following fields:
    %
    %   IsEmpty      - Logical value, that defines whether the WLAN Rx
    %                  signal is empty or not.
    %   Waveform     - Array that stores the decoded waveform in bits
    %                  (field is not used, while using abstracted MAC)
    %   Metadata     - Structure holding metadata for the received packet
    %   MACFrame     - Structure holding the MAC frame properties
    %
    %   Structure 'METADATA' contains the following fields:
    %
    %   Vector	         - Structure containing the information of the
    %                      received vector from MAC
    %   PayloadInfo	     - Array of structures with each structure
    %                      containing the payload information of MPDU.
    %                      OverheadDuration - Duration of the overhead
    %                      Duration         - Payload duration
    %                      NumOfBits        - Number of bits of the payload
    %   SourcePosition	 - Position of the source node
    %   PreambleDuration - Duration of the preamble in micro seconds
    %   HeaderDuration	 - Duration of the header in micro seconds
    %   PayloadDuration	 - Duration of payload in micro seconds
    %   Duration         - Duration of the PPDU in micro seconds
    %   ChannelWidth	 - Bandwidth of the channel
    %   SignalPower	     - Signal power of the received signal
    %   SourceID	     - Node identifier of the source node.
    %   SubframeCount	 - Number of subframes in a A-MPDU
    %   SubframeLengths	 - Lengths of the subframes carried in a A-MPDU
    %   SubframeIndexes	 - Start indexes of the subframes in a A-MPDU
    %   NumHeaderAndPreambleBits - Total number of header and preamble bits
    %   StartTime	     - Frame start time
    %
    %   Structure 'VECTOR' contains the following fields:
    %
    %   IsEmpty             - Logical value to determine whether the
    %                         input is valid or not.
    %   EnableSROperation   - Logical flag, that defines whether spatial
    %                         reuse(SR) operation is enabled or not
    %   BSSColor            - Basic service set color (Used to
    %                         differentiate signals as Intra-BSS/Intra-BSS)
    %   LimitTxPower        - Tx Power limit flag. This will be set
    %                         to true when received frame is decoded as
    %                         Inter-BSS frame and the signal power is
    %                         less than OBSSPDThreshold.
    %   OBSSPDThreshold     - Overlapping BSS Packet Detect Threshold (dBm)
    %   NumTransmitAntennas - Number of transmit antennas
    %   NumSpaceTimeStreams - Configure multiple streams of data(MIMO)
    %   FrameFormat         - FrameFormat is the physical layer (PHY) frame
    %                         format, specified as a constant value of
    %                         class hFrameFormats. Specify this value as
    %                         one of these: hFrameFormats.NonHT,
    %                         hFrameFormats.HTMixed, hFrameFormats.VHT,
    %                         hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU,
    %                         or hFrameFormats.HE_MU. See <a
    %                         href="matlab:help('hFrameFormats')">hFrameFormats</a>
    %                         class for valid input values.
    %   AggregatedMPDU      - Logical flag that represents whether the
    %                         MPDU aggregation is enabled or not
    %   ChannelBandwidth    - Bandwidth of the channel
    %   MCSIndex            - Modulation coding scheme index in range [0, 11]
    %   PSDULength          - Length of the received PSDU
    %   RSSI                - Receive signal strength
    %   MessageType         - Stores the PHY indications
    %                         (CCAIdle/CCABusy/RxStart/RxEnd/RxErr). These
    %                         indications are of type hPHYPrimitives class
    %   AllocationIndex     - Allocation index for OFDMA transmission.
    %   StationIDs          - Station identifier
    %
    %   Subfield 'MACFRAME' structure contains the following fields:
    %
    %   IsEmpty	       - Logical value, that defines whether the MAC Frame
    %                    is empty or not.
    %   FrameType      - FrameType Type of the MAC frame. Specify the frame
    %                    type as one of 'RTS' | 'CTS' | 'ACK' | 'Block Ack'
    %                    | 'Trigger' | 'Data' | 'Null' | 'QoS Data' |'QoS
    %                    Null' | 'Beacon'. The default value is 'Data'.
    %   FrameFormat	   - Frame formats ('Non-HT', 'VHT', 'HE-SU', 'HE-MU',
    %                    'HT-Mixed', 'HE-EXT-SU'). The default value is
    %                    'Non-HT'.
    %   Duration	   - Duration of the frame
    %   Retransmission - Logical array. Each element in the array states
    %                    whether a subframe is being retransmitted or not.
    %   IsMeshFrame	   - Logical flag, that defines whether received frame
    %                    is a mesh frame or not.
    %   Address1	   - Receiver address
    %   Address2	   - Transmitter address
    %   Address3	   - Basic Service Set Identifier (or) Destination
    %                    Address (or) Source Address
    %   Address4	   - Source Address (or) Basic Service Set Identifier
    %   AckPolicy	   - Type of Ack, It can be 'No Ack', 'Normal
    %                    Ack/Implicit Block Ack Request'
    %   SequenceNumber - Assign sequence number to the frame. Sequence
    %                    numbers will be maintained per AC. For an
    %                    Aggregated frame, configuring the sequence number
    %                    of the first subframe is sufficient. Sequence
    %                    number of the remaining subframes will be assigned
    %                    sequentially in wlanMACFrame(MAC frame generator)
    %                    function.
    %   TID	           - Traffic identifier
    %   BABitmap	   - Block-Ack bitmap
    %   MPDUAggregation- Logical value, states whether the frame is
    %                    aggregated or not
    %   PayloadLength  - Length of the payload
    %   Timestamp	   - Packet generation timestamp
    %   MPDULength	   - Length of MPDU
    %   PSDULength	   - Length of PSDU
    %   FCSPass	       - Frame check sequence pass, used to check whether
    %                    the frame is corrupted or not
    %   DelimiterFails - Failures caused due to delimiter errors

        narginchk(2,3);

        rxData = obj.RxData;
        frameToMAC = obj.EmptyFrame;
        
        macFrameCFG = obj.MACFrameCFG;
        indicationToMAC = obj.RxVector;
        indicationToMAC.IsEmpty = true;
        isSignalReceived = false;

        if ~wlanSignal.IsEmpty
            isSignalReceived = true;
        end
        if isSignalReceived
            % Create an entry for every received signal
            updateWaveformEntry(obj, wlanSignal);
        end

        % Update the reception timer
        obj.ReceptionTimer = obj.ReceptionTimer - elapsedTime;

        % Reception of the decodable signal (or its part) is completed
        if obj.ReceptionTimer <= 0
            switch(obj.SignalDecodeStage)
                case 1 % Started receiving a waveform (endPreambleAndHeader)
                    % SINR calculation parameters
                    obj.RxFrameFormat = obj.WLANSignal.Metadata.Vector.FrameFormat;
                    if obj.AbstractionTypeTGAXAppendix1 % 'TGax Evaluation Methodology Appendix 1'
                        
                        % Get active interfering signals at this moment in
                        % time
                        sigSet = getSignalBuffer(obj.Interference);
                        
                        rxPowerSet = [obj.SignalOfInterest.RxPower [sigSet.RxPower]];
                        sourceIDSet = [obj.SignalOfInterest.SourceID [sigSet.SourceID]];
                        fieldSet = getCurrentFieldSet(obj,'preamble',sigSet);
                        % Method invocation using dot notation is done for MATLAB
                        % compiler support
                        rxConfigSet = obj.getConfigSet(sigSet);
                        
                        SINR = estimateLinkQuality(obj.LinkQuality,rxConfigSet,fieldSet,rxPowerSet,sourceIDSet,obj.NodeID);
                        
                        % Determine packet success rate for preamble
                        % assuming Non-HT, MCS 0 and BCC coding
                        p = 1 - (estimateLinkPerformance(obj.PERAbstraction, ...
                            SINR, (obj.WLANSignal.Metadata.NumHeaderAndPreambleBits)/8, hFrameFormats.getFrameFormatString(hFrameFormats.NonHT, 'PHY'), 0, 'BCC'));
                    else % 'TGax Simulation Scenarios MAC Calibration'
                        if (getTotalNumOfSignals(obj.Interference) >= 1) % One or more interfering signals
                            p = 0;
                        else % No interference
                            p = 1;
                        end
                    end

                    % Pick a random number and compare against the
                    % packet success rate. If the packet success rate
                    % is 0.9, it means that 90 percent of packets get
                    % successfully decoded and 10 percent are not
                    % decoded because of packet errors.
                    randNum = rand(1);

                    if (p > randNum)
                        isDecodable = true;
                        obj.RxDataLength = obj.WLANSignal.Metadata.Vector.PSDULength(obj.UserIndexSU);
                    else
                        isDecodable = false;
                        obj.RxDataLength = 0;
                    end

                    if isDecodable
                        % If the SR operation is disabled or the
                        % frame is not an inter-BSS frame generate
                        % "RXSTART" indication and schedule
                        % "endPayload" event, otherwise discard the
                        % frame using OBSS PD threshold and indicate
                        % CCA idle to MAC layer.
                        if ~obj.EnableSROperation || ~isFrameIgnorable(obj, obj.WLANSignal.Metadata.SignalPower)
                            % Extract frame boundaries from frame
                            obj.NoOfSubFrames = obj.WLANSignal.Metadata.SubframeCount;
                            obj.SubFrameLengths(1:obj.NoOfSubFrames) = ...
                                obj.WLANSignal.Metadata.SubframeLengths(1:obj.NoOfSubFrames);
                            obj.SubFrameIndices = obj.WLANSignal.Metadata.SubframeIndexes(1:obj.NoOfSubFrames);
                            indicationToMAC = obj.WLANSignal.Metadata.Vector;

                            % In case of single subframe/no
                            % subframes, schedule timer to the end
                            % of complete payload
                            if obj.NoOfSubFrames < 2
                                indicationToMAC.MessageType = hPHYPrimitives.RxStartIndication;
                                obj.ReceptionTimer = obj.WLANSignal.Metadata.PayloadDuration;
                                obj.SignalDecodeStage = 2;
                            else
                                % In case of multiple subframes,
                                % schedule timer to end of first frame
                                firstPayloadDuration = obj.WLANSignal.Metadata.PayloadInfo(1).Duration + ...
                                    obj.WLANSignal.Metadata.PayloadInfo(1).OverheadDuration;
                                indicationToMAC.MessageType = hPHYPrimitives.RxStartIndication;
                                obj.ReceptionTimer = firstPayloadDuration;
                                obj.SignalDecodeStage = 2;
                            end

                            % Check if the frame is aggregated
                            aggregatedMPDU = false;
                            if (obj.RxFrameFormat >= hFrameFormats.VHT)
                                % VHT frames are always aggregated
                                aggregatedMPDU = true;

                            elseif (obj.RxFrameFormat == hFrameFormats.HTMixed)
                                % HT frames may be aggregated
                                aggregatedMPDU = obj.WLANSignal.Metadata.Vector.AggregatedMPDU;
                            end

                            % Fill the Rx Vector
                            obj.RxVector.PSDULength = obj.WLANSignal.Metadata.Vector.PSDULength;
                            obj.RxVector.ChannelBandwidth = obj.WLANSignal.Metadata.Vector.ChannelBandwidth;
                            obj.RxVector.FrameFormat = obj.RxFrameFormat;
                            obj.RxVector.MCSIndex = obj.WLANSignal.Metadata.Vector.MCSIndex;
                            obj.RxVector.NumSpaceTimeStreams = obj.WLANSignal.Metadata.Vector.NumSpaceTimeStreams;
                            obj.RxVector.AggregatedMPDU = aggregatedMPDU;
                            obj.RxVector.RSSI = obj.WLANSignal.Metadata.SignalPower;
                            obj.RxVector.BSSColor = obj.WLANSignal.Metadata.Vector.BSSColor;
                        else
                            % Start of transmit power limitation period
                            obj.LimitTxPower = true;

                            % In case of total signal power is less
                            % than OBSS PD threshold, indicate CCA idle
                            % to MAC layer.
                            totalSignalPower = getTotalSignalPower(obj.Interference) + obj.SignalOfInterest.RxPower;
                            if totalSignalPower < power(10.0, (obj.OBSSPDThreshold - 30)/ 10.0) % Convert OBSS threshold in watts
                                indicationToMAC.IsEmpty = false;
                                indicationToMAC.MessageType = hPHYPrimitives.CCAIdleIndication;
                                indicationToMAC.ChannelBandwidth = obj.ChannelBandwidth;
                                obj.CCAIdle = 1;
                                obj.SignalDecodeStage = 0;

                                % Reset the reception timer
                                obj.ReceptionTimer = 0;
                            end

                            % Add signal to the interference buffer list
                            addSignal(obj.Interference, obj.WLANSignal);
                        end
                    else
                        % Even if the header cannot be decoded,
                        % simulate the channel busy time until the
                        % end of this waveform using the duration
                        indicationToMAC.IsEmpty = false;
                        indicationToMAC.MessageType = hPHYPrimitives.RxErrorIndication;
                        obj.ReceptionTimer = obj.WLANSignal.Metadata.PayloadDuration;
                        obj.SignalDecodeStage = 3;

                        % Increment the PHY decoding failures and Rx drop statistic
                        obj.PhyHeaderDecodeFailures = obj.PhyHeaderDecodeFailures + 1;
                        obj.PhyRxDrop = obj.PhyRxDrop + 1;
                    end

                case 2 % Preamble and Header successfully decoded (endPayload)
                    % SINR calculation parameters
                    obj.RxFrameFormat = obj.WLANSignal.Metadata.Vector.FrameFormat;

                    numInterferers = getTotalNumOfSignals(obj.Interference);
                    % Update PHY Rx statistics
                    obj.RxSubFrameCount = obj.RxSubFrameCount + 1;

                    % In case of multiple subframes, pass current payload
                    % data from complete aggregated payload and current
                    % payload index. Index of payload is required to access
                    % information of current subframe from Metadata.
                    currentPayloadInfo = obj.WLANSignal.Metadata.PayloadInfo(obj.RxSubFrameCount);
                    
                    if obj.UsePacketSuccessProbCache && numInterferers==0
                    % If possible use pre-computed and cached probability
                    % of packet segment success
                        p = obj.PacketSuccessProbCache;
                    else
                    % Otherwise calculate SINR and probability of success
                        if obj.AbstractionTypeTGAXAppendix1 % 'TGax Evaluation Methodology Appendix 1'
                            % Get active interfering signals at this moment in time 
                            sigSet = getSignalBuffer(obj.Interference);
                            
                            % Calculate SINR
                            rxPowerSet = [obj.SignalOfInterest.RxPower [sigSet.RxPower]];
                            sourceIDSet = [obj.SignalOfInterest.SourceID [sigSet.SourceID]];
                            fieldSet = getCurrentFieldSet(obj,'data',sigSet);
                            % Method invocation using dot notation is done for MATLAB
                            % compiler support
                            rxConfigSet = obj.getConfigSet(sigSet);
                            SINR = estimateLinkQuality(obj.LinkQuality,rxConfigSet,fieldSet,rxPowerSet,sourceIDSet,obj.NodeID);
                            
                            if (obj.RxFrameFormat == hFrameFormats.NonHT)
                                channelCoding = 'BCC';
                            else
                                channelCoding = rxConfigSet{1}.ChannelCoding;
                            end
                            
                            % Calculate probability of success for this
                            % chunk of payload
                            p = 1 - (estimateLinkPerformance(obj.PERAbstraction, ...
                                SINR, currentPayloadInfo.NumOfBits/8, hFrameFormats.getFrameFormatString(obj.RxFrameFormat, 'PHY'), obj.WLANSignal.Metadata.Vector.MCSIndex(obj.UserIndexSU), channelCoding));
                        else % 'TGax Simulation Scenarios MAC Calibration'
                            if (numInterferers >= 1) % One or more interfering signals
                                p = 0;
                            else % No interference
                                p = 1;
                            end
                        end

                        if numInterferers==0 && (obj.RxSubFrameCount ~= obj.NoOfSubFrames) && (obj.WLANSignal.Metadata.PayloadInfo(obj.RxSubFrameCount+1).NumOfBits==currentPayloadInfo.NumOfBits)
                        % If no interference and the number of payload bits
                        % is the same in the next data segment, then cache
                        % data segment probability of success for next
                        % segment - this assumes the channel has not
                        % changed
                            obj.UsePacketSuccessProbCache = true;
                            obj.PacketSuccessProbCache = p;
                        else
                            % Otherwise do not cache
                            obj.UsePacketSuccessProbCache = false;
                        end
                    end
                    % Pick a random number and compare against the
                    % packet success rate. If the packet success rate
                    % is 0.9, it means that 90 percent of packets get
                    % successfully decoded and 10 percent are not
                    % decoded because of packet errors.
                    randNum = rand(1);
                    if (p > randNum)
                        isDecodable = true;
                    else
                        isDecodable = false;
                    end

                    if ~isDecodable && (obj.NoOfSubFrames > 0) % Payload is not decodable
                        % Flip the CRC of current subframe/frame
                        if obj.WLANSignal.MACFrame.IsEmpty
                            % Converting byte indexing to bit indexing for
                            % start and end indices
                            startIndex = (obj.SubFrameIndices(obj.RxSubFrameCount)-1) * 8 + 1;
                            endIndex = (startIndex + obj.SubFrameLengths(obj.RxSubFrameCount) * 8) - 1;
                            obj.WLANSignal.Waveform(endIndex - 1 : endIndex, 1) = ...
                                ~obj.WLANSignal.Waveform(endIndex -1 : endIndex, 1);
                        else % Abstracted MAC
                            % Mark FCS fail for the MAC subframe
                            obj.WLANSignal.MACFrame.FCSPass(obj.RxSubFrameCount, obj.UserIndexSU) = false;
                            obj.WLANSignal.MACFrame.DelimiterFails(obj.RxSubFrameCount, obj.UserIndexSU) = true;
                        end
                    else
                        if ~obj.WLANSignal.MACFrame.IsEmpty % Abstracted MAC
                            % Mark FCS pass for the MAC subframe
                            obj.WLANSignal.MACFrame.FCSPass(obj.RxSubFrameCount, obj.UserIndexSU) = true;
                            obj.WLANSignal.MACFrame.DelimiterFails(obj.RxSubFrameCount, obj.UserIndexSU) = false;
                        end
                    end

                    % If all subframes are done or there are no
                    % subframes, schedule RXEND event to MAC and remove
                    % interference
                    if (obj.RxSubFrameCount == obj.NoOfSubFrames) || (obj.NoOfSubFrames == 0)
                        if ~obj.WLANSignal.MACFrame.IsEmpty % Abstracted MAC
                            macFrameCFG = obj.WLANSignal.MACFrame;
                        else % Full MAC
                            obj.RxData(1: obj.RxDataLength * 8, obj.UserIndexSU) =...
                                obj.WLANSignal.Waveform(1:obj.RxDataLength * 8, obj.UserIndexSU);
                            rxData = obj.RxData;
                        end
                        indicationToMAC.IsEmpty = false;
                        indicationToMAC.MessageType = hPHYPrimitives.RxEndIndication;
                        obj.RxSubFrameCount = 0;
                        obj.SignalDecodeStage = 3;
                        obj.ReceptionTimer = 0;
                        rxDataLength = obj.RxDataLength;

                        frameToMAC.IsEmpty = false;
                        frameToMAC.MACFrame(obj.UserIndexSU) = macFrameCFG;
                        frameToMAC.Data = rxData;
                        frameToMAC.PSDULength(obj.UserIndexSU) = rxDataLength;
                        frameToMAC.Timestamp = obj.WLANSignal.Metadata.Timestamp;
                        frameToMAC.SequenceNumbers = obj.WLANSignal.Metadata.SequenceNumbers;
                        frameToMAC.NumSubframes(obj.UserIndexSU) = obj.NoOfSubFrames;
                        
                        % Update the statistics
                        obj.PhyRx = obj.PhyRx + 1;
                        obj.PhyRxBytes = obj.PhyRxBytes + rxDataLength;
                    else
                        % If not all subframes are done, schedule
                        % the end of next subframe payload
                        delayForNextSubFrame = ...
                            obj.WLANSignal.Metadata.PayloadInfo(obj.RxSubFrameCount+1).Duration + ...
                            obj.WLANSignal.Metadata.PayloadInfo(obj.RxSubFrameCount+1).OverheadDuration;
                        obj.ReceptionTimer = delayForNextSubFrame;
                        obj.SignalDecodeStage = 2; % Decode payload of next subframe
                    end

                case 3
                    % Remove the processing waveform from stored
                    % buffer when its duration is completed
                    obj.UsePacketSuccessProbCache = false;
                    obj.SignalDecodeStage = 0; % Reset
                    obj.ReceptionTimer = 0; % Reset
                    obj.SignalOfInterest = obj.SignalBufferDefault; % Reset
                    obj.TotalRxInterferenceTime = obj.TotalRxInterferenceTime + getInterferenceTime(obj.Interference);
                    resetInterferenceLogTime(obj.Interference); % Reset interference log time for next signal of interest
            end
        end

        % Update the interference after calculating the probability of
        % packet segment success. This ensures any interference finishing
        % at the same time as the packet segment is included.
        updateSignalBuffer(obj.Interference, obj.CurrentTime);

        % Get the indication to MAC
        if obj.RxOn && (obj.SignalDecodeStage == 0 || isSignalReceived) && indicationToMAC.IsEmpty
            indicationToMAC = getIndicationToMAC(obj);
        end

        nextInvokeTime = getNextInvokeTime(obj);
    end
    
    function setPHYMode(obj, phyMode)
    %setPHYMode Handle the PHY mode set request from the MAC layer
    %
    %   setPHYMode(OBJ, PHYMODE) handles the PHY mode set request from
    %   the MAC layer.
    %
    %   PHYMODE is an input structure from MAC layer to configure the
    %   PHY Rx mode.
    %
    %   Structure 'PHYMODE' contains the following fields:
    %
    %   IsEmpty           - Logical value, that defines whether the PHY
    %                       mode structure is empty or not.
    %   PHYRxOn           - Logical value, that defines whether the PHY Rx
    %                       is on or not
    %   EnableSROperation - Logical value, that defines whether the SR
    %                       operation is enabled or not.
    %   BSSColor          - Basic service set color (Used to differentiate
    %                       signals as Intra-BSS/Intra-BSS). Type double
    %   OBSSPDThreshold   - Overlapping BSS packet detect threshold. Type
    %                       double

        % Set PHY mode
        obj.RxOn = phyMode.PHYRxOn;
        
        % Set spatial reuse parameters
        obj.EnableSROperation = phyMode.EnableSROperation;
        if obj.EnableSROperation
            obj.BSSColor = phyMode.BSSColor;
            obj.OBSSPDThreshold = phyMode.OBSSPDThreshold;
        end
    end
end

methods (Access = private)
    function status = isFrameIgnorable(obj, sigPower)
    %isFrameIgnorable Return true if a frame is decoded as inter-BSS
    %frame and the signal power is less than OBSS PD threshold
    %otherwise return false.

        status = false;
        
        % Update PHY Rx statistics
        if obj.RxFrameFormat == hFrameFormats.HE_SU || obj.RxFrameFormat == hFrameFormats.HE_EXT_SU
            if obj.BSSColor ~= obj.RxBSSColor % Frame is inter-BSS
                obj.PhyNumInterFrames = obj.PhyNumInterFrames + 1;
                if sigPower < obj.OBSSPDThreshold
                    status = true;
                    obj.PhyNumInterFrameDrops = obj.PhyNumInterFrameDrops + 1;
                else
                    obj.EnergyDetectionGreaterThanOBSSPD = obj.EnergyDetectionGreaterThanOBSSPD + 1;
                end
            else % Frame is intra-BSS
                obj.PhyNumIntraFrames = obj.PhyNumIntraFrames + 1;
            end
        end
    end

    function indicationToMAC = getIndicationToMAC(obj)
    %getIndicationToMAC Return indication to MAC

        indicationToMAC = obj.RxVector;
        indicationToMAC.IsEmpty = true;

        % If the total signal power is greater than or equal to
        % EDthreshold when PHY receiver is invoked, indicate CCA Busy
        % to MAC.
        totalSignalPower = getTotalSignalPower(obj.Interference)+obj.SignalOfInterest.RxPower;
        if (totalSignalPower >= obj.EDThresoldInWatts) && obj.CCAIdle
            indicationToMAC.IsEmpty = false;
            indicationToMAC.MessageType = hPHYPrimitives.CCABusyIndication;
            indicationToMAC.ChannelBandwidth = obj.ChannelBandwidth;
            obj.CCAIdle = 0;
        end

        % If the total signal power results in zero or less than ED
        % threshold, indicate CCA idle to MAC layer
        if (totalSignalPower < obj.EDThresoldInWatts) && ~obj.CCAIdle
            indicationToMAC.IsEmpty = false;
            indicationToMAC.MessageType = hPHYPrimitives.CCAIdleIndication;
            indicationToMAC.ChannelBandwidth = obj.ChannelBandwidth;
            obj.LimitTxPower = false;
            obj.CCAIdle = 1;
        end
    end

    function updateVisualization(obj, wlanSignal)
    % Total duration of the waveform

        coder.extrinsic('hPlotStateTransition');
    
        ppduDuration = wlanSignal.Metadata.PreambleDuration + ...
            wlanSignal.Metadata.HeaderDuration + wlanSignal.Metadata.PayloadDuration;
        
        % Plot state transition with the waveform duration
        if any(obj.NodeID == wlanSignal.Metadata.Vector.StationIDs) || (obj.NodeID == (obj.NumberOfNodes+2))
            hPlotStateTransition([obj.NodeID obj.OperatingFreqID], 5, ...
                obj.CurrentTime, ppduDuration, obj.NumberOfNodes);
        else
            hPlotStateTransition([obj.NodeID obj.OperatingFreqID], 3, ...
                obj.CurrentTime, ppduDuration, obj.NumberOfNodes);
        end
    end
    
    function nextInvokeTime = getNextInvokeTime(obj)
    %nextInvokeTime Return next invoke time
        
        nextInvokeTime = -1;
        nextInterferenceTime = obj.Interference.TimeUntilNextSignalUpdate - obj.CurrentTime;
        
        if nextInterferenceTime > 0 && obj.SignalDecodeStage ~= 0
            nextInvokeTime = min(obj.ReceptionTimer, nextInterferenceTime);
        elseif nextInterferenceTime > 0
            nextInvokeTime = nextInterferenceTime;
        elseif obj.SignalDecodeStage ~= 0
            nextInvokeTime = obj.ReceptionTimer;
        end
    end

    function updateWaveformEntry(obj, wlanSignal)
    %updateWaveformEntry Updates the new entry of WLAN signal in a buffer
    %with each column containing transmitting node ID, received signal
    %power in dBm, its reception absolute (in simulation time stamp) end
    %time. Considers the frame for processing or ignores the frame
    %(consider as interfered signal) based on ED Threshold, CCA Idle and
    %RxOn conditions

        % Initialize transmit power limit flag
        obj.LimitTxPower = false;

        % Assign start time of the signal entry
        wlanSignal.Metadata.StartTime = obj.CurrentTime;

        % Apply Rx Gain
        wlanSignal.Metadata.SignalPower = wlanSignal.Metadata.SignalPower + obj.RxGain;

        isSignalDecodable = false;
        
        if obj.RxOn % Receiver antenna is switched on
            if obj.CCAIdle == 1
                if wlanSignal.Metadata.SignalPower >= obj.EDThreshold
                    updateVisualization(obj, wlanSignal); % Update the MAC state transition plot
                    % Store the received waveform
                    obj.WLANSignal = wlanSignal;
                    % Update the signal decode stage and signal processing
                    % flag
                    obj.SignalDecodeStage = 1;
                    isSignalDecodable = true;
                    % Set the reception timer to preamble + header duration
                    obj.ReceptionTimer = obj.WLANSignal.Metadata.PreambleDuration+...
                        obj.WLANSignal.Metadata.HeaderDuration;
                    if getTotalNumOfSignals(obj.Interference) > 0
                        % Log the interference time (pre-existing interference < EDThreshold)
                        logInterferenceTime(obj.Interference, obj.WLANSignal);
                    end
                else
                    % Signal power of the current individual waveform is
                    % less than ED threshold
                    obj.EnergyDetectionsLessThanED = obj.EnergyDetectionsLessThanED + 1;
                    % Update PHY Rx drop counter
                    obj.PhyRxDrop = obj.PhyRxDrop + 1;
                end
            else
                % Waveform is received when the node is already in
                % receive state
                obj.PhyRxDrop = obj.PhyRxDrop + 1;
                obj.RxTriggersWhilePrevRxIsInProgress = obj.RxTriggersWhilePrevRxIsInProgress + 1;
                % Log the interference time
                logInterferenceTime(obj.Interference, obj.WLANSignal, wlanSignal);
            end
        else % Receiver antenna is switched off (Transmission is in progress)
            obj.PhyRxDrop = obj.PhyRxDrop + 1;
            obj.RxTriggersWhileTxInProgress = obj.RxTriggersWhileTxInProgress + 1;
        end

        % Update the signal buffers
        if isSignalDecodable
            % Store the sender node ID, the corresponding Rx signal power
            % and the end times of the received waveform.
            obj.SignalOfInterest.SourceID = wlanSignal.Metadata.SourceID;
            obj.SignalOfInterest.RxPower = power(10.0, (wlanSignal.Metadata.SignalPower - 30)/ 10.0); % Convert to watts from dBm
            % Total duration of the waveform
            ppduDuration = wlanSignal.Metadata.PreambleDuration + wlanSignal.Metadata.HeaderDuration + ...
                wlanSignal.Metadata.PayloadDuration;
            obj.SignalOfInterest.EndTime = ppduDuration + wlanSignal.Metadata.StartTime;
            obj.SignalOfInterest.Metadata = extractMetadata(wlanSignal); 
        else
            % Add signal to the interference buffer list
            addSignal(obj.Interference, wlanSignal);
        end
    end
    
    function assignTgaxAbstractionFlag(obj, value)
        if strcmp(value, 'TGax Simulation Scenarios MAC Calibration')
            obj.AbstractionTypeTGAXAppendix1 = false;
        end
    end
    
    function fields = getCurrentFieldSet(obj,signalOfIntersetField,sigSet)
        % Returns an array of strings describing the active field of the
        % signal of interest and the active field of any interfering
        % signals at the current time.
        
        numInt = numel(sigSet);
        fields = strings(numInt+1,1);
        fields(1) = signalOfIntersetField;

        % Find current field of interferers
        possibleFields = ["preamble" "data"];
        for i = 1:numInt
            startTime = sigSet(i).Metadata.StartTime;
            % Get the start time of each section
            fieldStartTimes = [startTime; ...
                startTime+sigSet(i).Metadata.PreambleDuration+sigSet(i).Metadata.HeaderDuration];
            % Find the field which started before or on the current time
            % (as interference model assumed any signal active at this
            % current time applies to the segment of interest)
            fieldStarted = fieldStartTimes <= obj.CurrentTime;
            idx = find(fieldStarted,1,'last');
            fields(i+1) = possibleFields(idx);
        end
    end

    function configs = getConfigSet(obj,sigSet)
        % Returns a cell array of PHY configuration objects for the signal
        % of interest and any interfering signals.
        
        numInt = numel(sigSet);
        totalNumSig = 1+numInt;
        configs = cell(1,totalNumSig);

        % Signal of interest
        configs{1} = signalToPHYConfig(obj,obj.SignalOfInterest);

        % Interference
        for i = 1:numInt
            configs{i+1} = signalToPHYConfig(obj,sigSet(i));
        end
    end
    
    function cfg = signalToPHYConfig(obj,signal)
        % Return a PHY configuration object, set with signal metadata
        
        % Get a copy of the appropriate PHY configuration object for the signal
        cfg = getPHYConfig(obj,signal.Metadata.FrameFormat);

        % Configure with metadata
        cfg.ChannelBandwidth = getChannelBandwidthStr(obj,signal.Metadata.ChannelBandwidth);
        switch signal.Metadata.FrameFormat
            case hFrameFormats.NonHT
                cfg.NumTransmitAntennas = signal.Metadata.NumTransmitAntennas;
            case hFrameFormats.HTMixed
                cfg.NumTransmitAntennas = signal.Metadata.NumTransmitAntennas;
                cfg.NumSpaceTimeStreams = signal.Metadata.NumSpaceTimeStreams(obj.UserIndexSU);
            case hFrameFormats.VHT
                cfg.NumTransmitAntennas = signal.Metadata.NumTransmitAntennas;
                cfg.NumSpaceTimeStreams = signal.Metadata.NumSpaceTimeStreams(obj.UserIndexSU);
            case {hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU}
                cfg.NumTransmitAntennas = signal.Metadata.NumTransmitAntennas;
                cfg.NumSpaceTimeStreams = signal.Metadata.NumSpaceTimeStreams(obj.UserIndexSU);
        end
    end
    
    function cfg = getPHYConfig(obj,frameFormat)
        % Return a copy of one of the pre-created PHY configuration objects
        switch frameFormat
            case hFrameFormats.NonHT
                cfg = obj.NonHTConfig;
            case hFrameFormats.HTMixed
                cfg = obj.HTConfig;
            case hFrameFormats.VHT
                cfg = obj.VHTConfig;
            case {hFrameFormats.HE_SU,hFrameFormats.HE_EXT_SU}
                cfg = obj.HESUConfig;
        end
    end
    
    function cbwStr = getChannelBandwidthStr(~, cbw)
        %getChannelBandwidthStr Return the channel bandwidth in string format
        
        switch cbw
            case 20
                cbwStr = 'CBW20';
            case 40
                cbwStr = 'CBW40';
            case 80
                cbwStr = 'CBW80';
            case 160
                cbwStr = 'CBW160';
            otherwise
                error('Unsupported channel bandwidth');
        end
    end
end
end

function s = signalMetadataPrototype()
    % Return the default structure of useful metadata
    
    s = struct( ...
    'StartTime', 0, ...
    'PreambleDuration', 0, ...
    'HeaderDuration', 0, ...
    'PayloadDuration', 0, ...
     ... % TXVECTOR
    'FrameFormat',0,...
    'ChannelBandwidth',0, ...
    'NumTransmitAntennas',0, ...
    'NumSpaceTimeStreams',0);
end
        
function s = extractMetadata(wlanSignal)
    % Return a structure of useful metadata from a wlanSignal

    s = signalMetadataPrototype();
    ... % Metadata
    s.StartTime = wlanSignal.Metadata.StartTime;
    s.PreambleDuration = wlanSignal.Metadata.PreambleDuration;
    s.HeaderDuration = wlanSignal.Metadata.HeaderDuration;
    s.PayloadDuration = wlanSignal.Metadata.PayloadDuration;
     ... % TXVECTOR
    s.FrameFormat = wlanSignal.Metadata.Vector.FrameFormat;
    s.ChannelBandwidth = wlanSignal.Metadata.Vector.ChannelBandwidth;
    s.NumTransmitAntennas = wlanSignal.Metadata.Vector.NumTransmitAntennas;
    s.NumSpaceTimeStreams = wlanSignal.Metadata.Vector.NumSpaceTimeStreams;
end
