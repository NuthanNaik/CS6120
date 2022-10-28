classdef hPHYTxAbstract < hPHYTxInterface
%hPHYTxAbstract Create an object for WLAN abstracted PHY transmitter
%	WLANPHYTx = hPHYTxAbstract creates a WLAN PHY transmitter object
%	supporting the following operations:
%       - Handling requests from MAC layer
%       - Creating an abstracted waveform (PPDU)
%       - Handling transmit power (Tx power)
%
%   WLANPHYTx = hPHYTxAbstract(Name, Value) creates a WLAN PHY
%   transmitter object with the specified property Name set to the
%   specified Value. You can specify additional name-value pair arguments
%   in any order as (Name1, Value1, ..., NameN, ValueN).
%
%   hPHYTxAbstract methods:
%
%   run     - Run the physical layer transmit operations
%
%   hPHYTxAbstract properties:
%
%   NodeID           - Specifies the node identifier
%   NodePosition     - Specifies the node position
%   IsNodeTypeAP     - Specifies the type of node (AP/STA)
%   TxGain           - Specifies the transmission gain of the node in dB

%   Copyright 2021 The MathWorks, Inc.

% Information from MAC
properties (Access = private)
    % User index for single user processing. Index '1' will be used in case
    % of single user and downlink multi-user reception. Indices greater
    % than '1' will be used in case of downlink multi-user transmission and
    % uplink multi-user reception.
    UserIndexSU = 1;
end

% Configure based on values from MAC
properties (Access = private)
    % Waveform generator configuration objects (Tx)

    % Non-HT configuration object
    NonHTConfig;

    % HT configuration object
    HTConfig;

    % VHT configuration object
    VHTConfig;

    % HE-SU configuration object
    HESUConfig;
end

% Spatial reuse parameters
properties (Access = private)
    % Tx Power limit flag
    LimitTxPower = false;

    % OBSS Threshold (dBm)
    OBSSPDThreshold = -82;

    % SR operation flag
    EnableSROperation = false;

    % Tx Power reference (dBm)
    TXPowerReference = 21;
end

properties (Access = private)
    % Structure holding metadata for the transmitting packet
    Metadata;

    % Structure for storing Tx Vector information
    TxVector;
end

properties(Constant, Hidden)
    % Minimum OBSS Threshold
    OBSSPDThresholdMin = -82;

    % Maximum PSDU length in bytes with 8x8 MIMO, over 160MHz bandwidth
    MaxPSDULength = 6500631;
end

properties (Hidden)
    % Structure holding output data for the PHY transmitter
    TransmitWaveform

    % Structure to MAC layer which indicates the transmission start
    % ('TXSTARTCONFIRM') or transmission end ('TXENDCONFIRM') indication
    % for a corresponding MAC request.
    PHYConfirmIndication
end

properties (Hidden)
    % Operating frequency ID
    OperatingFreqID = 1;

    %OperatingFrequency Frequency of operation in GHz
    OperatingFrequency = 5.180;

    %MaxSubframes Maximum number of subframes that can be present in an
    %A-MPDU
    MaxSubframes = 64;

    %MaxMUUsers Maximum number of users in a PPDU
    MaxMUUsers = 9;
end

methods (Access = private)
    function sigPower = adjustTxPower(obj)
    % adjustTxPower Return the Adjusted transmit power in conjunction
    % with OBSS PD threshold

        % If the transmit power restriction period is active and OBSS PD
        % threshold greater than minimum OBSS PD threshold, adjust the
        % transmit power
        %
        % Reference: IEEE P802.11ax/D4.1 Section 26.10.2.4
        if obj.LimitTxPower && (obj.OBSSPDThreshold > obj.OBSSPDThresholdMin)
            % Restrict the Tx Power
            TxPowerMax = obj.TXPowerReference - (obj.OBSSPDThreshold - obj.OBSSPDThresholdMin);
            sigPower = min(TxPowerMax, obj.TxVector.TxPower(obj.UserIndexSU));
            obj.PhyNumTxWhileActiveOBSSTx = obj.PhyNumTxWhileActiveOBSSTx + 1;
        else
            sigPower = obj.TxVector.TxPower(obj.UserIndexSU);
        end
    end
end

methods
    function obj = hPHYTxAbstract(varargin)
    %hPHYTxAbstract Create an instance of abstracted PHY transmitter class

        % Name-value pair check
        if mod(nargin,2)
            error('Incorrect number of input arguments. Number of input arguments must be even.')
        end

        % Name-value pairs
        for idx = 1:2:numel(varargin)
            obj.(varargin{idx}) = varargin{idx+1};
        end

        % Initialize the frame config properties
        obj.NonHTConfig = wlanNonHTConfig; % Non-HT configuration object
        obj.HTConfig = wlanHTConfig; % HT configuration object
        % For VHT config default bandwidth is 80MHz. Update it to 20MHz
        obj.VHTConfig = wlanVHTConfig('ChannelBandwidth', 'CBW20');
        obj.HESUConfig = wlanHESUConfig; % HE-SU configuration object

        % Initialize the structures
        obj.TxVector = struct('IsEmpty', true, 'EnableSROperation', false, 'BSSColor', 1, 'LimitTxPower', false, ...
            'OBSSPDThreshold', -62, 'NumTransmitAntennas', 0, 'NumSpaceTimeStreams', 0, 'FrameFormat', 0, 'AggregatedMPDU', 0, ...
            'ChannelBandwidth', 20, 'MCSIndex', zeros(obj.MaxMUUsers, 1), 'PSDULength', zeros(obj.MaxMUUsers, 1), ...
            'RSSI', 0, 'MessageType', 0, 'AllocationIndex', 0, 'StationIDs', zeros(obj.MaxMUUsers, 1), ...
            'TxPower', zeros(obj.MaxMUUsers, 1));

        obj.Metadata = struct('Timestamp', zeros(obj.MaxSubframes, obj.MaxMUUsers), 'Vector', obj.TxVector, ...
            'PayloadInfo', repmat(struct('OverheadDuration', 0,'Duration', 0,'NumOfBits', 0), [1,obj.MaxSubframes]), ...
            'SourcePosition', zeros(1, 3), 'PreambleDuration', 0, 'HeaderDuration', 0, ...
            'PayloadDuration', 0, 'Duration', 0, 'SignalPower', 0, 'SourceID', 0, ...
            'SubframeCount', 0, 'SubframeLengths', zeros(1, obj.MaxSubframes), 'SubframeIndexes', zeros(1, obj.MaxSubframes), ...
            'NumHeaderAndPreambleBits', 0, 'StartTime', 0, 'SequenceNumbers', zeros(obj.MaxSubframes, obj.MaxMUUsers));

        macFrameConfig = struct('IsEmpty', true, 'FrameType', 'Data', 'FrameFormat', 'Non-HT', ...
            'Duration', 0, 'Retransmission', false(obj.MaxSubframes, obj.MaxMUUsers), ...
            'FourAddressFrame', false(obj.MaxSubframes, obj.MaxMUUsers), 'Address1', '000000000000', ...
            'Address2', '000000000000', 'Address3', repmat('0', obj.MaxSubframes, 12, obj.MaxMUUsers), ...
            'Address4', repmat('0', obj.MaxSubframes, 12, obj.MaxMUUsers), ...
            'MeshSequenceNumber', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'AckPolicy', 'No Ack', 'TID', 0, ...
            'SequenceNumber', zeros(obj.MaxSubframes, obj.MaxMUUsers), 'MPDUAggregation', false, ...
            'PayloadLength', zeros(obj.MaxSubframes, obj.MaxMUUsers), 'MPDULength', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'PSDULength', zeros(obj.MaxMUUsers, 1), 'FCSPass', true(obj.MaxSubframes, obj.MaxMUUsers), 'DelimiterFails', false(obj.MaxSubframes, obj.MaxMUUsers));

        obj.TransmitWaveform = struct('IsEmpty', true, ...
            'Waveform', [], ...
            'Metadata', obj.Metadata, ...
            'MACFrame', macFrameConfig);

        obj.PHYConfirmIndication = obj.TxVector;
    end

    function run(obj, macReqToPHY, frameToPHY)
    %run Run physical layer transmit operations for a WLAN node
    %   run(OBJ, MACREQTOPHY, FRAMETOPHY) runs the following transmit
    %   operations
    %       * Handling the MAC requests
    %       * Transmitting the waveform
    %
    %   MACREQTOPHY is a structure containing the details of request from
    %   MAC layer. MAC request is valid only if the field 'IsEmpty' is
    %   false in this structure. The corresponding confirmation for the MAC
    %   request is indicated through the PHYConfirmIndication property.
    %
    %   Structure 'MACREQTOPHY' contains the following fields:
    %
    %   IsEmpty             - Logical value to determine whether the
    %                         input is valid or not.
    %   EnableSROperation   - Logical flag, that defines whether spatial
    %                         reuse(SR) operation is enabled or not
    %   BSSColor            - Basic service set color (Used to differentiate
    %                         signals as Intra-BSS/Intra-BSS)
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
    %   MCSIndex            - Modulation coding scheme index in range [0, 9]
    %   PSDULength          - Length of the received PSDU
    %   RSSI                - Receive signal strength
    %   MessageType         - Stores the PHY indications
    %                         (CCAIdle/CCABusy/RxStart/RxEnd/RxErr). These
    %                         indications are of type hPHYPrimitives class
    %   AllocationIndex     - Allocation index for OFDMA transmission.
    %   StationIDs          - Station identifier
    %
    %   FRAMETOPHY is a structure containing the frame metadata
    %   received from the MAC layer. When the field IsEmpty is
    %   false in this structure, the corresponding waveform
    %   transmission is indicated through the TransmitWaveform
    %   property.
    %
    %   Structure 'FRAMETOPHY' contains the following fields:
    %
    %   IsEmpty            - Logical value, that defines whether the frame
    %                        to PHY is empty or not.
    %   MACFrame           - Structure containing the MAC frame information
    %   Data               - Data to be transmitted
    %   PSDULength         - Length of the PSDU
    %   SubframeBoundaries - Sub frame start indexes (Stores the start
    %                        indexes of every subframe in a AMPDU)
    %   NumSubframes       - Total number of subframes to be carried in the
    %                        transmitted waveform
    %
    %   Subfield 'MACFrame' structure contains the following fields
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
    %   MPDUAggregation- Logical value, indicating if the frame is
    %                    aggregated
    %   PayloadLength  - Length of the payload
    %   Timestamp	   - Packet generation timestamp
    %   MPDULength	   - Length of MPDU
    %   PSDULength	   - Length of PSDU
    %   FCSPass	       - Frame check sequence pass, used to check whether
    %                    the frame is corrupted or not
    %   DelimiterFails - Failures caused due to delimiter errors

        % Initialize
        obj.PHYConfirmIndication.IsEmpty = true;

        % Handle MAC requests
        if ~macReqToPHY.IsEmpty
            phyIndHandle(obj, macReqToPHY);
        end

        % Handle MAC frame
        if ~frameToPHY.IsEmpty
            generateWaveform(obj, frameToPHY);
        end
    end
end

methods (Access = private)
    function phyIndHandle(obj, phyTxVector)
    %phyIndHandle Build the PHY transmitter object using the Tx
    %vector.
    %
    %   phyIndHandle(OBJ, PHYTXVECTOR) builds the PHY transmitter
    %   object using the PHY transmitter vector received from MAC
    %   layer.
    %
    %   PHYTXVECTOR  - PHY transmitter vector received from MAC
    %                  layer specified as a structure.

        response = obj.TxVector;
        response.IsEmpty = false;

        % Checks the request type
        if phyTxVector.MessageType == hPHYPrimitives.TxStartRequest
            obj.TxVector = phyTxVector;
            % Set spatial reuse parameters
            obj.EnableSROperation = obj.TxVector.EnableSROperation;
            if obj.EnableSROperation
                obj.HESUConfig.BSSColor = obj.TxVector.BSSColor;
                obj.LimitTxPower = obj.TxVector.LimitTxPower;
                obj.OBSSPDThreshold = obj.TxVector.OBSSPDThreshold;
                % The TXPowerReference is 4 dB higher for APs with more
                % than 2 spatial streams.
                %
                % Reference: IEEE P802.11ax/D4.1 Section 26.10.2.4
                if obj.IsNodeTypeAP && obj.TxVector.NumSpaceTimeStreams > 2
                    obj.TXPowerReference = 25;
                end
            end

            % Configure the PHY object using transmission vector
            % information
            switch obj.TxVector.FrameFormat
                case hFrameFormats.NonHT
                    obj.NonHTConfig.NumTransmitAntennas = obj.TxVector.NumTransmitAntennas;
                    obj.NonHTConfig.ChannelBandwidth = getChannelBandwidthStr(obj, obj.TxVector.ChannelBandwidth);
                    obj.NonHTConfig.PSDULength = obj.TxVector.PSDULength(obj.UserIndexSU);
                    obj.NonHTConfig.MCS = obj.TxVector.MCSIndex(obj.UserIndexSU);

                case hFrameFormats.HTMixed
                    obj.HTConfig.PSDULength = obj.TxVector.PSDULength(obj.UserIndexSU);
                    obj.HTConfig.ChannelBandwidth = getChannelBandwidthStr(obj, obj.TxVector.ChannelBandwidth);
                    obj.HTConfig.MCS = obj.TxVector.MCSIndex(obj.UserIndexSU);
                    obj.HTConfig.AggregatedMPDU = obj.TxVector.AggregatedMPDU;
                    obj.HTConfig.NumSpaceTimeStreams = obj.TxVector.NumSpaceTimeStreams;
                    obj.HTConfig.NumTransmitAntennas = obj.TxVector.NumTransmitAntennas;

                case hFrameFormats.VHT
                    obj.VHTConfig.APEPLength = obj.TxVector.PSDULength(obj.UserIndexSU);
                    obj.VHTConfig.ChannelBandwidth = getChannelBandwidthStr(obj, obj.TxVector.ChannelBandwidth);
                    obj.VHTConfig.MCS = obj.TxVector.MCSIndex(obj.UserIndexSU);
                    obj.VHTConfig.NumSpaceTimeStreams = obj.TxVector.NumSpaceTimeStreams;
                    obj.VHTConfig.NumTransmitAntennas = obj.TxVector.NumTransmitAntennas;

                case {hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU}
                    obj.HESUConfig.APEPLength = obj.TxVector.PSDULength(obj.UserIndexSU);
                    obj.HESUConfig.ChannelBandwidth = getChannelBandwidthStr(obj, obj.TxVector.ChannelBandwidth);
                    obj.HESUConfig.MCS = obj.TxVector.MCSIndex(obj.UserIndexSU);
                    obj.HESUConfig.NumSpaceTimeStreams = obj.TxVector.NumSpaceTimeStreams;
                    obj.HESUConfig.NumTransmitAntennas = obj.TxVector.NumTransmitAntennas;
                    obj.HESUConfig.ExtendedRange = (obj.TxVector.FrameFormat == hFrameFormats.HE_EXT_SU);
            end
            % Send 'tx start confirm' indication to MAC
            response.MessageType = hPHYPrimitives.TxStartConfirm;

        elseif phyTxVector.MessageType == hPHYPrimitives.TxEndRequest
            % Update the counter for total number of PHY transmissions
            obj.PhyNumTransmissions = obj.PhyNumTransmissions + 1;

            % Update the counter for total number of bytes transmitted from PHY
            obj.PhyTxBytes = obj.PhyTxBytes + sum(obj.TxVector.PSDULength);

            % Update the counter for total PHY transmission time.
            obj.PhyTxTime = obj.PhyTxTime + obj.Metadata.Duration;

            % Send 'tx end confirm' indication to MAC
            response.MessageType = hPHYPrimitives.TxEndConfirm;
        else
            response.MessageType = hPHYPrimitives.UnknownIndication;
        end
        obj.PHYConfirmIndication = response;
    end

    function generateWaveform(obj, ppdu)
    % generateWaveform Generate the WLAN waveform
    %
    %   generateWaveform (OBJ, PPDU) generates the WLAN waveform.
    %   The waveform contains the PHY metadata and MAC metadata
    %
    %   PPDU - PPDU is the received WLAN physical layer Protocol Data
    %          Unit (PDU).

        if obj.EnableSROperation
            % Restrict the Tx Power.
            sigPower = adjustTxPower(obj);
            % Update signal power when SR operation is enabled.
            sigPower = sigPower + obj.TxGain;
        else
            % Update signal power when there is no SR operation.
            sigPower = obj.TxVector.TxPower(obj.UserIndexSU) + obj.TxGain;
        end

        % Preallocate to max size
        subFrameLengths = zeros(1, obj.MaxSubframes);
        subFrameIndices = zeros(1, obj.MaxSubframes);

        subframeCount = ppdu.NumSubframes(obj.UserIndexSU); % Number of subframes
        subFrameLengths(1:subframeCount) = ppdu.SubframeBoundaries(1:subframeCount, 2, obj.UserIndexSU); % Length of subframes
        subFrameIndices(1:subframeCount) = ppdu.SubframeBoundaries(1:subframeCount, 1, obj.UserIndexSU); % Subframe start indices

        % Preamble duration for all frame formats (in microseconds)
        obj.Metadata.PreambleDuration = 16;

        % Default HE guard interval
        heGuardInterval = 3.2;

        switch obj.TxVector.FrameFormat
        % Calculate the duration of the waveform
            case hFrameFormats.NonHT
                % Header duration for Non-HT format (in microseconds)
                obj.Metadata.HeaderDuration = 4;
                % Payload duration for Non-HT configuration (in microseconds)
                psduInfo = validateConfig(obj.NonHTConfig);
                psduInfo.TxTime = round(psduInfo.TxTime, 3);
                obj.Metadata.PayloadDuration = psduInfo.TxTime - ...
                    (obj.Metadata.PreambleDuration + obj.Metadata.HeaderDuration);

            case hFrameFormats.HTMixed
                % Retain the actual PSDU length
                psduLength = obj.HTConfig.PSDULength;
                % Get TxTime for PSDU length zero (validateConfig returns a
                % structure containing TxTime). This is equivalent to
                % (preamble + header) duration
                obj.HTConfig.PSDULength = 0;
                psduInfo = validateConfig(obj.HTConfig);
                psduInfo.TxTime = round(psduInfo.TxTime, 3);
                % Subtract preamble duration to get header duration (in microseconds)
                obj.Metadata.HeaderDuration = psduInfo.TxTime - obj.Metadata.PreambleDuration;
                % Reassign the PSDU length, so that configuration object
                % remains same again
                obj.HTConfig.PSDULength = psduLength;
                % Payload duration for HT configuration (in microseconds)
                psduInfo = validateConfig(obj.HTConfig);
                psduInfo.TxTime = round(psduInfo.TxTime, 3);
                obj.Metadata.PayloadDuration = psduInfo.TxTime - ...
                    (obj.Metadata.PreambleDuration + obj.Metadata.HeaderDuration);

            case hFrameFormats.VHT
                % Retain the actual APEP length
                apepLength = obj.VHTConfig.APEPLength;
                % Get TxTime for APEP length zero (validateConfig returns a
                % structure containing TxTime). This is equivalent to (preamble
                % + header) duration
                obj.VHTConfig.APEPLength = 0;
                psduInfo = validateConfig(obj.VHTConfig);
                psduInfo.TxTime = round(psduInfo.TxTime, 3);
                % Subtract preamble duration to get header duration (in microseconds)
                obj.Metadata.HeaderDuration = psduInfo.TxTime - obj.Metadata.PreambleDuration;
                % Reassign the PSDU length, so that configuration object
                % remains same again
                obj.VHTConfig.APEPLength = apepLength;
                % Payload duration for VHT configuration (in microseconds)
                psduInfo = validateConfig(obj.VHTConfig);
                psduInfo.TxTime = round(psduInfo.TxTime, 3);
                obj.Metadata.PayloadDuration = psduInfo.TxTime - ...
                    (obj.Metadata.PreambleDuration + obj.Metadata.HeaderDuration);

            case {hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU}
                % Retain the actual APEP length
                apepLength = obj.HESUConfig.APEPLength;
                % Get TxTime for APEP length zero (validateConfig returns a
                % structure containing TxTime). This is equivalent to (preamble
                % + header) duration
                obj.HESUConfig.APEPLength = 0;
                psduInfo = validateConfig(obj.HESUConfig);
                psduInfo.TxTime = round(psduInfo.TxTime, 3);
                ndpPEOverhead = 4; % PE overhead for NDP in microseconds
                % Subtract preamble duration and PE overhead (4 us) to get header duration (in microseconds)
                obj.Metadata.HeaderDuration = psduInfo.TxTime - obj.Metadata.PreambleDuration - ndpPEOverhead;
                % Reassign the PSDU length, so that configuration object
                % remains same again
                obj.HESUConfig.APEPLength = apepLength;
                % Payload duration for HE configuration (in microseconds)
                psduInfo = validateConfig(obj.HESUConfig);
                psduInfo.TxTime = round(psduInfo.TxTime, 3);
                obj.Metadata.PayloadDuration = psduInfo.TxTime - ...
                    (obj.Metadata.PreambleDuration + obj.Metadata.HeaderDuration);
        end

        % Form the metadata
        obj.Metadata.Duration = obj.Metadata.PreambleDuration + obj.Metadata.HeaderDuration + obj.Metadata.PayloadDuration;
        obj.Metadata.Vector = obj.TxVector;
        obj.Metadata.SourcePosition = obj.NodePosition;
        obj.Metadata.SignalPower = sigPower;
        obj.Metadata.SourceID = obj.NodeID;

        % Basic data rate and code rates for preamble
        preambleAndHeaderDataRate = 6;
        preambleAndHeaderCodeRate = 0.5;
        payloadDataRate = 0;
        payloadCodeRate = 0;
        numDataBitsPerSymbol = 0;
        isLDPCCoded = false;
        if ((obj.TxVector.FrameFormat == hFrameFormats.HE_SU)|| ...
                (obj.TxVector.FrameFormat == hFrameFormats.HE_EXT_SU))
            % Symbol duration in micro seconds
            switch heGuardInterval
                case 0.8
                    symbolDuration = 13.6;
                case 1.6
                    symbolDuration = 14.4;
                otherwise % 3.2
                    symbolDuration = 16;
            end
        else
            symbolDuration = 4; % Symbol duration in micro seconds
        end

        switch obj.TxVector.FrameFormat
            case hFrameFormats.NonHT
                NonHTMCSTable = wlan.internal.getRateTable(obj.NonHTConfig);
                payloadDataRate = NonHTMCSTable.NDBPS/symbolDuration; %Value in Mbps
                payloadCodeRate = NonHTMCSTable.Rate;
                numDataBitsPerSymbol = NonHTMCSTable.NDBPS;
            case hFrameFormats.HTMixed
                HTMCSTable = wlan.internal.getRateTable(obj.HTConfig);
                payloadDataRate = HTMCSTable.NDBPS/symbolDuration; %Value in Mbps
                payloadCodeRate = HTMCSTable.Rate;
                numDataBitsPerSymbol = HTMCSTable.NDBPS;
                isLDPCCoded = strcmp(obj.HTConfig.ChannelCoding, 'LDPC');
            case hFrameFormats.VHT
                VHTMCSTable = wlan.internal.getRateTable(obj.VHTConfig);
                payloadDataRate = VHTMCSTable.NDBPS(1)/symbolDuration; %Value in Mbps
                payloadCodeRate = VHTMCSTable.Rate;
                numDataBitsPerSymbol = VHTMCSTable.NDBPS(1);
                isLDPCCoded = strcmp(obj.VHTConfig.ChannelCoding, 'LDPC');
            case {hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU}
                [~, userCodingParams] = wlan.internal.heCodingParameters(obj.HESUConfig);
                payloadDataRate = userCodingParams.NDBPS(1)/symbolDuration; %Value in Mbps
                payloadCodeRate = userCodingParams.Rate;
                numDataBitsPerSymbol = userCodingParams.NDBPS(1);
                isLDPCCoded = strcmp(obj.HESUConfig.ChannelCoding, 'LDPC');
        end

        obj.Metadata.NumHeaderAndPreambleBits = preambleAndHeaderDataRate * ...
            (1/preambleAndHeaderCodeRate) * (obj.Metadata.PreambleDuration + obj.Metadata.HeaderDuration);

        actualDataSymbols = 0;
        paddingSymbols = 0;
        totalAmpduSymbols = 0;
        serviceBits = 16;
        tailBits = 6*(isLDPCCoded == 0); % Tail bits are only present for BCC coding

        aggregatePayloadDuration = 0;
        for count = 1:subframeCount
            actualPktSize = subFrameLengths(count);
            if (obj.TxVector.FrameFormat == hFrameFormats.NonHT) || ...
                    ((obj.TxVector.FrameFormat == hFrameFormats.HTMixed) && ...
                    ~obj.TxVector.AggregatedMPDU)
                % Not an A-MPDU. The number of OFDM symbols in the data
                % field when BCC encoding is used is given in equation
                % 19-32 of the IEEE 802.11-2016 standard.
                actualDataSymbols = ceil((serviceBits + actualPktSize * 8.0 + tailBits)/numDataBitsPerSymbol);
                paddingSymbols = 0;
            elseif ((obj.TxVector.FrameFormat == hFrameFormats.HTMixed)|| ...
                    (obj.TxVector.FrameFormat == hFrameFormats.VHT)|| ...
                    (obj.TxVector.FrameFormat == hFrameFormats.HE_SU)||...
                    (obj.TxVector.FrameFormat == hFrameFormats.HE_EXT_SU))
                if (count > 1)
                    % Assign service and tail bits to zero for subframe
                    % count greater than one
                    serviceBits = 0;
                    tailBits = 0;
                end
                actualDataSymbols = (serviceBits + actualPktSize * 8.0 + tailBits)/(numDataBitsPerSymbol);
                if (count == subframeCount)
                    payloadTxTime = obj.Metadata.PayloadDuration;
                    totalSymbols = payloadTxTime/symbolDuration;
                    totalAmpduSymbols = totalAmpduSymbols + actualDataSymbols;
                    paddingSymbols = totalSymbols - totalAmpduSymbols;
                elseif (count < subframeCount)
                    paddingSize = (subFrameIndices(count + 1))  - (subFrameIndices(count) + actualPktSize);
                    paddingSymbols = (paddingSize * 8)/(numDataBitsPerSymbol);
                    totalAmpduSymbols = totalAmpduSymbols + actualDataSymbols + paddingSymbols;
                end
            end
            % Symbol duration is in microseconds
            payloadDuration = round((actualDataSymbols * symbolDuration), 3);
            % Overhead duration is duration apart from payload for the
            % current frame which includes padding and delimiters
            % duration
            overheadDuration = round((paddingSymbols * symbolDuration), 3);
            obj.Metadata.PayloadInfo(count).Duration = payloadDuration;
            obj.Metadata.PayloadInfo(count).OverheadDuration = overheadDuration;
            obj.Metadata.PayloadInfo(count).NumOfBits = payloadDataRate(1) * ...
                (1/payloadCodeRate(1)) * payloadDuration;
            aggregatePayloadDuration = aggregatePayloadDuration+payloadDuration+overheadDuration;
        end
        % Assign aggregate payload duration
        obj.Metadata.PayloadDuration = round(aggregatePayloadDuration, 3);

        % Form waveform
        if ppdu.MACFrame.IsEmpty % Full MAC (with MAC frame bits)
            obj.TransmitWaveform.Waveform = ppdu.Data(:, obj.UserIndexSU); % Full MAC Frame(Expressed as unit8 vector)
        else % Abstracted MAC (with MAC frame metadata)
            obj.TransmitWaveform.MACFrame = ppdu.MACFrame;
        end
        obj.Metadata.SubframeCount = subframeCount;
        obj.Metadata.SubframeLengths(1:subframeCount) = subFrameLengths(1:subframeCount);
        obj.Metadata.SubframeIndexes(1:subframeCount) = subFrameIndices(1:subframeCount);
        obj.Metadata.Timestamp = ppdu.Timestamp;
        obj.Metadata.SequenceNumbers = ppdu.SequenceNumbers;
        obj.TransmitWaveform.Metadata = obj.Metadata;
        obj.TransmitWaveform.IsEmpty = false;
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
