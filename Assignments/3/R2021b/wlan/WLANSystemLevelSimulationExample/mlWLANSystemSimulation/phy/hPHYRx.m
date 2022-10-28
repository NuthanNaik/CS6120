classdef hPHYRx < hPHYRxInterface
%hPHYRx Create an object for WLAN PHY receiver
%   WLANPHYRX = hPHYRx creates a WLAN PHY Receiver object for PHY decoding.
%
%   WLANPHYRX = hPHYRx(Name, Value) creates a WLAN PHY Receiver object with
%   the specified property Name set to the specified Value. You can specify
%   additional name-value pair arguments in any order as (Name1, Value1,
%   ..., NameN, ValueN).
%
%   hPHYRx methods:
%
%   run         - Run the physical layer receive operations
%   setPHYMode  - Handle the PHY mode set request from the MAC layer
%
%   hPHYRx properties:
%
%   NodeID              - Node identifier of the receiving WLAN node
%   NumberOfNodes       - Number of nodes from which signal might come
%   EDThreshold         - Energy detection threshold in dBm
%   RxGain              - Receiver gain in dB
%   RxNoiseFigure       - Receiver noise figure in dB

%   Copyright 2021 The MathWorks, Inc.

properties
    %RxNoiseFigure Receiver noise figure in dB
    RxNoiseFigure = 7;
end

properties (Hidden)
    %MaxSubframes Maximum number of subframes that can be present in an
    %A-MPDU
    MaxSubframes = 64;

    %ChannelBandwidth Channel bandwidth
    ChannelBandwidth = 20;

    %ChannelBandwidthStr Channel bandwidth in string format
    ChannelBandwidthStr = 'CBW20';
end

% Information specific to a WLAN signal currently being decoded
properties (Access = private)
    % WLAN frame format of the signal being decoded
    RxFrameFormat;

    % CCA idle flag. This will be set to true when channel is idle, i.e. No
    % energy detected in the channel.
    CCAIdle = true;

    % Timer for receiving preamble and header, payload of a WLAN waveform
    % (in microseconds). When preamble & header is being received, it
    % contains the time till end of that preamble. While receiving
    % a subframe / payload, it contains the corresponding end time.
    ReceptionTimer = 0;

    % Stores the signal power of the waveform being decoded in watts
    RxSignalPowerInWatts

    % User index for single user processing. Index '1' will be used in
    % case of single user and downlink multi-user reception. Indices
    % greater than '1' will be used in case of downlink multi-user
    % transmission and uplink multi-user reception.
    UserIndexSU = 1;

    % Boolean value, used to indicate that during the reception of the
    % PPDU, the PPDU was dropped due to a condition set in the
    % PHYCONFIG.
    FilteredPPDU = false;
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

    % HE-MU configuration object
    HEMUConfig;
end

properties (Constant, Hidden)
    % Maximum number of users in a Rx MU-PPDU. In 20 MHz OFDMA
    % transmission max possible users are 9
    MaxMUUsers = 9;
end

properties (SetAccess = private, Hidden)
    % Received WLAN waveform
    WLANSignal;

    % Structure holding metadata for the received packet
    Metadata;

    % SignalDecodeStage Decoding stage of the WLAN waveform reception
    % 0 - Waveform processing not started
    % 1 - Process the end of preamble
    % 2 - Process the end of header
    % 3 - Process the end of actively received payload / MPDU in an AMPDU
    % 4 - End of waveform duration and so signal has to be removed
    SignalDecodeStage = 0;

    % Interference object
    Interference;
end

properties (Hidden)
    % Flag to indicate whether receiver antenna is on
    RxOn = true;

    % Structure of Rx-Vector with different fields
    RxVector;

    % Structure holding the MAC frame properties
    MACFrameCFG;

    % Structure holding the MAC frame and its metadata
    EmptyFrame;

    % Structure holding the configuration for PHY mode. This is an input
    % structure from MAC to configure the PHY Rx mode.
    PHYMode = struct('IsEmpty', true, ...
        'PHYRxOn', true, ...
        'EnableSROperation', 0, ...
        'BSSColor', 0, ...
        'OBSSPDThreshold', 0);

    % Current simulation time in microseconds
    CurrentTime = 0;

    % Operating frequency ID
    OperatingFreqID = 1;

    % Frequency of operation in GHz
    OperatingFrequency = 5.180;
end

% Pre-computed constants
properties(Access = private)
    % Buffer to hold the received waveform (PPDU)
    RxPPDU;

    % Length of the received PSDU
    RxPSDULength = 0;

    % HE recovery configuration object
    RxHERecoveryConfig;

    % HE channel estimate
    ChannelEstimatePreHE;

    % Channel estimation
    ChannelEstimate;

    % Pilot estimation
    PilotEstimate;

    % Non-HT channel estimation calculated using L-LTF
    ChannelEstimateNonHT = complex(zeros(52,1), 0);

    % Noise variance calculated using L-LTF
    NoiseVarianceNonHT = 0;

    % Noise variance of the received frame calculated based on frame format
    NoiseVariance = 0;

    % Demodulated L-LTF
    RecoveredLLTF = complex(zeros(52,2), 0);

    % Sample rate of the received signal
    SampleRate;

    % Current processing offset of the received waveform
    PacketOffset = 0;

    % HE demodulated data symbols
    HEDemodSym;

    % HE RU mapping index
    HERUMappingInd;

    % MCS of the received PPDU
    MCS;

    % Number of space time streams
    NumSTS;

    % Number of antennas
    NumAntennas;

    % Number of users in the received PPDU
    NumUsers;

    % HE user configuration object of the Rx PPDU
    HEUserConfig;

    % Station IDs in MU PPDU
    RxStationIDs ;

    % Flag to decode HE data field
    DecodeHEData = false;

    % Start and end indices of the payload
    PayloadIndices
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
    function obj = hPHYRx(varargin)
        % Perform one-time calculations, such as computing constants

        % Name-value pairs
        for idx = 1:2:numel(varargin)
            obj.(varargin{idx}) = varargin{idx+1};
        end

        obj.ChannelBandwidthStr = obj.getChannelBandwidthStr(obj.ChannelBandwidth);
        % Initialize frame config parameters
        obj.NonHTConfig = wlanNonHTConfig('ChannelBandwidth', obj.ChannelBandwidthStr);
        if obj.ChannelBandwidth < 80
            obj.HTConfig = wlanHTConfig('ChannelBandwidth', obj.ChannelBandwidthStr);
        end
        obj.VHTConfig = wlanVHTConfig('ChannelBandwidth',obj.ChannelBandwidthStr,'ChannelCoding','BCC','GuardInterval','Long');
        obj.HESUConfig = wlanHESUConfig('ChannelBandwidth', obj.ChannelBandwidthStr);

        % Initialize
        obj.Interference = hInterference('BufferSize', 2*obj.NumberOfNodes);
        obj.EDThresoldInWatts = power(10.0, (obj.EDThreshold - 30)/ 10.0); % Convert from dBm to watt

        % Initialize channel parameters
        obj.ChannelEstimatePreHE = complex(zeros(1, 0, 0), 0);
        obj.HEDemodSym = repmat({complex(zeros(1, 0), 0)}, obj.MaxMUUsers, 1);
        obj.ChannelEstimate = complex(zeros(1, 0));
        obj.PilotEstimate = complex(zeros(1, 0));
        obj.RxHERecoveryConfig = wlanHERecoveryConfig('ChannelBandwidth', obj.ChannelBandwidthStr, ...
            'STBC', 0, 'GuardInterval', 3.2, 'HELTFType', 4, 'BSSColor', 0, 'SpatialReuse', 0, ...
            'HighDoppler', 0, 'RUSize', 242, 'RUIndex', 1, 'DCM', 0, 'ChannelCoding', 'LDPC', ...
            'PreHESpatialMapping', 0, 'NumSpaceTimeStreams', 1, 'NumHELTFSymbols', 1, ...
            'TXOPDuration', 127, 'UplinkIndication', 0);
        obj.SampleRate = (obj.ChannelBandwidth)*1e6;

        % Form WLAN signal
        obj.MACFrameCFG = struct('IsEmpty', true, ...
            'FrameType', 'Data', ...
            'FrameFormat', 'Non-HT', ...
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

        obj.Metadata = struct('Vector', obj.RxVector, ...
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
            'Timestamp', zeros(obj.MaxSubframes, 9), ...
            'SequenceNumbers', zeros(obj.MaxSubframes, 9));

        obj.WLANSignal = struct('IsEmpty', true, ...
            'Waveform', [], ...
            'Metadata', obj.Metadata, ...
            'MACFrame', obj.MACFrameCFG);

        % Initialize recovery parameters with default values to support
        % codegen
        obj.NumUsers = 1;
        obj.HEUserConfig = obj.RxHERecoveryConfig;
        obj.MCS = zeros(obj.MaxMUUsers, 1);
        obj.RxPSDULength = zeros(obj.MaxMUUsers, 1);
        obj.RxStationIDs = zeros(obj.MaxMUUsers, 1);
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
        %                         format, specified as a string scalar or an
        %                         enum. If FrameFormat is specified as a string
        %                         scalar, specify this value as one of these:
        %                         "NonHT", "HTMixed", "VHT" , "HE_SU",
        %                         "HE_EXT_SU", or "HE_MU". If FrameFormat is
        %                         specified as an enum, see
        %                         <ahref="matlab:help('hFrameFormats')">hFrameFormats</a>
        %                         class for valid input values.
        %   AggregatedMPDU      - Logical flag that represents whether the
        %                         MPDU aggregation is enabled or not
        %   ChannelBandwidth    - Bandwidth of the channel
        %   MCSIndex            - Modulation coding scheme index in range [0, 9]
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

        coder.extrinsic('edcaPlotStats');
        narginchk(2,3);

        frameToMAC = obj.EmptyFrame;

        indicationToMAC = obj.RxVector;
        indicationToMAC.IsEmpty = true;
        isSignalReceived = false;

        if ~wlanSignal.IsEmpty
            isSignalReceived = true; % A new WLAN waveform is received
            % Create an entry for every received signal
            updateWaveformEntry(obj, wlanSignal);
        end

        % Update the reception timer
        obj.ReceptionTimer = obj.ReceptionTimer - elapsedTime;

        % Reception of the decodable signal (or its part) is completed
        if obj.ReceptionTimer <= 0
            numRx = obj.NumAntennas;
            startTime = obj.WLANSignal.Metadata.StartTime;
            samplesPerUs = obj.SampleRate*(1/1e6); % Number of samples per microsecond
            switch(obj.SignalDecodeStage)
                case 1 % Started receiving a waveform (endPreamble)
                    thermalNoiseInWatts = calculateThermalNoise(obj);

                    % Calculated SINR and signal power.
                    signalPower = obj.WLANSignal.Metadata.SignalPower - 30; % Convert from dBm to dBw
                    snr = signalPower - (10*log10(thermalNoiseInWatts));

                    % Apply noise on the waveform using AWGN channel.
                    obj.RxPPDU(:, :) = awgn(obj.RxPPDU(:, :),snr,signalPower);

                    % Extract preamble duration and field indices in Rx waveform
                    preambleDuration = obj.WLANSignal.Metadata.PreambleDuration;
                    preambleStartIndex = 1;
                    preambleEndIndex = preambleStartIndex + preambleDuration*samplesPerUs - 1;

                    % Get the resultant signal
                    obj.RxPPDU(preambleStartIndex:preambleEndIndex, (1:numRx)) ...
                        = getResultantWaveform(obj.Interference, obj.RxPPDU(preambleStartIndex:preambleEndIndex, (1:numRx)), startTime, preambleDuration, obj.SampleRate);

                    % Decode PHY preamble
                    [isValidPreamble, obj.RxPPDU] = obj.decodePreamble(obj.RxPPDU);

                    if isValidPreamble

                        % If preamble is successfully decoded, give
                        % RX-START indication to MAC and schedule a header
                        % decoding event
                        obj.SignalDecodeStage = 2;
                        obj.ReceptionTimer = obj.WLANSignal.Metadata.HeaderDuration;
                    else
                        % If preamble decoding is failed, give RX-ERROR
                        % indication to MAC and schedule a remove
                        % interference event at the end of the frame
                        % duration
                        payloadAndHeaderDuration = obj.WLANSignal.Metadata.Duration - preambleDuration;
                        obj.SignalDecodeStage = 4;
                        obj.ReceptionTimer = payloadAndHeaderDuration;
                        indicationToMAC = obj.WLANSignal.Metadata.Vector;
                        indicationToMAC.IsEmpty = false;
                        indicationToMAC.MessageType = hPHYPrimitives.RxErrorIndication;
                        % Update PHY Rx statistics
                        obj.PhyPreambleDecodeFailures = obj.PhyPreambleDecodeFailures + 1;
                        obj.PhyRxDrop = obj.PhyRxDrop + 1;
                    end

                case 2 % Preamble successfully decoded (endHeader)
                    preambleDuration = obj.WLANSignal.Metadata.PreambleDuration;
                    startTime = startTime + preambleDuration;

                    % Extract header duration and field indices in Rx waveform
                    headerDuration = obj.WLANSignal.Metadata.HeaderDuration;
                    headerStartIndex = preambleDuration*samplesPerUs + 1;
                    headerEndIndex = headerStartIndex + headerDuration*samplesPerUs - 1;

                    % Get the resultant signal
                    obj.RxPPDU(headerStartIndex:headerEndIndex, (1:numRx)) = ...
                        getResultantWaveform(obj.Interference, obj.RxPPDU(headerStartIndex:headerEndIndex, (1:numRx)), startTime, headerDuration, obj.SampleRate);

                    % Decode PHY header
                    isValidHeader = obj.decodeHeader(obj.RxPPDU);

                    indicationToMAC = obj.WLANSignal.Metadata.Vector;
                    indicationToMAC.IsEmpty = false;
                    if isValidHeader
                        % If preamble is successfully decoded, give RX-DATA
                        % indication to MAC and schedule a payload recovery
                        % event
                        indicationToMAC.MessageType = hPHYPrimitives.RxStartIndication;

                        if (obj.RxFrameFormat == hFrameFormats.NonHT)
                            % Non-HT frames are always non aggregated
                            aggregatedMPDU = false;
                        elseif (obj.RxFrameFormat == hFrameFormats.HTMixed)
                            % HT frames may be aggregated
                            aggregatedMPDU = obj.HTConfig.AggregatedMPDU;
                        else % VHT/HE
                            % VHT/HE frames are always aggregated
                            aggregatedMPDU = true;
                        end

                        indicationToMAC.AggregatedMPDU = aggregatedMPDU;
                        indicationToMAC.ChannelBandwidth = obj.ChannelBandwidth;
                        indicationToMAC.FrameFormat = obj.RxFrameFormat;
                        indicationToMAC.RSSI = 0;
                        indicationToMAC.StationIDs = obj.RxStationIDs;
                        indicationToMAC.NumSpaceTimeStreams = obj.NumSTS;
                        indicationToMAC.BSSColor = obj.RxBSSColor;
                        indicationToMAC.PSDULength = obj.RxPSDULength;
                        indicationToMAC.MCSIndex = obj.MCS;

                        % Payload duration
                        payloadDuration = obj.WLANSignal.Metadata.Duration - (preambleDuration +...
                            headerDuration);
                        obj.SignalDecodeStage = 3;
                        obj.ReceptionTimer = payloadDuration;

                        % Set the flag 'FilteredPPDU' if the Rx PPDU is an
                        % MU-PPDU not intended to this node
                        %
                        % Reference: IEEE P802.11ax/D8.0 Figure 27.63 -
                        % PHY receive state machine
                        if (obj.RxFrameFormat == hFrameFormats.HE_MU && obj.DecodeHEData == false)
                            obj.FilteredPPDU = true;
                            % Update PHY Rx statistics
                            obj.MUPPDUsDestinedToOthers = obj.MUPPDUsDestinedToOthers + 1;
                            % Set the reception timer to payload duration
                            obj.ReceptionTimer = payloadDuration;
                        end

                        % Set the flag 'FilteredPPDU' if the spatial reuse
                        % feature is enabled and the received PPDU can be
                        % ignored
                        %
                        % Reference: IEEE P802.11ax/D8.0 Figure 27.63 -
                        % PHY receive state machine
                        if(obj.EnableSROperation && isFrameIgnorable(obj, obj.WLANSignal.Metadata.SignalPower))
                            obj.FilteredPPDU = true;

                            % Start of transmit power limitation period
                            obj.LimitTxPower = true;
                            indicationToMAC.LimitTxPower = true;

                            % Set the reception timer to 0
                            obj.ReceptionTimer = 0;

                            % Add signal to the interference buffer list
                            addSignal(obj.Interference, obj.WLANSignal);
                        end
                    else
                        % If header decoding is failed, give RX-ERROR
                        % indication to MAC and schedule a remove
                        % interference event at the end of the frame
                        % duration
                        payloadDuration = obj.WLANSignal.Metadata.Duration - (preambleDuration +...
                            headerDuration);
                        obj.SignalDecodeStage = 4;
                        indicationToMAC.MessageType = hPHYPrimitives.RxErrorIndication;
                        obj.ReceptionTimer = payloadDuration;
                        % Update PHY Rx statistics
                        obj.PhyHeaderDecodeFailures = obj.PhyHeaderDecodeFailures + 1;
                        obj.PhyRxDrop = obj.PhyRxDrop + 1;
                    end

                case 3 % Header successfully decoded (endPayload)
                    indicationToMAC.IsEmpty = false;
                    if obj.FilteredPPDU
                        indicationToMAC.MessageType = hPHYPrimitives.RxEndIndication;
                    else
                        carrierLost = false;
                        preambleHeaderDuration = obj.WLANSignal.Metadata.PreambleDuration + obj.WLANSignal.Metadata.HeaderDuration;
                        startTime = startTime + preambleHeaderDuration;

                        % Extract data duration and field indices in Rx waveform
                        dataDuration = obj.WLANSignal.Metadata.PayloadDuration;
                        dataStartIndex = (preambleHeaderDuration)*samplesPerUs + 1;
                        dataEndIndex = dataStartIndex + dataDuration*samplesPerUs - 1;

                        % Extract data field indices in Rx waveform
                        if obj.RxFrameFormat == hFrameFormats.NonHT
                            dataIndices = wlanFieldIndices(obj.NonHTConfig, 'NonHT-Data');
                        elseif obj.RxFrameFormat == hFrameFormats.HTMixed
                            dataIndices = wlanFieldIndices(obj.HTConfig, 'HT-Data');
                        elseif obj.RxFrameFormat == hFrameFormats.VHT
                            dataIndices = wlanFieldIndices(obj.VHTConfig, 'VHT-Data');
                        else % HE_SU or HE_EXT_SU
                            dataIndices = uint32(wlanFieldIndices(obj.HEUserConfig, 'HE-Data'));
                        end

                        % Set carrier lost flag as true if the expected
                        % data indices do not match with actual data
                        % indices in waveform
                        if (dataIndices(1) ~= dataStartIndex) || (dataIndices(2) ~= dataEndIndex)
                            carrierLost = true;
                        end

                        if ~carrierLost
                            % Get the resultant signal
                            obj.RxPPDU(dataStartIndex:dataEndIndex, (1:numRx)) = ...
                                getResultantWaveform(obj.Interference, obj.RxPPDU(dataStartIndex:dataEndIndex, (1:numRx)), startTime, dataDuration, obj.SampleRate);

                            obj.PayloadIndices = dataIndices;
                            % Recover PSDU from waveform
                            psdu = obj.recoverPayload(obj.RxPPDU);

                            if (obj.RxPSDULength(1) == numel(psdu)/8)
                                frameToMAC.IsEmpty = false;
                                frameToMAC.MACFrame(obj.UserIndexSU) = obj.MACFrameCFG;
                                frameToMAC.Data = psdu(1:end, 1);
                                frameToMAC.PSDULength(obj.UserIndexSU) = obj.RxPSDULength(obj.UserIndexSU);
                                frameToMAC.Timestamp = obj.WLANSignal.Metadata.Timestamp;
                                frameToMAC.SequenceNumbers = obj.WLANSignal.Metadata.SequenceNumbers;
                                frameToMAC.NumSubframes = obj.WLANSignal.Metadata.SubframeCount;

                                % Give RX-END indication, PSDU to MAC and
                                % schedule a remove interference event
                                indicationToMAC.MessageType = hPHYPrimitives.RxEndIndication;
                                obj.PhyRx = obj.PhyRx +1;
                                obj.PhyRxBytes = obj.PhyRxBytes + obj.RxPSDULength(obj.UserIndexSU);
                            else
                                % Unequal PSDU lengths
                                indicationToMAC.MessageType = hPHYPrimitives.RxErrorIndication;
                                obj.PhyRxDrop = obj.PhyRxDrop +1;
                            end
                        else
                            % Carrier lost, give RX-End indication.
                            %
                            % Reference: IEEE P802.11ax/D8.0 Figure 27.63 -
                            % PHY receive state machine
                            indicationToMAC.MessageType = hPHYPrimitives.RxEndIndication;
                            obj.PhyRxDrop = obj.PhyRxDrop +1;
                        end
                    end
                    obj.SignalDecodeStage = 4; % Remove signal
                    obj.ReceptionTimer = 0; % Reset
                case 4
                    % Remove the processing waveform from stored
                    % buffer when its duration is completed
                    obj.SignalDecodeStage = 0; % Reset
                    obj.ReceptionTimer = 0; % Reset
                    obj.RxSignalPowerInWatts = 0;
                    obj.FilteredPPDU = false;
                    obj.TotalRxInterferenceTime = obj.TotalRxInterferenceTime + getInterferenceTime(obj.Interference);
                    resetInterferenceLogTime(obj.Interference); % Reset interference log time for next signal of interest
            end
            % Update the signal buffer after each decode stage
            updateSignalBuffer(obj.Interference, obj.CurrentTime);
        end

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
        if obj.RxFrameFormat == hFrameFormats.HE_SU || obj.RxFrameFormat == hFrameFormats.HE_EXT_SU || ...
                obj.RxFrameFormat == hFrameFormats.HE_MU
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
        totalSignalPowerInWatts = getTotalSignalPower(obj.Interference)+obj.RxSignalPowerInWatts;
        if obj.CCAIdle
            if (totalSignalPowerInWatts >= obj.EDThresoldInWatts)
                indicationToMAC.IsEmpty = false;
                indicationToMAC.MessageType = hPHYPrimitives.CCABusyIndication;
                indicationToMAC.ChannelBandwidth = obj.ChannelBandwidth;
                obj.CCAIdle = false;
            end

        else
            % If the total signal power results in zero or less than ED
            % threshold, indicate CCA idle to MAC layer
            if (totalSignalPowerInWatts < obj.EDThresoldInWatts)
                indicationToMAC.IsEmpty = false;
                indicationToMAC.MessageType = hPHYPrimitives.CCAIdleIndication;
                indicationToMAC.ChannelBandwidth = obj.ChannelBandwidth;
                obj.LimitTxPower = false;
                obj.CCAIdle = true;
            end

            % In case of total signal power is less than OBSS PD threshold,
            % indicate CCA idle to MAC layer.
            if obj.LimitTxPower && totalSignalPowerInWatts < power(10.0, (obj.OBSSPDThreshold - 30)/ 10.0) % Convert OBSS threshold in watts
                indicationToMAC.IsEmpty = false;
                indicationToMAC.MessageType = hPHYPrimitives.CCAIdleIndication;
                indicationToMAC.ChannelBandwidth = obj.ChannelBandwidth;
                obj.CCAIdle = true;
            end
        end
    end

    function updateVisualization(obj, wlanSignal)
        % Update visualization with the waveform duration

        % Total duration of the waveform
        ppduDuration = wlanSignal.Metadata.Duration;

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
        %getNextInvokeTime Return next invoke time

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

        % Assume number of transmitter antennas is same as the receiver
        % antennas
        obj.NumAntennas = wlanSignal.Metadata.Vector.NumTransmitAntennas;

        % Assign start time of the signal entry
        wlanSignal.Metadata.StartTime = obj.CurrentTime;

        % Apply Rx Gain
        scale = 10.^(obj.RxGain/20);
        wlanSignal.Waveform = wlanSignal.Waveform * scale;
        wlanSignal.Metadata.SignalPower = wlanSignal.Metadata.SignalPower + obj.RxGain;

        isSignalDecodable = false;

        % Receiver is switched on
        if obj.RxOn
            if obj.CCAIdle
                if wlanSignal.Metadata.SignalPower >= obj.EDThreshold
                    updateVisualization(obj, wlanSignal); % Update the MAC state transition plot
                    % Store the received waveform
                    obj.WLANSignal = wlanSignal;

                    % Extract the valid streams from the waveform entity
                    obj.RxPPDU = obj.WLANSignal.Waveform(:, (1:obj.NumAntennas));

                    % Update the signal decode stage and signal processing
                    % flag
                    obj.SignalDecodeStage = 1;
                    isSignalDecodable = true;
                    % Set the reception timer to preamble duration
                    obj.ReceptionTimer = obj.WLANSignal.Metadata.PreambleDuration;
                    if getTotalNumOfSignals(obj.Interference) > 0
                        % Log the interference time (pre-existing interference < EDThreshold)
                        logInterferenceTime(obj.Interference, obj.WLANSignal);
                    end
                else
                    % Signal power of the current individual waveform is
                    % less than ED threshold
                    obj.EnergyDetectionsLessThanED = obj.EnergyDetectionsLessThanED + 1;
                end
            else
                % Waveform is received when the node is already in
                % receive state
                obj.RxTriggersWhilePrevRxIsInProgress = obj.RxTriggersWhilePrevRxIsInProgress + 1;
                % Log the interference time
                logInterferenceTime(obj.Interference, obj.WLANSignal, wlanSignal);
            end
        else % Receiver antenna is switched off (Transmission is in progress)
            obj.RxTriggersWhileTxInProgress = obj.RxTriggersWhileTxInProgress + 1;
        end
        if isSignalDecodable
            obj.RxSignalPowerInWatts = power(10.0, (wlanSignal.Metadata.SignalPower - 30)/ 10.0); % Convert to watts from dBm
        else
            % Update PHY Rx statistics
            obj.PhyRxDrop = obj.PhyRxDrop + 1;
            % Add signal to the interference buffer list
            addSignal(obj.Interference, wlanSignal);
        end
    end

    function s = extractMetadata(~)
        s = [];
    end
end

% Static helper methods for waveform decode
methods (Static, Access = private)
    function cbwStr = getChannelBandwidthStr(cbw)
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

    function [MCS, PSDULength, fail] = helperInterpretLSIG(bits)
        %helperInterpretLSIG Interpret recovered L-SIG bits
        %   [MCS,PSDULENGTH,FAIL] = helperInterpretLSIG(BITS) interprets
        %   the recovered L-SIG bits and returns the recovered MCS and PSDU
        %   length. FAIL is true if the recovered contents is not valid and
        %   false otherwise.
        % Rate and length are determined from bits
        rate = double(bits(1:3));
        length = double(bits(5+(1:12)));

        % MCS rate table for 802.11a
        R = wlan.internal.nonHTRateSignalBits();
        MCS = find(all(bsxfun(@eq,R(1:3,:),rate)))-1;
        PSDULength = hPHYRx.binaryToDecimal(length.');

        % Check for invalid parameters
        fail = PSDULength==0;
    end

    function decimalVal = binaryToDecimal(binaryVal)
        %binaryToDecimal Convert binary to decimal

        decimalVal = 0;
        mul = 1;
        for idx = 1:numel(binaryVal)
            decimalVal = decimalVal + mul*binaryVal(idx);
            mul = mul*2;
        end
    end
end

% Waveform decode methods
methods (Access = private)
    function format = formatDetect(obj, rxPPDU, chEst, noiseVar)
        %formatDetect Returns the format of the rxPPDU

        tLSTF = 8e-6; % L-STF duration in seconds
        tLLTF = 8e-6; % L-LTF duration in seconds
        % Format detection using 16 us following L-LTF
        fmtDetInd = obj.PacketOffset+(tLSTF+tLLTF)*obj.SampleRate+(1:16e-6*obj.SampleRate);
        fmtDetectBuffer = zeros(16e-6*obj.SampleRate,size(rxPPDU,2));
        missingIndices = fmtDetInd>size(rxPPDU,1); % Small packet in waveform may not have enough samples for HE detection
        fmtDetectBuffer(~missingIndices,:) = rxPPDU(fmtDetInd(~missingIndices),:); % Use the indices available in the buffer
        formatString = wlanFormatDetect(fmtDetectBuffer, chEst, noiseVar, obj.ChannelBandwidthStr);
        % Return the format
        format = hFrameFormats.getFrameFormatConstant(formatString);
        % Update HE packet format in HE recovery config
        if (format > hFrameFormats.VHT)
            obj.RxHERecoveryConfig.PacketFormat = formatString;
            obj.RxHERecoveryConfig.ChannelBandwidth = obj.ChannelBandwidthStr;
            % Reset properties which must be undefined when processing
            % L-SIG and HE-SIG-A
            obj.RxHERecoveryConfig.LSIGLength = -1;
            obj.RxHERecoveryConfig.LDPCExtraSymbol = -1;
            obj.RxHERecoveryConfig.PreFECPaddingFactor = -1;
            obj.RxHERecoveryConfig.PEDisambiguity = -1;
            obj.RxHERecoveryConfig.GuardInterval = -1;
            obj.RxHERecoveryConfig.HELTFType = -1;
            obj.RxHERecoveryConfig.NumHELTFSymbols = -1;
            obj.RxHERecoveryConfig.SIGBMCS = -1;
            obj.RxHERecoveryConfig.SIGBDCM = -1;
            obj.RxHERecoveryConfig.SIGBCompression = -1;
        end
    end

    function getLLTFChanEstAndNoiseVar(obj, rxPPDU)
        %getLLTFChanEstAndNoiseVar Calculates the LLTF channel estimation and
        %noise variance

        tLSTF = 8e-6; % L-STF duration in seconds
        tLLTF = 8e-6; % L-LTF duration in seconds
        % L-LTF field indices
        indLLTF = [tLSTF*obj.SampleRate+1, (tLLTF+tLSTF)*obj.SampleRate];
        % Get the L-LTF field from rxPPDU.
        rxLLTF = rxPPDU(obj.PacketOffset + double(indLLTF(1):indLLTF(2)), :);
        % Demodulate L-LTF
        obj.RecoveredLLTF = wlanLLTFDemodulate(rxLLTF, obj.ChannelBandwidthStr);
        % Calculate Non-HT channel estimation
        obj.ChannelEstimateNonHT = wlanLLTFChannelEstimate(obj.RecoveredLLTF, obj.ChannelBandwidthStr);
        % Calculate Non-HT Noise variance
        obj.NoiseVarianceNonHT = helperNoiseEstimate(obj.RecoveredLLTF);
    end

    function failCheck = recoverSIGFields(obj, rxPPDU)
        %recoverSIGFields Recovers SIG fields (L-SIG, HT-SIG, VHT-SIG-A
        %VHT-SIG-B, HE-SIG-A) of the Rx PPDU

        lsigBits = zeros(24,1,'int8'); % For codegen
        if ~(any(obj.RxFrameFormat == [hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU, hFrameFormats.HE_MU]))
            % Get L-SIG field from Rx PPDU
            lsigIndices = wlanFieldIndices(obj.NonHTConfig, 'L-SIG');
            rxLSIG = rxPPDU(obj.PacketOffset + double(lsigIndices(1):lsigIndices(2)), :);
            % Decode L-SIG
            [lsigBits(:),failCheck] = wlanLSIGRecover(rxLSIG, obj.ChannelEstimateNonHT, obj.NoiseVarianceNonHT, obj.NonHTConfig.ChannelBandwidth);
            if failCheck % LSIG bits fail the parity check
                return;
            end
            % Get MCS & PSDU length from L-SIG bits
            lsigInfo = struct('MCS',0,'Length',0);
            [lsigInfo.MCS,lsigInfo.Length,failCheck] = obj.helperInterpretLSIG(lsigBits);
            if failCheck % Unexpected field value
                return;
            end
        else % HE SU or HE EXT SU or HE MU
            % Set the packet format in the recovery object and update the field indices
            indices = wlanFieldIndices(obj.RxHERecoveryConfig);

            % Demodulate the L-LTF and perform channel estimation. The
            % demodulated L-LTF symbols include tone rotation for each
            % 20 MHz segment. The L-LTF channel estimates (with tone
            % rotation) are used to equalize and decode the pre-HE-LTF
            % fields.
            rxLLTF = rxPPDU(obj.PacketOffset + double(indices.LLTF(1):indices.LLTF(2)), :);
            lltfDemod = wlanHEDemodulate(rxLLTF,'L-LTF',obj.RxHERecoveryConfig.ChannelBandwidth);
            lltfChanEst = wlanLLTFChannelEstimate(lltfDemod,obj.RxHERecoveryConfig.ChannelBandwidth);

            % L-SIG and RL-SIG Decoding
            rxLSIG = rxPPDU(obj.PacketOffset + double(indices.LSIG(1):indices.RLSIG(2)),:);

            % OFDM demodulate
            helsigDemod = wlanHEDemodulate(rxLSIG, 'L-SIG', obj.RxHERecoveryConfig.ChannelBandwidth);

            % Phase tracking
            helsigDemod = preHECommonPhaseErrorTracking(helsigDemod, lltfChanEst, 'L-SIG', obj.RxHERecoveryConfig.ChannelBandwidth);
            % Estimate channel on extra 4 subcarriers per subchannel and create full channel estimate
            preheInfo = wlanHEOFDMInfo('L-SIG', obj.RxHERecoveryConfig.ChannelBandwidth);
            obj.ChannelEstimatePreHE = preHEChannelEstimate(helsigDemod, lltfChanEst, preheInfo.NumSubchannels);

            % Average L-SIG and RL-SIG before equalization
            helsigDemod = mean(helsigDemod,2);

            % Equalize data carrying subcarriers, merging 20 MHz subchannels
            [eqLSIGSym,csi] = preHESymbolEqualize(helsigDemod(preheInfo.DataIndices,:,:),obj.ChannelEstimatePreHE(preheInfo.DataIndices,:,:),obj.NoiseVarianceNonHT,preheInfo.NumSubchannels);

            % Decode L-SIG field
            [~,failCheck,lsigInfo] = wlanLSIGBitRecover(eqLSIGSym,obj.NoiseVarianceNonHT,csi);
            if failCheck
                return;
            end

            % Get the length information from the recovered L-SIG bits and update the
            % L-SIG length property of the recovery configuration object
            obj.RxHERecoveryConfig.LSIGLength = lsigInfo.Length;
        end

        % Get Rx time and number of Rx samples
        if obj.RxFrameFormat == hFrameFormats.NonHT
            rxTime = lsigRxTime(lsigInfo.MCS,lsigInfo.Length);
        else
            % Calculate the receive time and corresponding number of samples in
            % the packet (note should be the same as above)
            rxTime = ceil((lsigInfo.Length + 3)/3) * 4 + 20; % In microseconds (IEEE 802.11-2016, Eqn 21-105)
        end
        % If the length of the waveform is less than L-SIG length then
        % something is wrong therefore error (carrier drop)
        numRxSamples = round(rxTime*obj.ChannelBandwidth);
        if (obj.PacketOffset+numRxSamples)>size(rxPPDU,1)
            failCheck = true;
            return;
        end

        % Recover and interpret L-SIG field parameters
        if (obj.RxFrameFormat == hFrameFormats.NonHT)
            % Update PHY configuration fields, if L-SIG is successfully
            % decoded
            obj.NonHTConfig.MCS = lsigInfo.MCS(1);
            obj.MCS(obj.UserIndexSU) = lsigInfo.MCS(1);
            obj.NonHTConfig.PSDULength = lsigInfo.Length(1);
            obj.RxPSDULength(obj.UserIndexSU) = lsigInfo.Length(1);
            obj.NumSTS = 1;

            % Return Non-HT channel estimation and noise variance
            obj.ChannelEstimate = obj.ChannelEstimateNonHT;
            obj.NoiseVariance = obj.NoiseVarianceNonHT;

            % Recover and interpret HT-SIG field parameters
        elseif (obj.RxFrameFormat == hFrameFormats.HTMixed)
            htSIGIdx = wlanFieldIndices(obj.HTConfig, 'HT-SIG');
            % Get HT-SIG field from Rx PPDU
            rxHTSIG = rxPPDU(obj.PacketOffset + double(htSIGIdx(1):htSIGIdx(2)), :);
            % Decode HT-SIG
            [htsigBits, failCheck] = wlanHTSIGRecover(rxHTSIG, obj.ChannelEstimateNonHT, obj.NoiseVarianceNonHT, obj.HTConfig.ChannelBandwidth);

            if ~failCheck
                % Recover HT PHY parameters using HT SIG bits
                htsigBits = double(reshape(htsigBits, 24, 2)');
                mcs = obj.binaryToDecimal(htsigBits(1,1:7));
                if mcs > 31
                    failCheck = true;
                    return;
                end
                obj.HTConfig.MCS = mcs;
                obj.HTConfig.PSDULength = obj.binaryToDecimal(htsigBits(1,9:24));
                obj.HTConfig.RecommendSmoothing = logical(htsigBits(2, 1));
                obj.HTConfig.AggregatedMPDU = logical(htsigBits(2, 4));
                Nss = floor(mcs/8)+1;
                obj.HTConfig.NumSpaceTimeStreams = Nss;
                obj.HTConfig.NumTransmitAntennas = Nss;

                % Calculate HT channel estimation and noise variance using
                % HT-LTF
                htLTFIdx = wlanFieldIndices(obj.HTConfig, 'HT-LTF');
                htltfDemod = wlanHTLTFDemodulate(rxPPDU(obj.PacketOffset + double(htLTFIdx(1):htLTFIdx(2)), :), obj.HTConfig);
                obj.ChannelEstimate = wlanHTLTFChannelEstimate(htltfDemod, obj.HTConfig);
                obj.NoiseVariance = helperNoiseEstimate(obj.RecoveredLLTF, obj.HTConfig.ChannelBandwidth, obj.HTConfig.NumSpaceTimeStreams);
                obj.RxPSDULength(obj.UserIndexSU) = obj.HTConfig.PSDULength;
                obj.MCS(obj.UserIndexSU) = obj.HTConfig.MCS;
                obj.NumSTS(obj.UserIndexSU) = obj.HTConfig.NumSpaceTimeStreams;
            end

            % Recover and interpret VHT-SIG-A, VHT-SIG-B field parameters
        elseif (obj.RxFrameFormat == hFrameFormats.VHT)
            vhtSIGAIdx = wlanFieldIndices(obj.VHTConfig, 'VHT-SIG-A');
            % Get VHT-SIG-A field from Rx PPDU
            rxVHTSIGA = rxPPDU(obj.PacketOffset + double(vhtSIGAIdx(1):vhtSIGAIdx(2)), :);
            % Decode VHT-SIG-A
            [recVHTSIGA, failCheck] = wlanVHTSIGARecover(rxVHTSIGA, obj.ChannelEstimateNonHT, obj.NoiseVarianceNonHT, obj.VHTConfig.ChannelBandwidth);

            if failCheck
                return;
            end

            % Retrieve packet parameters based on decoded L-SIG and VHT-SIG-A
            [obj.VHTConfig, ~, ~, ~, failInterp] = helperVHTConfigRecover(lsigBits, recVHTSIGA, 'SuppressError',true);

            if failInterp || ~strcmp(obj.ChannelBandwidthStr, obj.VHTConfig.ChannelBandwidth) || ...
                    obj.NumUsers ~= 1 % Cannot interpret the received bits.
                return;
            end

            % Get VHT field indices
            vhtLTFIdx = wlanFieldIndices(obj.VHTConfig, 'VHT-LTF');
            % Calculate VHT channel estimation and noise
            % variance using VHT-LTF
            vhtltfDemod = wlanVHTLTFDemodulate(rxPPDU(obj.PacketOffset + double(vhtLTFIdx(1):vhtLTFIdx(2)), :), obj.VHTConfig);
            obj.ChannelEstimate = wlanVHTLTFChannelEstimate(vhtltfDemod, obj.VHTConfig);
            obj.NoiseVariance = helperNoiseEstimate(obj.RecoveredLLTF, obj.VHTConfig.ChannelBandwidth, obj.VHTConfig.NumSpaceTimeStreams);

            obj.RxPSDULength(obj.UserIndexSU) = obj.VHTConfig.PSDULength(1);
            obj.MCS(obj.UserIndexSU) = obj.VHTConfig.MCS(1);
            obj.NumSTS(obj.UserIndexSU) = obj.VHTConfig.NumSpaceTimeStreams(1);

        else % HE-SU/HE-EXT-SU/HE-MU
            indices = wlanFieldIndices(obj.RxHERecoveryConfig);

            % Start of HE-SIG-A decoding

            % Equalize data carrying subcarriers, merging 20 MHz subchannels
            preheInfo = wlanHEOFDMInfo('HE-SIG-A', obj.RxHERecoveryConfig.ChannelBandwidth);

            % Recover and decode HE-SIG-A field
            rxSIGA = rxPPDU(obj.PacketOffset + double(indices.HESIGA(1) : 1*indices.HESIGA(2)), :);
            sigaDemod = wlanHEDemodulate(rxSIGA, 'HE-SIG-A', obj.RxHERecoveryConfig.ChannelBandwidth);
            % Phase tracking
            hesigaDemod = preHECommonPhaseErrorTracking(sigaDemod, obj.ChannelEstimatePreHE, 'HE-SIG-A', obj.RxHERecoveryConfig.ChannelBandwidth);

            % Equalize data carrying subcarriers, merging 20 MHz subchannels
            [eqHESIGASym, csi] = preHESymbolEqualize(hesigaDemod(preheInfo.DataIndices, :, :), ...
                obj.ChannelEstimatePreHE(preheInfo.DataIndices, :, :), obj.NoiseVariance, preheInfo.NumSubchannels);

            [rxSIGABits, sigaCRCFail] = wlanHESIGABitRecover(eqHESIGASym, obj.NoiseVariance, csi); % Recover HE-SIG-A bits

            % HE-SIG-A: check CRC
            if sigaCRCFail
                failCheck = true;
                return;
            end
            % Recover HE configuration from HE-SIG-A bits
            [obj.RxHERecoveryConfig, failInterpretation] = interpretHESIGABits(obj.RxHERecoveryConfig, rxSIGABits);

            % Do not process unsupported transmission parameters
            if failInterpretation || obj.RxHERecoveryConfig.HighDoppler==1 || ...
                    ~strcmp(obj.ChannelBandwidthStr, obj.RxHERecoveryConfig.ChannelBandwidth)
                failCheck = true;
                return;
            end

            % Update field indices after interpreting the recovered HE-SIG-A bits
            heFieldIndices = wlanFieldIndices(obj.RxHERecoveryConfig);

            % End of HE-SIG-A decoding

            % Decode HE-SIG-B in case of HE-MU
            if (obj.RxFrameFormat == hFrameFormats.HE_MU)

                if ~obj.RxHERecoveryConfig.SIGBCompression
                    sigbInfo = getSIGBLength(obj.RxHERecoveryConfig);
                    % Get common field symbols. The start of HE-SIG-B field is known
                     rxSym = rxPPDU(obj.PacketOffset+(double(heFieldIndices.HESIGA(2))+(1:sigbInfo.NumSIGBCommonFieldSamples)),:);
                    % Decode HE-SIG-B common field
                    [status, obj.RxHERecoveryConfig, ~, ~, failInterpretation] = heSIGBCommonFieldDecode(rxSym, obj.ChannelEstimatePreHE, obj.NoiseVarianceNonHT, obj.RxHERecoveryConfig, true);

                    % CRC on HE-SIG-B content channels
                    if ~strcmp(status,'Success') || failInterpretation
                        failCheck = true;
                        return;
                    end
                    % Update field indices as the number of HE-SIG-B symbols are
                    % updated
                    heFieldIndices = wlanFieldIndices(obj.RxHERecoveryConfig);
                end
                % Get complete HE-SIG-B field samples
                if (obj.PacketOffset+double(heFieldIndices.HESIGB(2)))>size(rxPPDU,1)
                    % If not enough samples carrier lost
                    failCheck = true;
                    return;
                end
                 rxSIGB = rxPPDU(obj.PacketOffset+(double(heFieldIndices.HESIGB(1):heFieldIndices.HESIGB(2))),:);

                % Decode HE-SIG-B user field
                [failCRC,userCfgs,~,~,failInterp] = heSIGBUserFieldDecode(rxSIGB, obj.ChannelEstimatePreHE, obj.NoiseVarianceNonHT, obj.RxHERecoveryConfig, true);

                % CRC on HE-SIG-B users
                if all(~failCRC) && all(~failInterp)
                    % All users pass CRC and interpreted successfully
                elseif all(failCRC) || all(failInterp) || isempty(userCfgs)
                    % Discard the packet as HE-SIG-B unexpected value or CRC fail for all users
                    failCheck = true;
                    return
                else % all(~failInterp) || all(~failCRC) || any(failInterp)
                    % Some users failed CRC, and some passing ones failed interpretation
                    % Only process users with valid CRC and can be interpreted
                end
                if isempty(userCfgs)
                    % Discard the packet if all users fail the CRC
                    failCheck = true;
                    return;
                end

                obj.NumUsers = numel(userCfgs);
                for userIdx = 1: obj.NumUsers
                    % Fill Rx Station IDs
                    obj.RxStationIDs(userIdx) = userCfgs{userIdx}.STAID;
                    obj.MCS(userIdx) = userCfgs{userIdx}.MCS;
                    obj.RxPSDULength(userIdx) = getPSDULength(userCfgs{userIdx});

                    % Don't process the rx data if the received PPDU is of
                    % type HE-MU and Rx station ID doesn't match with
                    % receivers node ID
                    if (obj.RxStationIDs(userIdx) ~= obj.NodeID)
                        obj.DecodeHEData = false;
                        continue;
                    else
                        obj.HEUserConfig = userCfgs{userIdx};
                        obj.DecodeHEData = true;
                        obj.NumSTS = userCfgs{userIdx}.NumSpaceTimeStreams;
                        obj.RxBSSColor = userCfgs{userIdx}.BSSColor;

                        % In case of downlink OFDMA maximum of one RU
                        % is assigned for a user. So stop processing
                        % other RUs after processing an RU.
                        break;
                    end
                end

            else % HE-SU, HE-EXT-SU
                obj.HEUserConfig = obj.RxHERecoveryConfig;
                obj.NumUsers = 1;
                obj.DecodeHEData = true;
                obj.MCS(obj.UserIndexSU) = obj.HEUserConfig.MCS;
                obj.RxPSDULength(obj.UserIndexSU) = getPSDULength(obj.HEUserConfig);
                obj.NumSTS = obj.HEUserConfig.NumSpaceTimeStreams;
                obj.RxBSSColor = obj.HEUserConfig.BSSColor;
            end

            if (obj.DecodeHEData == true)
                heFieldIndices = wlanFieldIndices(obj.RxHERecoveryConfig);
                rxHELTF = rxPPDU(obj.PacketOffset + double(heFieldIndices.HELTF(1):heFieldIndices.HELTF(2)), :);
                heltfDemod = wlanHEDemodulate(rxHELTF, 'HE-LTF', obj.HEUserConfig.ChannelBandwidth, ...
                    obj.HEUserConfig.GuardInterval, obj.HEUserConfig.HELTFType, [obj.HEUserConfig.RUSize obj.HEUserConfig.RUIndex]);

                [obj.ChannelEstimate, obj.PilotEstimate] = heLTFChannelEstimate(heltfDemod, obj.HEUserConfig);
            end
        end
    end

    function data = recoverRxData(obj, rxPPDU, chEst, noiseVar)
        %recoverRxData Recover data field bits from the received PPDU

        % Extract data field from PPDU
        receivedData = rxPPDU(obj.PacketOffset + double(obj.PayloadIndices(1):obj.PayloadIndices(2)), :);

        if (obj.RxFrameFormat == hFrameFormats.NonHT)
            % Recover information bits
            data = double(wlanNonHTDataRecover(receivedData, chEst, noiseVar, obj.NonHTConfig));

        elseif (obj.RxFrameFormat == hFrameFormats.HTMixed)
            % Recover information bits
            data = double(wlanHTDataRecover(receivedData, chEst, noiseVar, obj.HTConfig));

        elseif (obj.RxFrameFormat == hFrameFormats.VHT)
            % Recover information bits
            vhtDataBits= wlanVHTDataRecover(receivedData, chEst, noiseVar, obj.VHTConfig);
            data = double(vhtDataBits);

        else % HE-SU/HE-EXT-SU/HE-MU
            % User configuration
            userCfg = obj.HEUserConfig;

            % Data demodulate
            demodSym = wlanHEDemodulate(receivedData, 'HE-Data', userCfg.ChannelBandwidth, ...
                userCfg.GuardInterval, [userCfg.RUSize userCfg.RUIndex]);

            % Pilot phase tracking
            pilotEstTrack = mean(obj.PilotEstimate,2);
            heDemodSym = heCommonPhaseErrorTracking(demodSym, pilotEstTrack, userCfg);

            % Estimate noise power in HE fields
            heInfo = wlanHEOFDMInfo('HE-Data', userCfg.ChannelBandwidth, userCfg.GuardInterval, [userCfg.RUSize userCfg.RUIndex]);

            demodPilotSym = demodSym(heInfo.PilotIndices, :, :);
            obj.NoiseVariance = heNoiseEstimate(demodPilotSym, obj.PilotEstimate, userCfg);
            obj.MCS(obj.UserIndexSU) = userCfg.MCS;

            % Equalization and STBC combining
            [eqDataSym, csi] = heEqualizeCombine(heDemodSym, obj.ChannelEstimate, obj.NoiseVariance, userCfg);

            preheInfo = wlanHEOFDMInfo('HE-Data', userCfg.ChannelBandwidth, ...
                userCfg.GuardInterval, [userCfg.RUSize userCfg.RUIndex]);

            data = double(wlanHEDataBitRecover(eqDataSym(preheInfo.DataIndices, :, :), noiseVar, csi(preheInfo.DataIndices, :, :), userCfg));
            obj.RxPSDULength(obj.UserIndexSU) = numel(data)/8;
        end
    end

    function [detected, rxPPDU] = packetDetectionAndFreqCorrection(obj, rxPPDU)
        %packetDetectionAndFreqCorrection Detects the packet and
        %performs frequency correction on the given waveform.
        detected = true;
        ind = wlanFieldIndices(obj.NonHTConfig);

        % Identify packet offset and determine coarse packet offset
        startOffset = wlanPacketDetect(rxPPDU, obj.ChannelBandwidthStr);

        % No packet is detected or packet detection is likely incorrect
        if isempty(startOffset) || (startOffset+double(ind.LSIG(2))>size(rxPPDU,1))
            detected = false;
        else
            obj.PacketOffset = startOffset(1);
            % Extract L-STF and perform coarse frequency offset
            % correction
            lstf = rxPPDU((obj.PacketOffset + double(ind.LSTF(1):ind.LSTF(2))), :);
            cfo = wlanCoarseCFOEstimate(lstf, obj.ChannelBandwidthStr);
            rxPPDU = helperFrequencyOffset(rxPPDU, obj.SampleRate, -cfo);

            % Extract Non-HT fields and perform symbol timing
            % synchronization
            nonHTFields = rxPPDU(obj.PacketOffset + double(ind.LSTF(1):ind.LSIG(2)), :);
            startOffset = wlanSymbolTimingEstimate(nonHTFields, obj.ChannelBandwidthStr);
            obj.PacketOffset = obj.PacketOffset + startOffset(1);
            if (obj.PacketOffset < 0)
                obj.PacketOffset = 0;
            end

            % No packet is detected if the minimum packet length is
            % less than 5 OFDM symbols or the packet is detected
            % outwith the range of the expected delays from the channel
            if (obj.PacketOffset + double(ind.LSIG(2))) > size(rxPPDU,1) || obj.PacketOffset>50
                detected = false;
            else
                % Extract L-LTF and perform fine frequency offset
                % correction
                lltf = rxPPDU(obj.PacketOffset + double(ind.LLTF(1):ind.LLTF(2)), :);
                ffo = wlanFineCFOEstimate(lltf, obj.ChannelBandwidthStr);
                rxPPDU = helperFrequencyOffset(rxPPDU, obj.SampleRate, -ffo);
            end

            % Scale the waveform based on L-STF power (AGC)
            gain = 1./(sqrt(mean(lstf(:).*conj(lstf(:)))));
            rxPPDU = rxPPDU.*gain;
        end
    end

    function rxPSDU = recoverPayload(obj, rxPPDU)
        %recoverPayload Recovers the payload from the received PPDU
        rxPSDU = obj.recoverRxData(rxPPDU, obj.ChannelEstimate, obj.NoiseVariance);
    end

    function [isValidPreamble, rxPPDU] = decodePreamble(obj, rxPPDU)
        %decodePreamble Decodes preamble of the received PPDU
        [isValidPreamble, rx] = obj.packetDetectionAndFreqCorrection(rxPPDU);
        if isValidPreamble
            rxPPDU = rx;
            % Calculate channel estimation and noise variance
            obj.getLLTFChanEstAndNoiseVar(rxPPDU);

            % Get the format of the receive packet Synthetically
            frameFormat = formatDetect(obj, rxPPDU, obj.ChannelEstimateNonHT, obj.NoiseVarianceNonHT);
        end

        % Check if the frame format is unsupported like HT_GF.
        isValidPreamble = isValidPreamble && (frameFormat ~= -1);

        if isValidPreamble
            obj.RxFrameFormat = frameFormat;
        end
    end

    function isValidHeader = decodeHeader(obj, rxPPDU)
        %decodeHeader Decodes PHY header of the given waveform.
        isValidHeader = ~(obj.recoverSIGFields(rxPPDU));
    end

    function thermalNoise = calculateThermalNoise(obj)
        %calculateThermalNoise calculate thermal noise

        % Temperature in Kelvin for calculating thermal noise.
        tempInKelvin = 290;
        % Thermal noise(in Watts) = BoltzmannConstant * Temperature (in Kelvin) * bandwidth of the channel.
        Nt = physconst('Boltzmann') * tempInKelvin * obj.SampleRate;
        thermalNoise = (10^(obj.RxNoiseFigure/10)) * Nt; % In watts
    end
end
end

function rxTime = lsigRxTime(MCS,Length)
    % Returns the RXTIME of a packet given the MCS and LENGTH recovered in
    % L-SIG
    Nsd = 48; % Data subcarriers
    switch MCS
      case 0 % 6 Mbps
        Nbpscs = 1;  % 'BPSK'
        rate = 1/2;
      case 1 % 9 Mbps
        Nbpscs = 1; 
        rate   = 3/4;
      case 2 % 12 Mbps
        Nbpscs = 2;  % QPSK
        rate   = 1/2;
      case 3 % 18 Mbps
        Nbpscs = 2; 
        rate   = 3/4;
      case 4 % 24 Mbps
        Nbpscs = 4;  % 16QAM 
        rate   = 1/2;
      case 5 % 36 Mbps
        Nbpscs = 4;  
        rate   = 3/4;
      case 6  % 48 Mbps
        Nbpscs = 6;  % '64QAM'
        rate   = 2/3;
      otherwise % 7 => 54 Mbps
        Nbpscs = 6;
        rate   = 3/4;
    end
    Ncbps = Nsd * Nbpscs;
    numDBPS = Ncbps * rate;  

    % Compute the RX time by computing number of data field symbols
    Ntail = 6;
    Nservice = 16;
    numDataSym = ceil((8*Length + Nservice + Ntail)/numDBPS);
    numSymbols = 2 + 2 + 1 + numDataSym;
    rxTime = numSymbols*4;
end
