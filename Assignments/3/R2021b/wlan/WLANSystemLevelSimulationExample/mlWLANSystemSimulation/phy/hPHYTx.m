classdef hPHYTx < hPHYTxInterface
%hPHYTx Create an object for WLAN PHY transmitter
%	WLANPHYTx = hPHYTx creates a WLAN PHY transmitter object
%	supporting the following operations:
%       - Handling requests from MAC layer
%       - Creating waveform (PPDU)
%       - Handling transmit power (Tx power)
%
%   WLANPHYTx = hPHYTx(Name, Value) creates a WLAN PHY transmitter object
%   with the specified property Name set to the specified Value. You can
%   specify additional name-value pair arguments in any order as (Name1,
%   Value1, ..., NameN, ValueN).
%
%   hPHYTx methods:
%
%   run     - Run the physical layer transmit operations
%
%   hPHYTx properties:
%
%   NodeID           - Specifies the node identifier
%   NodePosition     - Specifies the node position
%   IsNodeTypeAP     - Specifies the type of node (AP/STA)
%   TxPower          - Specifies the transmission power of the node in dBm
%   TxGain           - Specifies the transmission gain of the node in dB

% Copyright 2021 The MathWorks, Inc.

    % Information from MAC
    properties (Access = private)
        % PHY Tx buffer to store the input PSDU.
        TxData;

        % User index for single user processing. Index '1' will be used in
        % case of single user and downlink multi-user reception. Indices
        % greater than '1' will be used in case of downlink multi-user
        % transmission and uplink multi-user reception.
        UserIndexSU = 1;

        % Timestamp of subframes in current frame. As MSDU aggregation is not
        % supported, each subframe contains only single MSDU.
        MSDUTimestamps;

        % Maximum subframes in an AMPDU
        MaxSubframes = 64;

        % Channel Bandwidth
        ChannelBandwidth = 20;

        % Number of users in MU PPDU transmission
        NumUsers;

        % Number of space time streams
        NumSTS
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

        % HE-MU configuration object
        HEMUConfig;
    end

    % Spatial reuse and frequency parameters
    properties (Hidden)
        % Tx Power limit flag
        LimitTxPower = false;

        % OBSS Threshold (dBm)
        OBSSPDThreshold = -82;

        % SR operation flag
        EnableSROperation = false;

        % Tx Power reference (dBm)
        TXPowerReference = 21;

        % Operating frequency ID
        OperatingFreqID = 1;

        % Frequency of operation in GHz
        OperatingFrequency = 5.180;
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

        % Maximum number of users
        MaxMUUsers = 9;
    end

    properties (Hidden)
        % Structure holding output data for the PHY transmitter
        TransmitWaveform

        % Structure to MAC layer which indicates the transmission start
        % ('TXSTARTCONFIRM') or transmission end ('TXENDCONFIRM') indication
        % for a corresponding MAC request.
        PHYConfirmIndication
    end

methods
    function obj = hPHYTx(varargin)
        %hPHYTx Create an instance of PHY transmitter class

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

        % HE-MU configuration object
        allocationIndex = 0;
        obj.HEMUConfig = wlanHEMUConfig(allocationIndex);

        obj.MSDUTimestamps = zeros(obj.MaxSubframes, 9);

        % Initialize the structures
        obj.TxVector = struct('IsEmpty', true, ...
            'EnableSROperation', false, ...
            'BSSColor', 1, ...
            'LimitTxPower', false, ...
            'OBSSPDThreshold', -62, ...
            'NumTransmitAntennas', 0, ...
            'NumSpaceTimeStreams', 0, ...
            'FrameFormat', 0, ...
            'AggregatedMPDU', 0, ...
            'ChannelBandwidth', 20, ...
            'MCSIndex', zeros(obj.MaxMUUsers, 1), ...
            'PSDULength', zeros(obj.MaxMUUsers, 1), ...
            'RSSI', 0, ...
            'MessageType', 0, ...
            'AllocationIndex', 0, ...
            'StationIDs', zeros(obj.MaxMUUsers, 1), ...
            'TxPower', zeros(obj.MaxMUUsers, 1));
        obj.Metadata = struct('Vector', obj.TxVector, ...
            'PayloadInfo', repmat(struct('OverheadDuration', 0,'Duration', 0,'NumOfBits', 0), [1, obj.MaxSubframes]), ...
            'SourcePosition', zeros(1, 3), ...
            'PreambleDuration', 0, ...
            'HeaderDuration', 0, ...
            'Duration', 0, ...
            'PayloadDuration', 0, ...
            'SignalPower', 0, ...
            'SourceID', 0, ...
            'SubframeCount', 0, ...
            'SubframeLengths', zeros(1, obj.MaxSubframes), ...
            'SubframeIndexes', zeros(1, obj.MaxSubframes), ...
            'NumHeaderAndPreambleBits', 0, ...
            'StartTime', 0, ...
            'Timestamp', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'SequenceNumbers', zeros(obj.MaxSubframes, obj.MaxMUUsers));
        macFrameConfig = struct('IsEmpty', true, ...
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
            'TID', 0, ...
            'SequenceNumber', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'MPDUAggregation', false, ...
            'PayloadLength', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'MPDULength', zeros(obj.MaxSubframes, obj.MaxMUUsers), ...
            'PSDULength', zeros(obj.MaxMUUsers, 1), ...
            'FCSPass', true(obj.MaxSubframes, obj.MaxMUUsers), ...
            'DelimiterFails', false(obj.MaxSubframes, obj.MaxMUUsers));
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
    %   IsEmpty             - Boolean value to determine whether the
    %                         input is valid or not.
    %   EnableSROperation   - Boolean flag, that defines whether spatial
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
    %   FrameFormat         - Frame formats ('Non-HT', 'VHT', 'HE-SU',
    %                         'HE-MU', 'HT-Mixed', 'HE-EXT-SU'). The
    %                         default value is 'Non-HT'.
    %   AggregatedMPDU      - Boolean flag that represents whether the
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
    %
    %   FRAMETOPHY is a structure containing the frame metadata
    %   received from the MAC layer. When the field IsEmpty is
    %   false in this structure, the corresponding waveform
    %   transmission is indicated through the TransmitWaveform
    %   property.
    %
    %   Structure 'FRAMETOPHY' contains the following fields:
    %
    %   IsEmpty            - Boolean value, that defines whether the frame
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
    %   IsEmpty	       - Boolean value, that defines whether the MAC Frame
    %                    is empty or not.
    %   FrameType      - FrameType Type of the MAC frame. Specify the frame
    %                    type as one of 'RTS' | 'CTS' | 'ACK' | 'Block Ack'
    %                    | 'Trigger' | 'Data' | 'Null' | 'QoS Data' |'QoS
    %                    Null' | 'Beacon'. The default value is 'Data'.
    %   FrameFormat	   - Frame formats ('Non-HT', 'VHT', 'HE-SU', 'HE-MU',
    %                    'HT-Mixed', 'HE-EXT-SU'). The default value is
    %                    'Non-HT'.
    %   Duration	   - Duration of the frame
    %   Retransmission - Boolean array. Each element in the array states
    %                    whether a subframe is being retransmitted or not.
    %   IsMeshFrame	   - Boolean flag, that defines whether received frame
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
    %   MPDUAggregation- Boolean value, states whether the frame is
    %                    aggregated or not
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

    function duration = getPreambleDuration()
    %getPreambleDuration Returns PHY preamble duration in second

        % L-STF and L-LTF duration (16 microseconds)
        duration = 16;
    end
end

methods (Access = private)
    function sigPower = adjustTxPower(obj)
    % adjustTxPower Return the Adjusted transmit power in conjunction
    % with OBSS PD threshold

    % If the transmit power restriction period is active and OBSS PD
    % threshold greater than minimum OBSS PD threshold, adjust the
    % transmit power
    %
    % Reference: IEEE P802.11ax/D8.0 Section 26.10.2.4
        if obj.LimitTxPower && (obj.OBSSPDThreshold > obj.OBSSPDThresholdMin)
            % Restrict the Tx Power
            TxPowerMax = obj.TXPowerReference - (obj.OBSSPDThreshold - obj.OBSSPDThresholdMin);
            sigPower = min(TxPowerMax, obj.TxVector.TxPower(obj.UserIndexSU));
            obj.PhyNumTxWhileActiveOBSSTx = obj.PhyNumTxWhileActiveOBSSTx + 1;
        else
            sigPower = obj.TxVector.TxPower(obj.UserIndexSU);
        end
    end

    function outputSamples = applyTxPowerLevelAndGain(obj, iqSamples, gain)
        %applyTxPowerLevelAndGain Applies Tx power level and gain to IQ
        %samples

        % Apply default Tx power to IQ samples.
        scale = 10.^((-30 + obj.TxVector.TxPower(obj.UserIndexSU) + gain)/20);
        outputSamples = iqSamples * scale;
    end

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

            obj.NumSTS = obj.TxVector.NumSpaceTimeStreams;
            obj.ChannelBandwidth = obj.TxVector.ChannelBandwidth;

            % Configure the PHY object using transmission vector
            % information
            switch obj.TxVector.FrameFormat
                case hFrameFormats.NonHT
                    obj.NonHTConfig.NumTransmitAntennas = obj.TxVector.NumTransmitAntennas;
                    obj.NonHTConfig.ChannelBandwidth = obj.getChannelBandwidthStr(obj.TxVector.ChannelBandwidth);
                    obj.NonHTConfig.PSDULength = obj.TxVector.PSDULength(obj.UserIndexSU);
                    obj.NonHTConfig.MCS = obj.TxVector.MCSIndex(obj.UserIndexSU);

                case hFrameFormats.HTMixed
                    obj.HTConfig.PSDULength = obj.TxVector.PSDULength(obj.UserIndexSU);
                    obj.HTConfig.ChannelBandwidth = obj.getChannelBandwidthStr(obj.TxVector.ChannelBandwidth);
                    obj.HTConfig.MCS = obj.TxVector.MCSIndex(obj.UserIndexSU);
                    obj.HTConfig.AggregatedMPDU = obj.TxVector.AggregatedMPDU;
                    obj.HTConfig.NumSpaceTimeStreams = obj.TxVector.NumSpaceTimeStreams;
                    obj.HTConfig.NumTransmitAntennas = obj.TxVector.NumTransmitAntennas;

                case hFrameFormats.VHT
                    obj.VHTConfig.APEPLength = obj.TxVector.PSDULength(obj.UserIndexSU);
                    obj.VHTConfig.ChannelBandwidth = obj.getChannelBandwidthStr(obj.TxVector.ChannelBandwidth);
                    obj.VHTConfig.MCS = obj.TxVector.MCSIndex(obj.UserIndexSU);
                    obj.VHTConfig.NumSpaceTimeStreams = obj.TxVector.NumSpaceTimeStreams;
                    obj.VHTConfig.NumTransmitAntennas = obj.TxVector.NumTransmitAntennas;

                case {hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU}
                    obj.HESUConfig.APEPLength = obj.TxVector.PSDULength(obj.UserIndexSU);
                    obj.HESUConfig.ChannelBandwidth = obj.getChannelBandwidthStr(obj.TxVector.ChannelBandwidth);
                    obj.HESUConfig.MCS = obj.TxVector.MCSIndex(obj.UserIndexSU);
                    obj.HESUConfig.NumSpaceTimeStreams = obj.TxVector.NumSpaceTimeStreams;
                    obj.HESUConfig.NumTransmitAntennas = obj.TxVector.NumTransmitAntennas;
                    obj.HESUConfig.BSSColor = obj.TxVector.BSSColor;
                    obj.HESUConfig.ExtendedRange = (obj.TxVector.FrameFormat == hFrameFormats.HE_EXT_SU);

                case hFrameFormats.HE_MU
                    obj.HEMUConfig = wlanHEMUConfig(obj.TxVector.AllocationIndex);
                    obj.HEMUConfig.NumTransmitAntennas = obj.TxVector.NumTransmitAntennas;
                    obj.HEMUConfig.BSSColor = obj.TxVector.BSSColor;
                    obj.NumUsers = numel(obj.HEMUConfig.User);
                    for userIndex = 1:obj.NumUsers
                        obj.HEMUConfig.User{userIndex}.MCS = obj.TxVector.MCSIndex(userIndex);
                        obj.HEMUConfig.User{userIndex}.APEPLength = obj.TxVector.PSDULength(userIndex);
                        obj.HEMUConfig.User{userIndex}.STAID = obj.TxVector.StationIDs(userIndex);
                        % All users assumed to have same number of space-time streams
                        obj.HEMUConfig.User{userIndex}.NumSpaceTimeStreams = obj.TxVector.NumSpaceTimeStreams;
                    end
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
        msduTimestamps = zeros(obj.MaxSubframes, 9);
        msduSeqNums = zeros(obj.MaxSubframes, 9);

        subframeCount = ppdu.NumSubframes(obj.UserIndexSU); % Number of subframes
        msduTimestamps(1:subframeCount, obj.UserIndexSU) = ...
            ppdu.Timestamp(1:subframeCount, obj.UserIndexSU);
        msduSeqNums(1:subframeCount, obj.UserIndexSU) = ...
            ppdu.SequenceNumbers(1:subframeCount, obj.UserIndexSU);

        switch obj.TxVector.FrameFormat
        % Calculate the duration of the waveform
            case hFrameFormats.NonHT
                % Generate Non-HT waveform
                waveform = wlanWaveformGenerator(ppdu.Data(:, obj.UserIndexSU), obj.NonHTConfig);
            case hFrameFormats.HTMixed
                % Generate HT waveform
                waveform = wlanWaveformGenerator(ppdu.Data(:, obj.UserIndexSU), obj.HTConfig);
            case hFrameFormats.VHT
                % Generate VHT waveform
                waveform = wlanWaveformGenerator(ppdu.Data(:, obj.UserIndexSU), obj.VHTConfig);
            case {hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU}
                % Generate HE-SU waveform
                waveform = wlanWaveformGenerator(ppdu.Data(:, obj.UserIndexSU), obj.HESUConfig);
            otherwise % HE_MU format
                % Create a cell array for PSDUs of all users to generate
                % MU-PPDU
                txPSDUs = cell(obj.NumUsers, 1);
                for i = 1:numel(txPSDUs)
                    txPSDUs{i} = ppdu.Data(:, i);
                end

                % Generate HE-MU waveform
                waveform = wlanWaveformGenerator(txPSDUs, obj.HEMUConfig);
        end

        % Number of samples and streams in waveform
        [numSamples, ~] = size(waveform);

        % Apply Tx gain to the waveform
        waveform = obj.applyTxPowerLevelAndGain(waveform, obj.TxGain);

        % Set transmission time of the waveform
        obj.Metadata.Duration = round((numSamples*(1/obj.ChannelBandwidth)), 3);

        % Preamble duration for all frame formats (in microseconds)
        obj.Metadata.PreambleDuration = obj.getPreambleDuration;

        % Header duration
        obj.Metadata.HeaderDuration = round(getHeaderDuration(obj, obj.TxVector.FrameFormat), 3);

        % Payload duration
        obj.Metadata.PayloadDuration = round((obj.Metadata.Duration - (obj.Metadata.PreambleDuration + obj.Metadata.HeaderDuration)), 3);

        % Form the metadata
        obj.Metadata.Vector = obj.TxVector;
        obj.Metadata.SourcePosition = obj.NodePosition;
        obj.Metadata.SignalPower = sigPower;
        obj.Metadata.SourceID = obj.NodeID;
        obj.Metadata.Timestamp = msduTimestamps;
        obj.Metadata.SubframeCount = subframeCount;
        obj.Metadata.SequenceNumbers = msduSeqNums;

        % Form transmit waveform
        obj.TransmitWaveform.Waveform = waveform;
        obj.TransmitWaveform.Metadata = obj.Metadata;
        obj.TransmitWaveform.IsEmpty = false;
    end

    function headerDuration = getHeaderDuration(obj, frameFormat)
        % L-Sig duration (4 microseconds)
        headerDuration = 4;

        % To Protect against MU-MIMO
        numSTS = sum(obj.NumSTS);

        switch frameFormat
            case hFrameFormats.HTMixed
                numESS = 0;
                htHeaderSyms = 2 + 1 + wlan.internal.numVHTLTFSymbols(numSTS) + wlan.internal.numHTELTFSymbols(numESS);
                headerDuration = headerDuration + htHeaderSyms*4;

            case hFrameFormats.VHT
                vhtHeaderSyms = 2 + 1 + wlan.internal.numVHTLTFSymbols(numSTS) + 1;
                headerDuration = headerDuration + vhtHeaderSyms*4;

            case {hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU, hFrameFormats.HE_MU}
                % Get HE timing related constants
                trc = wlan.internal.heTimingRelatedConstants(obj.HESUConfig.GuardInterval,obj.HESUConfig.HELTFType,4,0,0);

                if (frameFormat == hFrameFormats.HE_SU)
                	headerDuration  = (trc.TLSIG+trc.TRLSIG+trc.THESIGA+trc.THESTFNT+trc.THELTFSYM*wlan.internal.numVHTLTFSymbols(numSTS))*1e-3;
                elseif (frameFormat == hFrameFormats.HE_EXT_SU)
                	headerDuration  = (trc.TLSIG+trc.TRLSIG+trc.THESIGAR+trc.THESTFNT+trc.THELTFSYM*wlan.internal.numVHTLTFSymbols(numSTS))*1e-3;
                elseif (frameFormat == hFrameFormats.HE_MU)
                	sigbInfo = wlan.internal.heSIGBCodingInfo(obj.HEMUConfig);
                	numSIGBSym = sigbInfo.NumSymbols;
                	headerDuration  = (trc.TLSIG+trc.TRLSIG+trc.THESIGA+trc.THESIGB*numSIGBSym+trc.THESTFNT+trc.THELTFSYM*wlan.internal.numVHTLTFSymbols(numSTS))*1e-3;
                end
        end
    end
end
end
