classdef hTxContext < handle
%hTxContext Create an object to maintain context specific to transmit
%states (SENDINGDATA/WAITFORRX) for a node
%
%   OBJ = hTxContext(NUMNODES, MAXSUBFRAMES, MAXQUEUELENGTH) creates a MAC
%   layer transmit parameters configuration object OBJ, for a node with all
%   properties set to their default values. NUMNODES is the total number of
%   nodes in the network. MAXSUBFRAMES is the maximum number of subframes
%   present in an A-MPDU. MAXQUEUELENGTH is the maximum queue length.
%
%   hTxContext properties
%
%   AllocationIndex       - Allocation index for OFDMA transmission
%   MSDUDiscardCount      - Number of MSDUs to be discarded
%   MSDUDiscardIndices    - Indices of MSDUs to be discarded
%   TxStationIDs          - Node ID's of scheduled stations
%   IsShortFrame          - Indicates shorter frames when true
%   MSDUBytesNoAck        - Number of MSDU Bytes with NoAck
%   DataFrameSent         - Indicates the status of data frame
%   RTSSent               - Flag for RTS frame
%   WaitingForCTS         - Indicates the status of waiting for CTS frame
%   TxACs                 - Access categories of scheduled stations
%   TxInvokeTime          - Duration required to start sending frame to
%                           physical layer
%   FrameTxTime           - Duration to transmit frame to physical layer
%   TxSSN                 - Transmission frame starting sequence number
%   TxPSDULength          - Length of PSDU
%   TxMPDULengths         - Length of MPDUs
%   TxSubframeLengths     - Length of A-MPDU subframes
%   TxMSDUCount           - Number of MSDUs aggregated per user
%   TxMCS                 - Modulation and coding scheme (MCS) index
%   RTSRate               - MCS index used for transmitting the RTS frame
%   NoAck                 - Flag to enable/disable acknowledgment for RTS
%                           frame
%   TxFrame               - Frame dequeued from MAC transmission queue
%   TxState               - State of the Sending data state machine
%   PHYTxEntryTS          - Physical layer transmission entry timestamp
%   WaitForPHYEntry       - Entry Flag for WaitForPHY state
%   SequenceCounter       - MPDU sequence counter
%   InitialSubframesCount - Number of initial subframes in PSDU
%   TxWaitingForAck       - Data units waiting for acknowledgment
%   TxMSDULengths         - Length of MSDU buffer for transmission
%   TxSequenceNumbers     - Sequence numbers of the frame
%   ShortRetries          - Retry counts for the short frames
%   LongRetries           - Retry counts for the long frames
%   CfgHT                 - HT configuration object
%   CfgVHT                - VHT configuration object
%   CfgHE                 - HE configuration object
%   CfgNonHT              - Non-HT configuration object
%   CfgMAC                - MAC configuration object

%   Copyright 2021 The MathWorks, Inc.

properties
    %MSDUDiscardCount Number of MSDUs to be discarded
    %   MSDUDiscardCount is an array of size 9 x 1 where 9 is the
    %   maximum number of stations supported in downlink Multi-User(MU)
    %   transmission. Each element represents number of MSDUs to be
    %   discarded by a node.
    MSDUDiscardCount = zeros(9, 1);
    
    %MSDUDiscardIndices Indices of MSDUs to be discarded
    %   MSDUDiscardIndices is an array of size M x 9 where M is the
    %   maximum of subframes that can be aggregated and 9 is the
    %   maximum number of stations supported in downlink Multi-User(MU)
    %   transmission. Each column represents indices of packets to be
    %   discarded from MAC queues.
    MSDUDiscardIndices;
    
    %TxStationIDs Node ID's of scheduled stations
    %   TxStationIDs is a column vector of size 9 where 9 is the maximum
    %   number of users supported in a downlink Multi-User(MU)
    %   transmission. Each element represents node ID of scheduled
    %   stations. The default value is [0; 0; 0; 0; 0; 0; 0; 0; 0].
    TxStationIDs = zeros(9,1);
    
    %IsShortFrame Indicates shorter frames when true
    %   Set this property to true to indicate shorter frames. The default
    %   value is false.
    IsShortFrame = false;
    
    %MSDUBytesNoAck Number of MSDU Bytes with NoAck
    %   MSDUBytesNoAck is a scalar representing number of MSDUBytes with
    %   NoAck.
    MSDUBytesNoAck = 0;
    
    %DataFrameSent Indicates the status of data frame
    %   Set this property to true if data frame is sent to PHY layer.
    DataFrameSent = false;
    
    %RTSSent Flag for RTS frame
    %   Set this property to true if RTS frame is sent. The default
    %   value is false.
    RTSSent = false;
    
    %WaitingForCTS Indicates the status of waiting for CTS frame
    %   Set this Flag to true if waiting for CTS frame.
    WaitingForCTS = false;
    
    %TxACs Access categories of scheduled stations
    %   TxACs is a column vector of size 9 representing the access
    %   categories of scheduled stations.
    TxACs = zeros(9,1);
    
    %TxInvokeTime Duration required to start sending frame to physical layer
    %   TxInvokeTime is a scalar representing duration required to start
    %   sending frame to physical layer. Default value is 16 (SIFS time).
    TxInvokeTime = 16;
    
    %FrameTxTime Duration to transmit frame to physical layer
    %   FrameTxTime is a scalar representing duration to transmit frame
    %   to physical layer.
    FrameTxTime = 0;
    
    %TxSSN Tx frame starting sequence numbers corresponding to each AC
    %   TxSSN is a column vector of size 4 representing Tx frame starting
    %   sequence number.
    TxSSN = zeros(4,1);
    
    %TxPSDULength Length of PSDU
    %   TxPSDULength is a column vector of size 9 where 9 is the maximum
    %   number of stations supported in multi-user(MU) transmission and
    %   each element represents length of PSDU transmitted to corresponding
    %   station.
    TxPSDULength = zeros(9,1);
    
    %TxMPDULengths Length of MPDUs
    %   TxMPDULengths is an array of size M-by-9, where M represents the
    %   maximum number of subframes in an A-MPDU, and 9 represents the
    %   maximum number of stations addressed in an A-MPDU.
    TxMPDULengths;
    
    %TxSubframeLengths Length of A-MPDU subframes
    %   TxSubframeLengths is an array of size M-by-9, where M represents
    %   the maximum number of subframes in an A-MPDU, and 9 represents
    %   the maximum number of stations addressed in an A-MPDU. These lengths
    %   include the MPDU length, delimiter, and optional padding.
    TxSubframeLengths;
    
    %TxMSDUCount Number of MSDUs aggregated per user
    %   TxMSDUCount is a column vector of size 9 representing number of
    %   MSDUs aggregated per user.
    TxMSDUCount = zeros(9,1);
    
    %TxMCS Modulation and coding scheme (MCS) index
    %   TxMCS is a vector of size 9 x 1 where 9 is the maximum number of
    %   stations supported in multi-user(MU) transmission and each element
    %   represents MCS index used for transmitting a frame to corresponding
    %   station.
    TxMCS = zeros(9, 1);
    
    %RTSRate MCS index used for transmitting the RTS frame
    %   RTSRate is a scalar representing MCS index used for transmitting an
    %   RTS frame. The default value is 0.
    RTSRate = 0;
    
    %AllocationIndex Allocation index for OFDMA transmission
    %   AllocationIndex is a scalar representing allocation index for OFDMA
    %   transmission.
    AllocationIndex = 0;
    
    %NoAck Flag to enable/disable acknowledgment for RTS frame
    %   Set this to true to disable acknowledgment for RTS frame.
    NoAck = false;
    
    %TxFrame Frame dequeued from MAC transmission queue
    %   TxFrame is a struct representing frame dequeued from MAC
    %   transmission queue.
    TxFrame;
    
    %TxState State of the Sending data state machine (either 1 | 2 | 3 | 4)
    %   1 - TXINIT_STATE
    %   2 - TRANSMITDATA_STATE
    %   3 - TRANSMITRTS_STATE
    %   4 - WAITFORPHY_STATE
    TxState = 1;     % Default state is 'Tx Initialization'
    
    %PHYTxEntryTS PHY transmission entry timestamp
    %   PHYTxEntryTS is a scalar representing PHY transmission entry
    %   timestamp.
    PHYTxEntryTS = 0;
    
    %WaitForPHYEntry Entry Flag for WaitForPHY state
    %   Set this flag to true once WaitForPHY state is entered.
    WaitForPHYEntry = false;
    
    %SequenceCounter MPDU sequence counter
    % SequenceCounter is a vector of size M x N representing MPDU
    % sequence counter in the range of [0 -  4095] where M  is the
    % number of stations and N is the maximum number of ACs.
    SequenceCounter;
    
    %InitialSubframesCount Number of initial subframes in PSDU
    % InitialSubframesCount is a array of size M x N representing
    % number of initial subframes in PSDU where M  is the number of
    % stations and N is the maximum number of ACs.
    InitialSubframesCount;
    
    %TxWaitingForAck Data units waiting for acknowledgment
    %   TxWaitingForAck is an array of size M x N where M is the number of
    %   stations in the network and N is the maximum number of ACs. Each
    %   element is a scalar indicating number of data units waiting for
    %   acknowledgment.
    TxWaitingForAck;
    
    %TxMSDULengths Length of each MSDU buffered for transmission
    % TxMSDULengths is an array of size M x N x O where M is the number of
    % stations in network, N is the maximum number of ACs and O is the
    % maximum queue length. Each element represents length of MSDU present
    % in the queue of corresponding station and corresponding AC.
    TxMSDULengths;
    
    %TxSequenceNumbers Sequence Numbers of the frame
    %   TxSequenceNumbers holds the sequence numbers of the MPDUs in a
    %   frame maintained per AC.
    TxSequenceNumbers;
    
    %ShortRetries Retry counts for the short frames
    %   ShortRetries holds the retry count for the transmitted frame,
    %   per station and per AC, when the frame length is less than RTS
    %   threshold.
    ShortRetries;
    
    %LongRetries Retry counts for the long frames
    %   LongRetries holds the retry count for the transmitted frame,
    %   per station and per AC, when the frame length is greater than RTS
    %   threshold.
    LongRetries;
    
    %MACTxTimeStamp Simulation timestamp of the last MAC frame transmitted.
    %   MACTxTimeStamp stores the simulation timestamp of the last MAC
    %   frame transmitted. This value is used to calculate the statisic MAC
    %   average time per frame
    MACTxTimeStamp;
    
    %PHY configuration objects for generating data frame and calculating
    %frame transmission time
    CfgHT;          % HT Config object
    CfgVHT;         % VHT Config object
    CfgHE;          % HE Config object
    CfgNonHT;       % Non-HT Config object
    CfgMAC;         % MAC Config object
end

% Constant properties
properties(Constant, Hidden)
    % SendingData states
    TXINIT_STATE =1;
    TRANSMITDATA_STATE = 2;
    TRANSMITRTS_STATE = 3;
    WAITFORPHY_STATE = 4;
    
    %BasicRate Basic rate
    BasicRate = 0;
end

% Public methods
methods
    function obj = hTxContext(numNodes, maxSubframes, maxQueueLength, varargin)
        % Initialize
        obj.SequenceCounter = zeros(numNodes+2, 4);
        obj.InitialSubframesCount = zeros(numNodes+2, 4);
        obj.TxWaitingForAck = zeros(numNodes+2, 4);
        obj.ShortRetries = zeros(numNodes+2, 4);
        obj.LongRetries = zeros(numNodes+2, 4);
        obj.MSDUDiscardIndices = zeros(maxSubframes, 9);
        obj.TxMSDULengths = zeros(numNodes+2, 4, maxQueueLength);
        obj.TxMPDULengths = zeros(maxSubframes, 9);
        obj.TxSubframeLengths = zeros(maxSubframes, 9);
        
        % Fill PHY configuration objects for Sending data
        obj.CfgHT = wlanHTConfig('ChannelBandwidth', 'CBW20');
        obj.CfgVHT = wlanVHTConfig('ChannelBandwidth', 'CBW20');
        obj.CfgHE = wlanHESUConfig('ChannelBandwidth', 'CBW20');
        obj.CfgNonHT = wlanNonHTConfig('ChannelBandwidth', 'CBW20');
        obj.CfgMAC = wlanMACFrameConfig('FrameType', 'QoS Data');
        
        % Assign properties specified as name-value pairs
        for idx = 1:2:numel(varargin)
            obj.(varargin{idx}) = varargin{idx+1};
        end
        
        obj.TxFrame = repmat(struct('MSDUCount', 0, ...
            'MSDULength', zeros(maxSubframes, 1), ...
            'AC', 0, ...
            'DestinationID', 0, ...
            'DestinationMACAddress', '000000000000', ...
            'FourAddressFrame', false(maxSubframes, 1), ...
            'MeshSourceAddress', repmat('000000000000', maxSubframes, 1), ...
            'MeshDestinationAddress', repmat('000000000000', maxSubframes, 1), ...
            'MeshSequenceNumber', zeros(maxSubframes, 1), ...
            'Timestamp', zeros(maxSubframes, 1), ...
            'Data', []), 9, 1);
    end
end

end
