classdef hEDCAMAC < handle
%hEDCAMAC Create a WLAN EDCA MAC object
%
%   OBJ = hEDCAMAC(NUMNODES, MAXQUEUELENGTH, MAXSUBFRAMES) creates a WLAN
%   EDCA MAC object, OBJ, for a node. NUMNODES is the total number of nodes
%   in the WLAN network. MAXQUEUELENGTH is the maximum queue length.
%   MAXSUBFRAMES is the maximum number of subframes present in an A-MPDU.
%   This object provides functionality to get notified about following
%   events:
%   1. <a href="matlab:help('hEDCAMAC.TxEvent')">TxEvent</a>
%   2. <a href="matlab:help('hEDCAMAC.RxEvent')">RxEvent</a>
%   3. <a href="matlab:help('hEDCAMAC.TxStatusEvent')">TxStatusEvent</a>
%   4. <a href="matlab:help('hEDCAMAC.TxEnqueueEvent')">TxEnqueueEvent</a>
%   5. <a href="matlab:help('hEDCAMAC.TxDiscardEvent')">TxDiscardEvent</a>
%   To register callback for an event, use <a
%   href="matlab:help('addlistener')">addlistener</a>.
%
%   hEDCAMAC properties:
%
%   Bandwidth                   - Bandwidth of the channel
%   Use6MbpsForControlFrames    - Force 6 Mbps for control frames
%   BasicRates                  - Non-HT rates supported by the network
%   TxFormat                    - Physical layer frame format
%   EnableSROperation           - Enable spatial reuse operation
%   NumTxChains                 - Number of space time streams
%   BSSColor                    - Basic service set (BSS) color identifier
%   OBSSPDThreshold             - OBSS PD threshold
%   DisableRTS                  - Disable RTS transmission
%   RTSThreshold                - Threshold for frame length above which RTS is
%                                 transmitted
%   MPDUAggregation             - Enable frame aggregation
%   DisableAck                  - Disable acknowledgments
%   MaxDLStations               - Maximum number of downlink Stations
%   MaxShortRetries             - Maximum retries for short frames
%   MaxLongRetries              - Maximum retries for long frames
%   NodeID                      - Node identifier
%   MACAddress                  - MAC address of node
%   BSSID                       - BSS identifier
%   NumNodes                    - Number of nodes in the network
%   CWMin                       - Minimum range of contention window for four ACs
%   CWMax                       - Maximum range of contention window for four ACs
%   AIFSSlots                   - Arbitrary interframe slot values for four ACs
%   FrameAbstraction            - Enable MAC frame abstraction
%   TxEvent                     - Event to notify about frame transmission from MAC to PHY
%   RxEvent                     - Event to notify about received MAC frame
%   TxStatusEvent               - Event to notify about the transmission status (success or failure)
%                                 of a frame
%   TxEnqueueEvent              - Event to notify about entry of a data packet
%                                 into MAC queue from application layer
%   TxDiscardEvent              - Event to notify about discarding data packets
%                                 from MAC queue

%   Copyright 2021 The MathWorks, Inc.

properties
    % Configurable properties - includes user configurable and those
    % configured from simulation script

    % User configurable

    %Bandwidth Bandwidth of the channel (in MHz)
    %   Specify Bandwidth in MHz as 20, 40, 80, or 160. The default value
    %   is 20.
    Bandwidth = 20;

    %Use6MbpsForControlFrames Force 6 Mbps for control frames
    %   Set this property to true to indicate date rate of 6 Mbps should be
    %   used for control frames. The default value is false.
    Use6MbpsForControlFrames (1, 1) logical = false;

    %BasicRates Non-HT rates supported by the network
    %   Specify Non-HT rates supported by the network in Mbps as a vector
    %   which is subset of [6 9 12 18 24 36 48 54]. The default value is [6
    %   12 24]. This property is set to 6, if Use6MbpsForControlFrames
    %   property is set to true.
    BasicRates {mustBeInteger, mustBeMember(BasicRates, [6 9 12 18 24 36 48 54])} = [6 12 24];

    %TxFormat Physical layer frame format
    %   TxFormat is the physical layer (PHY) frame format, specified as a
    %   constant value of class hFrameFormats. Specify this value as one of
    %   these: hFrameFormats.NonHT, hFrameFormats.HTMixed,
    %   hFrameFormats.VHT, hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU, or
    %   hFrameFormats.HE_MU. See <a
    %   href="matlab:help('hFrameFormats')">hFrameFormats</a> class for
    %   valid input values.
    TxFormat = hFrameFormats.NonHT;

    %EnableSROperation Enable spatial reuse(SR) operation
    %   Set this property to true to indicate that spatial reuse
    %   operation is enabled. The default value is false.
    EnableSROperation (1, 1) logical = false;

    %NumTxChains Number of space time streams
    %   NumTxChains is a scalar representing number of multiple streams
    %   of data to transmit using the multiple-input multiple-output
    %   (MIMO) capability. The default value is 1.
    NumTxChains (1, 1) {mustBeNumeric} = 1;

    %BSSColor Basic service set (BSS) color identifier
    %   Specify the BSS color number of a basic service set as an integer
    %   scalar between 0 to 63, inclusive. The default is 0. This property
    %   is applicable when EnableSROperation is set to true.
    BSSColor (1,1) {mustBeInteger, mustBeGreaterThanOrEqual(BSSColor,0), mustBeLessThanOrEqual(BSSColor,63)} = 0;

    %OBSSPDThreshold OBSS PD threshold
    %   Specify OBSS PD Threshold as an integer in the range of [-62 -
    %   -82]. The default value is -82.
    OBSSPDThreshold (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(OBSSPDThreshold,-82), mustBeLessThanOrEqual(OBSSPDThreshold, -62)} = -82;

    %DisableRTS Disable RTS transmission
    %   Set this property to true to disable the RTS/CTS exchange in the
    %   simulation.
    DisableRTS (1, 1) logical = false;

    %RTSThreshold Threshold for frame length below which RTS is not
    %transmitted
    %   RTSThreshold is a scalar representing threshold value for frame
    %   length below which RTS is not transmitted. Value must be in the
    %   range [0 65535]. The default value is 65535. This property is
    %   applicable only when DisableRTS is set to false.
    RTSThreshold (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(RTSThreshold, 0)} = 65535;

    %MPDUAggregation Enable frame aggregation
    %   Set this property to true to aggregate multiple MPDUs into an
    %   aggregated MPDU (A-MPDU) for transmission. The default value is
    %   false. This property is only applicable when TxFormat is set to
    %   "HTMixed".
    MPDUAggregation (1, 1) logical = false;

    %DisableAck Disable acknowledgments
    %   Set this property to true to disable acknowledgments (no
    %   acknowledgment in response to data frame). The default value is
    %   true.
    DisableAck (1, 1) logical = true;

    %MaxDLStations Maximum number of downlink Stations
    %    MaxDLStations is a scalar representing maximum number of downlink
    %    Stations. Specify this property as an integer in the range of
    %    [1-9] only when TxFormat is set to "HE-MU" and 1 for all other
    %    formats.
    MaxDLStations (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(MaxDLStations,1), mustBeLessThanOrEqual(MaxDLStations,9)} = 1;

    %MaxShortRetries Maximum retries for short frames
    MaxShortRetries (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(MaxShortRetries,1), mustBeLessThanOrEqual(MaxShortRetries,255)} = 7;

    %MaxLongRetries Maximum retries for long frames
    MaxLongRetries (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(MaxLongRetries,1), mustBeLessThanOrEqual(MaxLongRetries,255)} = 7;

    % Configurable from simulation script

    %NodeID Node identifier
    %   NodeID is an integer identifying the node in the network
    NodeID (1, 1) {mustBeInteger} = 0;

    %MACAddress MAC address of node
    %   Specify MAC address of the node as a 12-element character vector or
    %   string scalar denoting a 6-octet hexadecimal value.
    MACAddress = '000000000000';

    %BSSID BSS identifier
    %   BSSID is the MAC address of the access point (AP)
    BSSID = '00123456789B';

    %NumNodes Number of nodes in the network
    %   NumNodes is a scalar representing number of nodes in the
    %   network. The default value is 1.
    NumNodes = 1;

    %CWMin Minimum range of contention window for four ACs
    %   Minimum size of contention window for Best Effort, Background,
    %   Video, and Voice traffic.
    CWMin (1, 4) {mustBeInteger, mustBeGreaterThanOrEqual(CWMin,1), mustBeLessThanOrEqual(CWMin,1023)} = [15 15 7 3];

    %CWMax Maximum range of contention window for four ACs
    %   Maximum size of contention window for Best Effort, Background,
    %   Video, and Voice traffic.
    CWMax (1, 4) {mustBeInteger, mustBeGreaterThanOrEqual(CWMax,1), mustBeLessThanOrEqual(CWMax,1023)} = [1023 1023 15 7];

    %AIFSSlots Arbitrary interframe slot values for four ACs
    %   Arbitrary interframe space slots for Best Effort, Background,
    %   Video, and Voice traffic.
    AIFSSlots (1, 4) {mustBeInteger, mustBeGreaterThanOrEqual(AIFSSlots,2), mustBeLessThanOrEqual(AIFSSlots,15)} = [3 7 2 2];

    %FrameAbstraction Enable abstracted frame operations
    %   Specify this property as false to generate and decode MAC frame,
    %   otherwise set true. The default value is true.
    FrameAbstraction (1, 1) logical = true;
end

properties
    %PacketToApp Decoded application packet structure
    %   Output structure containing the received application packet details
    PacketToApp;

    %PHYMode PHY mode structure
    %   Output structure indicating the change in PHY mode when IsEmpty
    %   property is set to false
    PHYMode = struct('IsEmpty', true, ...
        'PHYRxOn', true, ...
        'EnableSROperation', 0, ...
        'BSSColor', 0, ...
        'OBSSPDThreshold', 0);
end

properties(Hidden)
    %MACState Current state of the MAC State machine (either 1 | 2 | 3 | 4 | 5 | 6)
    %   MACState represents the current state of EDCA MAC state machine.
    %   1 - IDLE_STATE
    %   2 - CONTENTION_STATE
    %   3 - SENDINGDATA_STATE
    %   4 - RECEIVING_STATE
    %   5 - WAITFORRX_STATE
    %   6 - EIFS_STATE
    MACState;

    %Tx hTxContext object
    %   Tx represents a MAC layer transmit parameters object to maintain
    %   context specific to transmit states (SENDINGDATA/WAITFORRX) for a
    %   node
    Tx;

    %Rx hRxContext object
    %   Rx represents a MAC layer receive parameters object to maintain
    %   context specific to receiving state for a node
    Rx;

    %EDCAQueues Queue management object
    %   EDCAQueues represents a WLAN MAC Queue management object.
    EDCAQueues;

    %Scheduler Round-robin scheduler object
    %   Scheduler is a Round-robin scheduler object for a multi-user
    %   network to schedule destination stations.
    Scheduler;

    %RxData RxData to store received frame
    %   RxData represents a buffer to store frames received from the
    %   physical layer
    RxData;

    %RateControl Rate control algorithm
    %   RateControl is a scalar object providing the interface for
    %   rateControl. This allows plugging in various rate control
    %   strategies such as - Fixed rate, ARF, Minstrel.
    RateControl;

    %PowerControl Power control algorithm
    %   PowerControl is a scalar object providing the interface for
    %   powerControl. This allows plugging in various power control
    %   strategies such as - Fixed power, MCS based power control, central
    %   carrier frequency based power control.
    PowerControl;

    %OperatingFreqID ID for the operating frequency
    %   OperatingFreqID indicates the sequential ID for the frequency in
    %   which the MAC layer is operating.
    OperatingFreqID = 1;

    %OperatingFrequency Frequency of operation
    %   OperatingFrequency indicates the frequency in which the MAC layer
    %   is operating.
    OperatingFrequency = 2.412;
end

properties(Hidden, Access = private)
    %MSDUTimestamps Entry timeStamps per each subframe in microseconds
    % MSDUTimestamps is an array of size M x N x O representing entry
    % Timestamps per each subframe where M is the maximum queue length,
    % N is the number of stations in network, and O is the maximum
    % number of ACs.
    MSDUTimestamps;

    %BackoffInvokeTime Wait time (in microseconds) to invoke the backoff
    %algorithm. It is initialized to SIFS time.
    BackoffInvokeTime = 0;

    %StateEntryTimestamp Entry timestamp of MAC state in microseconds
    StateEntryTimestamp = 0;

    %AggressiveChannelAccess Aggressive channel access
    % If this flag is true, in Idle state the transmission starts as soon
    % as data is queued. Otherwise, MAC first invokes backoff algorithm
    % instead of directly transmitting even when the channel is idle.
    AggressiveChannelAccess = false;
end

properties(Hidden, SetAccess = private, GetAccess = public)
    %MaxSubframes Maximum number of A-MPDU subframes
    %   MaxSubframes is a scalar representing maximum number of subframes
    %   in a single A-MPDU. The default value is 64.
    MaxSubframes = 64;

    %NumTxUsers Number of Tx users
    %   NumTxUsers is a scalar representing the number of Tx users.
    %   The default value is 1.
    NumTxUsers = 1;

    %DestinationStationID Node ID of receiving station
    DestinationStationID = 0;

    %ContendFromTx Flag to indicate contention state is triggered from Tx
    %states (SENDING_DATA or WAIT_FOR_RX)
    ContendFromTx = false;

    %CTSDuration CTS frame transmission duration
    CTSDuration;

    %ResponseTimeout Timeout for waiting on a response frame
    ResponseTimeout;
end

properties(Hidden)
    %CCAState PHY state
    %   CCAState represents is a logical value which represents PHY state.
    %   Set this property to true to indicate channel is busy.
    CCAState

    %SeqNumWaitingForAck Sequence numbers waiting for ack data units
    %   SeqNumWaitingForAck is an array of size M x N where M is the
    %   maximum number of subframes and N is the maximum number of ACs.
    %   Each element is a scalar indicating sequence number for data
    %   units waiting for acknowledgment.
    SeqNumWaitingForAck = zeros(64, 4);

    %CW Size of contention window(CW)
    %   CW is a vector of size 4 x 1 where each element represents size of
    %   contention window for corresponding AC.
    CW

    %NAV Network Allocation Vector(NAV)
    %   NAV is a scalar that indicates Network Allocation Vector value when
    %   spatial reuse is disabled.
    NAV

    %InterNAV NAV used for frames received from other BSS
    %   InterNAV is a scalar which represents NAV used for frames received
    %   from other BSS when spatial reuse is enabled.
    InterNAV

    %IntraNAV NAV used for frames received from same BSS
    %   IntraNAV is a scalar which represents NAV used for frames received
    %   from same BSS when spatial reuse is enabled.
    IntraNAV

    % Flag to indicate whether to limit Tx power during transmission
    LimitTxPower = false;

    % Available channel bandwidth
    AvailableBandwidth;

    % Structure to store response frame
    ResponseFrame;

    % Discard frame indication from rate control algorithm
    % RateControlDiscard = false;

    % Updated OBSS PD threshold
    UpdatedOBSSPDThreshold = -82;

    % Next event invoke time
    NextInvokeTime = 0;

    % AIFS slot counter for Contention state
    AIFSSlotCounter = zeros(1, 4);

    % Backoff counter
    BackoffCounter = zeros(1, 4);

    % Flag to indicate backoff is completed
    BackoffCompleted = false;

    % Owner access category
    OwnerAC = 0;

    % Block-ack bitmap length
    BABitmapLength

    % Current simulation time in microseconds
    CurrentTime = 0;
end

% Dependent properties
properties(Dependent, Hidden)
    %BroadcastDestinationID Broadcast Destination Identifier
    BroadcastDestinationID;

    %UnknownDestinationID Unknown Destination Identifier
    UnknownDestinationID;

    %BasicRatesIndexes Basic rates indexes
    BasicRatesIndexes;
end

% Constant Properties
properties(Constant, Hidden)
    %UserIndexSU User index for single user processing
    UserIndexSU = 1;

    %MPDUOverhead Overhead for A-MPDU frames
    MPDUOverhead = 30;

    %SlotTime Slot time duration in microseconds
    SlotTime = 9;

    %SIFSTime Short interframe spacing duration in microseconds
    SIFSTime = 16;

    %PIFSTime PCF interframe spacing duration = SIFS Time + Slot Time
    PIFSTime = 25;

    %BroadcastID Broadcast address
    BroadcastID = 65535;

    %AckOrCtsFrameLength Acknowledgment or CTS frame length
    %   Acknowledgment or CTS frame length (14 octets)
    AckOrCtsFrameLength = 14;

    %MPDUMaxLength Maximum MPDU length
    %   Maximum MPDU length that we can receive is:
    %   (MPDU header + FCS + Mesh control + Max MSDU length) = (30 + 6 + 2304)
    MPDUMaxLength = 2340;

    %PSDUMaxLength Maximum PSDU length
    %   Maximum PSDU length supported by 802.11ax
    PSDUMaxLength = 6500631;

    %PHYRxStartDelay PHY Rx start delay in microseconds
    PHYRxStartDelay = 20;

    %MaxMUStations Maximum number of users in a multi-user(MU) transmission
    %   In 20MHz OFDMA transmission, maximum possible users are 9.
    MaxMUStations = 9;

    %AC2TID Mapping from AC (values 0 to 3) to TID (values 0 to 7)
    %   Default TID value corresponding to each AC, where AC+1 is index
    AC2TID = [3 1 5 7];

    %TID2AC Mapping from TID (values 0 to 7) to AC (values 0 to 3)
    %   Access Category corresponding to each TID, where TID+1 is the index
    TID2AC = [0 1 1 0 2 2 3 3]; % AC 0=BE, 1=BK, 2=Video, 3=Voice
end

properties (Hidden)
    %EmptyMACFrame Structure for MAC frame (abstracted MAC)
    EmptyMACFrame;

    %EmptyPhyIndication Structure for indications between MAC and PHY
    EmptyPHYIndication;

    %EmptyFrame Structure for frame (MAC frame and metadata) passed between MAC and PHY
    EmptyFrame;

    %EmptyMACConfig A default object of type wlanMACFrameConfig
    EmptyMACConfig;

    %NonHTConfig An object of type wlanNonHTConfig
    NonHTConfig;

    %HTConfig An object of type wlanHTConfig
    HTConfig;

    %VHTConfig An object of type wlanVHTConfig
    VHTConfig;

    %HESUConfig An object of type wlanHESUConfig
    HESUConfig;

    %EventDataObj An object of type <a href="matlab:help('hWLANEventData')">hWLANEventData</a>.
    EventDataObj;
end

properties(Constant, Hidden)
    % MAC States
    IDLE_STATE = 1;
    CONTENTION_STATE = 2;
    SENDINGDATA_STATE = 3;
    RECEIVING_STATE = 4;
    WAITFORRX_STATE = 5;
    EIFS_STATE = 6;
end

% MAC statistics
properties (Description = 'Metrics')
    % Average queuing delay in MAC
    MACAverageTimePerFrame = 0;
end

% MAC statistics
properties (GetAccess = public, SetAccess = private, Description = 'Metrics')
    % Array of MAC per AC internal collisions count. Elements in index 1
    % contains AC0 count, index 2 contains AC1 count, index 3 contains AC2
    % count, and index 4 contains AC3 count
    MACInternalCollisionsAC = zeros(1, 4);

    % MAC random backoff slots count. Elements in index 1 contains AC0
    % count, index 2 contains AC1 count, index 3 contains AC2 count, and
    % index 4 contains AC3 count
    MACBackoffAC = zeros(1, 4);

    % MAC data frames transmitted
    MACDataTx = 0;

    % Array of MAC per AC data frames transmitted count. Elements in index
    % 1 contains AC0 count, index 2 contains AC1 count, index 3 contains
    % AC2 count, and index 4 contains AC3 count
    MACDataTxAC = zeros(1, 4);

    % Array of MAC per AC aggregated frames transmitted count. Elements in
    % index 1 contains AC0 count, index 2 contains AC1 count, index 3
    % contains AC2 count, and index 4 contains AC3 count
    MACAggTxAC = zeros(1, 4);

    % MAC data frames retransmission
    MACRetries = 0;

    % Array of MAC per AC frame retries count. Elements in index 1 contains
    % AC0 count, index 2 contains AC1 count, index 3 contains AC2 count,
    % and index 4 contains AC3 count
    MACTxRetriesAC = zeros(1, 4);

    % MAC acknowledgment frames transmitted
    MACAckTx = 0;

    % MAC block acknowledgment frames transmitted
    MACBATx = 0;

    % MAC RTS frames transmitted
    MACRTSTx = 0;

    % MAC CTS frames transmitted
    MACCTSTx = 0;

    % MAC data bytes (excluding MAC header) transmitted
    MACDataTxBytes = 0;

    % MAC data bytes transmitted per AC
    MACDataTxBytesAC = zeros(1, 4);

    % MAC control bytes transmitted
    MACControlTxBytes = 0;

    % MAC transmission queue overflows
    MACTxQueueOverflow = 0;

    % MAC transmission failures
    MACTxFails = 0;

    % MAC frames received
    MACRx = 0;

    % MAC data bytes (excluding MAC header) received
    MACDataRxBytes = 0;

    % MAC bytes received
    MACControlRxBytes = 0;

    % Array of MAC per AC frames received count. Elements in index 1
    % contains AC0 count, index 2 contains AC1 count, index 3 contains AC2
    % count, and index 4 contains AC3 count
    MACDataRxAC = zeros(1, 4);

    % Array of MAC per AC aggregated frames received count. Elements in
    % index 1 contains AC0 count, index 2 contains AC1 count, index 3
    % contains AC2 count, and index 4 contains AC3 count
    MACAggRxAC = zeros(1, 4);

    % MAC aggregated frames received
    MACAggRx = 0;

    % MAC aggregated duplicate frames received
    MACDuplicateAMPDURx = 0;

    % MAC non-HT frames received
    MACNonHTRx = 0;

    % MAC HT frames received
    MACHTRx = 0;

    % MAC VHT frames received
    MACVHTRx = 0;

    % MAC HE-SU frames received
    MACHESURx = 0;

    % MAC HE-Extended-SU frames received
    MACHEEXTSURx = 0;

    % MAC Rx drop
    MACRxDrop = 0;

    % MAC CRC failures
    MACCRCFailures = 0;

    % MAC data frames received
    MACDataRx = 0;

    % MAC acknowledgment frames received
    MACAckRx = 0;

    % MAC RTS frames received
    MACRTSRx = 0;

    % MAC CTS frames received
    MACCTSRx = 0;

    % MAC block acknowledgment frames received
    MACBARx = 0;

    % MAC error responses
    MACRespErrors = 0;

    % MAC other than response frames while waiting for response
    MACNonRespFrames = 0;

    % MAC others frames while waiting for response
    MACOthersFramesInWaitForResp = 0;

    % Time spent in ideal state (microseconds)
    IdleStateTime = 0;

    % Time spent in contend state (microseconds)
    ContendStateTime = 0;

    % Time spent in sending data state (microseconds)
    SendingDataStateTime = 0;

    % Time spent in wait for Rx state (microseconds)
    WaitForRxStateTime = 0;

    % Time spent in EIFS state (microseconds)
    EIFSStateTime = 0;

    % Time spent in Rx state (microseconds)
    RxStateTime = 0;

    % MAC layer throughput of the node
    MACThroughput = 0;

    % Packet loss ratio of the node
    PacketLossRatio = 0;

    % MAC layer throughput of the node per AC
    MACThroughputAC = zeros(1, 4);

    % Number of acknowledged MPDUs/A-MPDU subframes
    MACTxSuccess = 0;

    % Queue length per AC. Elements in index 1 contains AC0 count, index 2
    % contains AC1 count, index 3 contains AC2 count, and index 4 contains
    % AC3 count. The count in each column corresponds to the sum of frames
    % in all per destination queues for AC.
    MACMaxQueueLengthAC = zeros(1, 4);

    % Number of per AC application packets discarded due to buffer overflow
    % in MAC layer. Elements in index 1 contains AC0 count, index 2
    % contains AC1 count, index 3 contains AC2 count, and index 4 contains
    % AC3 count.
    MACQueueoverflowAC = zeros(1, 4);

    % Number of application packets discarded due to buffer overflow in MAC
    % layer, per destination and per AC. Size of this property is N-by-4
    % where N is the number of nodes and 4 corresponds to number of ACs.
    MACQueueOverflowPerDestPerAC;

    % Number of duplicate MPDUs received. Elements in index 1 contains
    % AC0 count, index 2 contains AC1 count, index 3 contains AC2 count,
    % and index 4 contains AC3 count.
    MACDuplicateRxAC = zeros(1, 4);

    % Number of successful RTS transmissions
    MACRTSSuccess = 0;

    % Timestamp at which recent frame transmission status is known
    MACRecentFrameStatusTimestamp = 0;

    % Number of HE-MU frames received at MAC layer
    MACHEMURx = 0;

    % Number of intra NAV updates
    MACNumIntraNavUpdates = 0;

    % Number of inter or basic NAV updates when spatial reuse (SR)
    % operation is enabled or Number of NAV updates when there is no SR
    % operation
    MACNumBasicNavUpdates = 0;
end

% MAC events
events
    % TxEvent is triggered when a frame is sent from MAC to PHY. Along with
    % the event notification, a structure with the following fields is
    % passed to the registered callback:
    %   NodeID      - Integer representing unique identifier(ID) for the
    %                 node in the network
    %   TxFrameType - Indicates the frame type as one of 'Data',
    %                 'Control', or 'Management' 
    %   TxFrame     - Structure containing frame sent to PHY
    %   TxMCS       - Scalar representing MCS to be used for transmission of frame
    %   TxTime      - Scalar representing frame transmission time
    % This structure can be extended to include any other required fields.
    TxEvent

    % RxEvent is triggered when a MAC frame is received. Along with
    % the event notification, a structure with the following fields is
    % passed to the registered callback:
    %   NodeID   - Integer representing unique identifier(ID) for the
    %              node in the network
    %   RxFrame  - Received MAC frame
    %                In case of abstracted MAC frames, it is a structure
    %                containing MAC frame information
    %                In case of full MAC frames, it contains MPDU bytes
    %                in decimal format
    %   RxVector - Structure containing parameters provided by PHY upon receipt of
    %              a valid PHY header
    % This structure can be extended to include any other required fields.
    RxEvent

    % TxStatusEvent is triggered to notify about the transmission status of
    % a frame('RTS' and Data). Along with the event notification, a
    % structure with following fields is passed to the registered callback:
    %   NodeID        - Integer representing unique identifier(ID) for the
    %                   node in the network
    %   FrameType     - Indicates the frame type as one of 'Data', 'Control'
    %                   or 'Management'
    %   IsSuccess     - Logical scalar or vector representing transmission
    %                   status of each subframe
    %                     'true'  - Transmission success
    %                     'false' - Transmission failure
    %   NumTxAttempts - Scalar representing number of transmission attempts
    %   MCS           - Scalar representing MCS used for transmission of frame
    % This structure can be extended to include any other required fields.
    TxStatusEvent

    % TxEnqueueEvent is triggered when there is an entry of a data packet
    % into MAC queue from application layer. Along with the event
    % notification, a structure with following fields is passed to the
    % registered callback:
    %   NodeID             - Integer representing unique identifier(ID) for the
    %                        node in the network
    %   AccessCategory     - Scalar representing access category(AC) of the enqueued packet
    %   MSDULength         - Scalar representing length of the enqueued packet
    %   SourceAddress      - 12-element character vector or string scalar
    %                        representing MAC address of the packet source
    %   DestinationAddress - 12-element character vector or string scalar
    %                        representing MAC address of the packet destination
    %   Timestamp          - Scalar representing packet generation timestamp
    % This structure can be extended to include any other required fields.
    TxEnqueueEvent

    % TxDiscardEvent is triggered when data packets are discarded from MAC
    % queue. Along with the event notification, a structure with following
    % fields is passed to the registered callback:
    %   NodeID             - Integer representing unique identifier(ID) for the
    %                        node in the network
    %   AccessCategory     - Scalar representing access category of discarded packets
    %   MCS                - Scalar representing MCS used for transmission of packets
    %   MSDULengths        - Scalar or vector representing lengths of discarded packets
    %   SourceAddress      - Array representing MAC address of source of discarded packets
    %   DestinationAddress - Array representing MAC address of destination of discarded packets
    %   TimeInQueue        - Scalar or vector containing time spent by packets
    %                        in MAC queue until discard
    %   TxSuccess          - Scalar or vector containing transmission status
    %                        of discarded packets
    %                          'true'  - Discard after successful transmission
    %                          'false' - Discard after maximum retry limit
    %   NumRetries         - Scalar representing number of retransmission attempts
    %                        made by packets before discard
    % This structure can be extended to include any other required fields.
    TxDiscardEvent
end

% Public methods
methods
    % Constructor
    function obj = hEDCAMAC(NumNodes, MaxQueueLength, MaxSubframes, varargin)
        % Initial MAC state
        obj.MACState = obj.IDLE_STATE;

        % Create a scheduler object with queues for 'NumNodes', broadcast
        % and special case
        obj.Scheduler = hSchedulerRoundRobin(NumNodes+2);

        % Create object for rate control
        obj.RateControl = hRateControlFixed(NumNodes);

        % Create object for power control
        obj.PowerControl = hPowerControlFixed;

        % Statistic size allocation
        obj.MACQueueOverflowPerDestPerAC = zeros(NumNodes, 4);

        % Initialize remaining properties to default values
        obj.NumNodes = NumNodes;
        obj.CCAState = hPHYPrimitives.CCAIdleIndication;
        obj.NAV = 0;
        obj.InterNAV = 0;
        obj.IntraNAV = 0;

        % Name-value pairs
        for idx = 1:2:numel(varargin)
            obj.(varargin{idx}) = varargin{idx+1};
        end

        obj.MaxSubframes = MaxSubframes;
        if obj.MaxSubframes <= 64
            obj.BABitmapLength = 64;
        else
            obj.BABitmapLength = 256;
        end

        % Create transmit and receive parameters configuration
        % objects.
        obj.Tx = hTxContext(NumNodes, obj.MaxSubframes, MaxQueueLength);
        obj.Rx = hRxContext(NumNodes, obj.BABitmapLength);

        % Create a WLAN MAC Queue management object
        obj.EDCAQueues = hMACQueueManagement(NumNodes + 2, MaxQueueLength, obj.MaxSubframes);
        obj.MSDUTimestamps = zeros(obj.MaxSubframes, NumNodes+2, 4);
        obj.SeqNumWaitingForAck = zeros(obj.MaxSubframes, 4);

        obj.PacketToApp = struct('IsEmpty', true, ...
            'MSDUCount', 0, ...
            'MSDULength', zeros(obj.MaxSubframes, 1), ...
            'AC', 0, ...
            'DestinationID', 0, ...
            'DestinationMACAddress', '000000000000', ...
            'FourAddressFrame', false(obj.MaxSubframes, 1), ...
            'MeshSourceAddress', repmat('000000000000', obj.MaxSubframes, 1), ...
            'MeshDestinationAddress', repmat('000000000000', obj.MaxSubframes, 1), ...
            'MeshSequenceNumber', zeros(obj.MaxSubframes, 1), ...
            'Timestamp', zeros(obj.MaxSubframes, 1), ...
            'Data', zeros(obj.MaxSubframes, 2304, 'uint8'));

        obj.EmptyMACFrame = struct('IsEmpty', true, ...
            'FrameType', 'Beacon', ...
            'FrameFormat', 'Non-HT', ...
            'Duration', 0, ...
            'Retransmission', false(obj.MaxSubframes, obj.MaxMUStations), ...
            'FourAddressFrame', false(obj.MaxSubframes, obj.MaxMUStations), ...
            'Address1', '000000000000', ...
            'Address2', '000000000000', ...
            'Address3', repmat('0', obj.MaxSubframes, 12, obj.MaxMUStations), ...
            'Address4', repmat('0', obj.MaxSubframes, 12, obj.MaxMUStations), ...
            'MeshSequenceNumber', zeros(obj.MaxSubframes, obj.MaxMUStations), ...
            'AckPolicy', 'No Ack', ...
            'SequenceNumber', zeros(obj.MaxSubframes, obj.MaxMUStations), ...
            'TID', 0, ...
            'BABitmap', '0000000000000000', ...
            'MPDUAggregation', false, ...
            'PayloadLength', zeros(obj.MaxSubframes, obj.MaxMUStations), ...
            'MPDULength', zeros(obj.MaxSubframes, obj.MaxMUStations), ...
            'PSDULength', zeros(obj.MaxMUStations, 1), ...
            'FCSPass', false(obj.MaxSubframes, obj.MaxMUStations), ...
            'DelimiterFails', false(obj.MaxSubframes, obj.MaxMUStations));

        obj.EmptyPHYIndication = struct('IsEmpty', true, ...
            'MessageType', 0, ...
            'FrameFormat', hFrameFormats.NonHT, ...
            'MCSIndex', zeros(obj.MaxMUStations, 1), ...
            'PSDULength', zeros(obj.MaxMUStations, 1), ...
            'ChannelBandwidth', 20, ...
            'AggregatedMPDU', false, ...
            'NumTransmitAntennas', 0, ...
            'NumSpaceTimeStreams', 0, ...
            'AllocationIndex', 0, ...
            'StationIDs', zeros(obj.MaxMUStations,1), ...
            'RSSI', 0, ...
            'EnableSROperation', false, ...
            'BSSColor', 0, ...
            'OBSSPDThreshold', -82, ...
            'LimitTxPower', false, ...
            'TxPower', zeros(obj.MaxMUStations, 1));

        obj.EmptyFrame = struct('IsEmpty', true, ...
            'MACFrame', obj.EmptyMACFrame, ...
            'Data', [], ...
            'PSDULength', 0, ...
            'Timestamp', zeros(obj.MaxSubframes, obj.MaxMUStations), ...
            'SubframeBoundaries', zeros(obj.MaxSubframes, 2), ...
            'NumSubframes', 0, ...
            'SequenceNumbers', zeros(obj.MaxSubframes, obj.MaxMUStations));

        obj.EmptyMACConfig = obj.EmptyPHYIndication;

        % Initialize MAC parameters
        initMACParameters(obj);

        obj.NonHTConfig = wlanNonHTConfig;
        obj.HTConfig = wlanHTConfig;
        obj.VHTConfig = wlanVHTConfig;
        obj.HESUConfig = wlanHESUConfig;

        obj.EventDataObj = hWLANEventData;

        % Default structure for received frame and response frame
        obj.RxData = obj.EmptyFrame;
        obj.ResponseFrame = obj.EmptyFrame;
    end

    function initMACParameters(obj)
        %initMACParameters Initialize MAC layer parameters

        % CTS frame length (14 octets)
        ctsFrameLength = 14;

        cbw = 20; % Bandwidth for CTS transmission
        numSTS = 1; % Number of space time streams

        % CTS frame duration with basic rate
        obj.CTSDuration = calculateTxTime(obj, cbw, obj.Tx.BasicRate, ctsFrameLength, hFrameFormats.NonHT, numSTS);

        % Response timeout. Refer section 10.3.2.9 in IEEE Std 802.11-2016
        obj.ResponseTimeout = obj.SIFSTime + obj.SlotTime + obj.PHYRxStartDelay;

        % Initialize CW value to CWmin
        obj.CW = obj.CWMin;

        % Available channel bandwidth
        obj.AvailableBandwidth = obj.Bandwidth;

        if ~obj.FrameAbstraction
            % MAC configuration for full MAC
            obj.EmptyMACConfig = wlanMACFrameConfig;
        end
        init(obj.RateControl);
    end

    function [nextInvokeTime, macReqToPHY, frameToPHY] = run(obj, phyIndication, elapsedTime)
        %run Runs MAC Layer state machine
        %
        %   This function implements the following:
        %   1. EDCA (Enhanced Distribution Channel Access)
        %   2. Generation and parsing of MPDU's and A-MPDU's
        %   3. Transmission of PSDU's in NonHT/HT/HE/VHT based on
        %   configuration
        %
        %   [NEXTINVOKETIME, MACREQTOPHY, FRAMETOPHY] = run(OBJ,
        %   PHYINDICATION, ELAPSEDTIME) performs MAC Layer data actions.
        %
        %   NEXTINVOKETIME returns the time (in microseconds) after which
        %   the run function must be invoked again.
        %
        %   MACREQTOPHY returns Tx request to PHY Layer.
        %
        %   FRAMETOPHY returns data frame to PHY Layer.
        %
        %   PHYINDICATION is indication from PHY Layer.
        %
        %   ELAPSEDTIME is the time elapsed in microseconds between the
        %   previous and current call of this function.

        % Initialize
        macReqToPHY = obj.EmptyPHYIndication;
        frameToPHY = obj.EmptyFrame;
        obj.PHYMode.IsEmpty = true;
        obj.PacketToApp.IsEmpty = true;

        % Handle the events as per the current state
        switch obj.MACState
            case obj.IDLE_STATE
                nextInvokeTime = handleEventsIDLE(obj, phyIndication, elapsedTime);

            case obj.CONTENTION_STATE
                nextInvokeTime = handleEventsContention(obj, phyIndication, elapsedTime);

            case obj.SENDINGDATA_STATE
                [macReqToPHY, frameToPHY, nextInvokeTime] = handleEventsSendingData(obj, phyIndication, elapsedTime);

            case obj.WAITFORRX_STATE
                nextInvokeTime = handleEventsWaitForRx(obj, phyIndication, elapsedTime);

            case obj.RECEIVING_STATE
                [macReqToPHY, frameToPHY, nextInvokeTime] = handleEventsReceiving(obj, phyIndication, elapsedTime);

            otherwise % obj.EIFS_STATE
                nextInvokeTime = handleEventsEIFS(obj, phyIndication, elapsedTime);
        end
    end

    function runScheduler(obj, maxStationCount)
        %runScheduler Schedules destination stations
        %   runScheduler(OBJ, MAXSTATIONCOUNT) schedules destination
        %   stations and calculates number of MSDUs that can be aggregated
        %   per each user. MAXSTATIONCOUNT represents the maximum number of
        %   stations that can be scheduled.

        queueLengths = obj.EDCAQueues.TxQueueLengths;
        retryQueueLengths = obj.EDCAQueues.RetryQueueLengths;

        % Run scheduler
        scheduleInfo = obj.Scheduler.runScheduler(obj.OwnerAC + 1, maxStationCount,...
            queueLengths, retryQueueLengths);

        % Scheduled stations and corresponding ACs
        obj.Tx.TxStationIDs = scheduleInfo.DstStationIDs;
        obj.Tx.TxACs = scheduleInfo.ACs;
        obj.Tx.AllocationIndex = scheduleInfo.AllocationIndex;

        % Calculate max possible number of subframes that can be used to form PSDU
        % (MPDU/A-MPDU)
        if obj.TxFormat == hFrameFormats.HE_MU % Multi-user format

            % Create MU PHY configuration object
            cfgHEMU = wlanHEMUConfig(obj.Tx.AllocationIndex);
            obj.NumTxUsers = numel(cfgHEMU.User);
            fourAddressFrame = zeros(1, obj.NumTxUsers);

            % Set data rate for each user
            for userIdx = 1:obj.NumTxUsers
                % Get the data rate for from the rate control algorithm
                rateControlInfo = obj.RateControl.TxInfo;
                rateControlInfo.FrameType = 'Data';
                rateControlInfo.IsUnicast = (obj.Tx.TxStationIDs(userIdx) ~= obj.BroadcastID);
                % Method invocation using dot notation is done for MATLAB
                % compiler support
                rate = obj.RateControl.getRate(obj.Tx.TxStationIDs(userIdx), rateControlInfo);
                cfgHEMU.User{userIdx}.MCS = rate;
                obj.Tx.TxMCS(userIdx) = rate;
                fourAddressFrame(userIdx) = isFourAddressFrame(obj.EDCAQueues, obj.Tx.TxStationIDs(userIdx), obj.Tx.TxACs(userIdx));
            end

            % Get number of MSDUs that can be aggregated per each user
            obj.Tx.TxMSDUCount(1:obj.NumTxUsers) = hCalculateSubframesCount(obj.Tx.TxMSDULengths(obj.Tx.TxStationIDs(1:obj.NumTxUsers), :, :),...
                queueLengths(obj.Tx.TxStationIDs(1:obj.NumTxUsers), :), obj.Tx.TxACs, obj.OwnerAC+1, obj.MaxSubframes, cfgHEMU, fourAddressFrame);

            if any(obj.Tx.TxMSDUCount(1:obj.NumTxUsers) == 0)
                error(['OFDMA transmission time exceeded 5484 microseconds with given application packet size and MCS ' int2str(obj.Tx.TxMCS) ...
                    '. Use higher MCS value to transmit given MSDU using OFDMA within 5484 microseconds.']);
            end

            % Retransmit only failed subframes
            for userIdx = 1:obj.NumTxUsers
                if retryQueueLengths(obj.Tx.TxStationIDs(userIdx), obj.Tx.TxACs(userIdx))
                    obj.Tx.TxMSDUCount(userIdx) = retryQueueLengths(obj.Tx.TxStationIDs(userIdx), obj.Tx.TxACs(userIdx));
                end
            end

        else % Single user format
            % Store destination ID
            obj.DestinationStationID = obj.Tx.TxStationIDs(obj.UserIndexSU);

            % Get the data rate for from the rate control algorithm
            rateControlInfo = obj.RateControl.TxInfo;
            rateControlInfo.FrameType = 'Data';
            rateControlInfo.IsUnicast = (obj.Tx.TxStationIDs(obj.UserIndexSU) ~= obj.BroadcastID);

            if obj.DestinationStationID == obj.BroadcastDestinationID
                % Transmit broadcast frames with maximum basic rate
                obj.Tx.TxMCS(obj.UserIndexSU) = max(obj.BasicRatesIndexes);
            else
                % Method invocation using dot notation is done for MATLAB
                % compiler support
                rate = obj.RateControl.getRate(obj.DestinationStationID, rateControlInfo);
                obj.Tx.TxMCS(obj.UserIndexSU) = rate;
            end

            if retryQueueLengths(obj.Tx.TxStationIDs(1), obj.Tx.TxACs(1))
                % Retransmit only failed frames
                queueLength = retryQueueLengths(obj.Tx.TxStationIDs(obj.UserIndexSU), obj.Tx.TxACs(obj.UserIndexSU));
            else
                queueLength = queueLengths(obj.Tx.TxStationIDs(obj.UserIndexSU), obj.Tx.TxACs(obj.UserIndexSU));
            end

            % Initialize
            obj.Tx.TxMSDUCount(obj.UserIndexSU) = 0;
            psduLength = 0;
            mpduOverhead = obj.MPDUOverhead;
            fourAddressFrame = isFourAddressFrame(obj.EDCAQueues, obj.Tx.TxStationIDs(obj.UserIndexSU), obj.Tx.TxACs(obj.UserIndexSU));
            if fourAddressFrame
                mpduOverhead = mpduOverhead + 6;
            end

            % Get Max PSDU length that can be transmitted with maximum allowed
            % transmission time (5484 microseconds)
            maxPSDULen = getMaxPSDULength(obj);

            for msduIdx = 1:queueLength
                % MSDU length
                msduLen = obj.Tx.TxMSDULengths(obj.Tx.TxStationIDs(obj.UserIndexSU), obj.Tx.TxACs(obj.UserIndexSU), msduIdx);

                % Calculate PSDU length
                psduLength = psduLength + (mpduOverhead + msduLen);

                % Aggregated MPDU
                if obj.MPDUAggregation
                    % Delimiter overhead for aggregated frames (4 Octets)
                    psduLength = psduLength + 4;

                    % Subframe padding overhead for aggregated frames
                    subFramePadding = abs(mod(msduLen+mpduOverhead, -4));
                    psduLength = psduLength + subFramePadding;
                end

                if (obj.Tx.TxMSDUCount(obj.UserIndexSU) < obj.MaxSubframes) && (psduLength <= maxPSDULen)
                    obj.Tx.TxMSDUCount(obj.UserIndexSU) = obj.Tx.TxMSDUCount(obj.UserIndexSU) + 1;
                else  % Max PSDU length is reached
                    break;
                end

                % Only one MSDU is sufficient if no MPDU aggregation
                if ~obj.MPDUAggregation
                    break;
                end
            end
        end
    end

    function isSuccess = edcaQueueManagement(obj, opType, varargin)
        %edcaQueueManagement Maintain queues per station and per AC
        %
        %   This function performs the following operations
        %   1. Inserts the packet into queue
        %   2. Dequeues the frames from MAC queue for transmission
        %   3. Discard packets from transmission and retry queues
        %
        %   edcaQueueManagement(OBJ, OPTYPE) performs 'dequeue' / 'discard'
        %   operation
        %
        %   OPTYPE determines the type of operation to be performed
        %
        %   edcaQueueManagement(OBJ, 'enqueue', APPPACKET) enqueues the
        %   application packet into the transmission queue

        % Initialize the output variable
        isSuccess = true;

        switch(opType)
            % Enqueue event
            case 'enqueue'
                appPacket = varargin{1};
                % Get access category of the packet
                ac = appPacket.AC;

                % Capture packet entry time stamp
                timestamp = getCurrentTime(obj);

                if (appPacket.DestinationID == obj.BroadcastID)
                    % Broadcast destination
                    destinationID = obj.BroadcastDestinationID;
                elseif (appPacket.DestinationID == 0)
                    % Unknown destination
                    destinationID = obj.UnknownDestinationID;
                else
                    destinationID = appPacket.NextHopID;
                end

                % Enqueue packet
                isSuccess = enqueue(obj.EDCAQueues, destinationID, ac+1, appPacket);

                % Update MSDU lengths
                obj.Tx.TxMSDULengths = obj.EDCAQueues.MSDULengths;

                if isSuccess

                    % Create a structure with necessary data to pass while
                    % triggering the event.
                    notificationData = struct('NodeID', obj.NodeID, 'AccessCategory', appPacket.AC, ...
                        'MSDULength', appPacket.MSDULength, ...
                        'SourceAddress', appPacket.SourceAddress, ...
                        'DestinationAddress', appPacket.DestinationAddress, ...
                        'Timestamp', appPacket.Timestamp);
                    obj.EventDataObj.Data = notificationData;

                    % Notify about packet entry into MAC queue
                    notify(obj, 'TxEnqueueEvent', obj.EventDataObj);

                    % Update statistics
                    if obj.MACMaxQueueLengthAC(ac + 1) < sum(obj.EDCAQueues.TxQueueLengths(:, ac + 1))
                        obj.MACMaxQueueLengthAC(ac + 1) = sum(obj.EDCAQueues.TxQueueLengths(:, ac + 1));
                    end

                else % Queue overflow
                    % Update MAC queue overflow statistics
                    obj.MACQueueoverflowAC(ac + 1) = obj.MACQueueoverflowAC(ac + 1) + 1;
                    if appPacket.DestinationID ~= obj.BroadcastID
                        obj.MACQueueOverflowPerDestPerAC(appPacket.DestinationID, ac + 1) = obj.MACQueueOverflowPerDestPerAC(appPacket.DestinationID, ac + 1) + 1;
                    end
                    obj.MACTxQueueOverflow = obj.MACTxQueueOverflow + 1;
                end

                % Plot the queue status
                hPlotQueueLengths(false, {}, obj.NodeID, sum(obj.EDCAQueues.TxQueueLengths), timestamp);

                % Dequeue event
            case 'dequeue'
                % Dequeue the frames from MAC queue for transmission
                obj.Tx.TxFrame = dequeue(obj.EDCAQueues, obj.Tx.TxStationIDs, ...
                    obj.Tx.TxACs, obj.Tx.TxMSDUCount, obj.NumTxUsers);

                % Initial transmission. i.e retry flag set to false
                for userIdx = 1:obj.NumTxUsers
                    if ~obj.EDCAQueues.RetryFlags(obj.Tx.TxStationIDs(userIdx), obj.Tx.TxACs(userIdx))
                        % Store the number of subframes in transmission of PSDU
                        obj.Tx.InitialSubframesCount(obj.Tx.TxStationIDs(userIdx), obj.Tx.TxACs(userIdx)) = ...
                            obj.Tx.TxMSDUCount(userIdx);
                    end
                    % Store the entry timestamps for each subframe
                    obj.MSDUTimestamps(:, userIdx, obj.OwnerAC+1) = obj.Tx.TxFrame(userIdx).Timestamp;
                end

            case 'discard'
                % Remove packets from MAC queue
                discardIndices = discardPackets(obj.EDCAQueues, ...
                    obj.Tx.TxStationIDs, obj.Tx.TxACs, obj.Tx.MSDUDiscardIndices,...
                    obj.Tx.MSDUDiscardCount, obj.NumTxUsers);
                % Update MSDU lengths
                obj.Tx.TxMSDULengths = obj.EDCAQueues.MSDULengths;
                currentTimestamp = getCurrentTime(obj);
                for userIndex = 1:obj.NumTxUsers
                    % Log MSDU entry and discard timestamps
                    for idx = 1: nnz(discardIndices(:, obj.Tx.TxStationIDs(userIndex)))
                        hLogLatencies(obj.NodeID, obj.Tx.TxACs(userIndex)-1, ...
                            obj.MSDUTimestamps(discardIndices(idx, obj.Tx.TxStationIDs(userIndex)), userIndex, obj.Tx.TxACs(userIndex)), ...
                            currentTimestamp);
                    end
                end

            case 'isQueueFull'
                appPacket = varargin{1};
                % Check if MAC buffers are full
                if obj.EDCAQueues.TxQueueLengths(...
                        appPacket.DestinationID, appPacket.PriorityID+1) ~= obj.EDCAQueues.MaxQueueLength
                    isSuccess = false;
                end
        end
    end

    function discardTxPackets(obj, isSuccess, numRetries)
        %discardTxPackets Discard MSDUs from MAC queue
        %
        %   discardTxPacket(OBJ, ISSUCCESS, NUMRETRIES) discards MSDUs from
        %   MAC queue.
        %
        %   OBJ is an object of type hEDCAMAC.
        %
        %   ISSUCCESS is a logical scalar or a vector. Each element
        %   indicates whether the packet is discarded due to transmission
        %   success(true) or maximum retransmission limit reached(false).
        %
        %   NUMRETRIES is a scalar representing number of retransmission
        %   attempts before packet is discarded.

        tx = obj.Tx;
        % Number of MSDUs should be discarded from each user
        for userIdx = 1:obj.NumTxUsers
            tx.MSDUDiscardCount(userIdx) = tx.InitialSubframesCount(tx.TxStationIDs(userIdx), tx.TxACs(userIdx));
        end
        tx.MSDUDiscardIndices = repmat((1:obj.MaxSubframes)', 1, obj.MaxMUStations);

        frame = tx.TxFrame(obj.UserIndexSU);
        stationID = tx.TxStationIDs(obj.UserIndexSU);
        acIndex = obj.OwnerAC+1;
        msduIndices = 1:tx.InitialSubframesCount(stationID, acIndex);
        
        % Create a structure with necessary data to pass while
        % triggering the event.
        notificationData = struct('NodeID', obj.NodeID, 'AccessCategory', tx.TxACs(obj.UserIndexSU) - 1, ...
            'MCS', tx.TxMCS(obj.UserIndexSU), ...
            'MSDULengths', frame.MSDULength(msduIndices), ...
            'SourceAddress', frame.MeshSourceAddress(msduIndices, :), ...
            'DestinationAddress', frame.MeshDestinationAddress(msduIndices, :), ...
            'TimeInQueue', getCurrentTime(obj) - frame.Timestamp(msduIndices), ...
            'TxSuccess', isSuccess, ...
            'NumRetries', numRetries);
        obj.EventDataObj.Data = notificationData;

        % Notify about packet removal from MAC queue
        notify(obj, 'TxDiscardEvent', obj.EventDataObj);

        % Remove last transmitted frame from MAC queue
        edcaQueueManagement(obj, 'discard');
    end
end

methods(Hidden)
    function stateChange(obj, newState)
        oldState = obj.MACState;

        stateExit(obj, obj.MACState);
        stateEntry(obj, newState);
        obj.MACState = newState;

        % Set the flag if the MAC state is moving from receiving
        % state to contention state
        if any(oldState == [obj.SENDINGDATA_STATE, obj.WAITFORRX_STATE]) && (newState == obj.CONTENTION_STATE)
            obj.ContendFromTx = true;
        end
    end

    function stateEntry(obj, macState)
        switch macState
            case obj.IDLE_STATE
                % Capture entry timestamp
                obj.StateEntryTimestamp = getCurrentTime(obj);

            case obj.CONTENTION_STATE
                % Capture entry timestamp
                obj.StateEntryTimestamp = getCurrentTime(obj);
                % Initialize AIFS counters
                obj.AIFSSlotCounter = obj.AIFSSlots*obj.SlotTime;
                obj.BackoffCompleted = [false false false false];
                obj.BackoffInvokeTime = obj.SIFSTime;
                obj.NextInvokeTime = min(obj.AIFSSlots)*obj.SlotTime;

            case obj.SENDINGDATA_STATE
                % Capture entry timestamp
                obj.StateEntryTimestamp = getCurrentTime(obj);
                % Stop PHY Receiver
                obj.PHYMode.IsEmpty = false;
                obj.PHYMode.PHYRxOn = false;
                % If MAC state is moved to SendingData after an RTS/CTS
                % exchange, move directly to TRANSMITDATA_STATE substate
                % after waiting for SIFS time
                if obj.Tx.RTSSent
                    obj.NextInvokeTime = obj.SIFSTime;
                    obj.Tx.TxState = obj.Tx.TRANSMITDATA_STATE;
                end

            case obj.RECEIVING_STATE
                % Capture entry timestamp
                obj.StateEntryTimestamp = getCurrentTime(obj);

            case obj.WAITFORRX_STATE
                % Capture entry timestamp
                obj.StateEntryTimestamp = getCurrentTime(obj);
                % Reset flag
                obj.Rx.IgnoreResponseTimeout = false;
                % Set response timeout
                obj.Rx.WaitForResponseTimer = obj.ResponseTimeout;

            otherwise % EIFS_STATE
                % Capture entry timestamp
                obj.StateEntryTimestamp = getCurrentTime(obj);
                ackFrameLength = 14;
                mcs = 0;
                cbw = 20;
                numSTS = 1;
                ackDuration = calculateTxTime(obj, cbw, mcs, ackFrameLength, hFrameFormats.NonHT, numSTS);
                % Set EIFS recovery timeout
                obj.NextInvokeTime = obj.SIFSTime + ackDuration;
        end
    end

    function stateExit(obj, macState)
        switch macState
            case obj.IDLE_STATE
                obj.IdleStateTime = obj.IdleStateTime + (getCurrentTime(obj) - obj.StateEntryTimestamp);

            case obj.CONTENTION_STATE
                % Reset flag
                obj.ContendFromTx = false;
                % Update statistics
                obj.ContendStateTime = obj.ContendStateTime + (getCurrentTime(obj) - obj.StateEntryTimestamp);
                hPlotStateTransition([obj.NodeID obj.OperatingFreqID], 1, obj.StateEntryTimestamp, ...
                    getCurrentTime(obj) - obj.StateEntryTimestamp, obj.NumNodes)

            case obj.SENDINGDATA_STATE
                % Start PHY Receiver
                obj.PHYMode.IsEmpty = false;
                obj.PHYMode.PHYRxOn = true;
                % Update Statistics
                obj.SendingDataStateTime = obj.SendingDataStateTime + (getCurrentTime(obj) - obj.StateEntryTimestamp);

            case obj.RECEIVING_STATE
                % Update Statistics
                obj.RxStateTime = obj.RxStateTime + (getCurrentTime(obj) - obj.StateEntryTimestamp);
                obj.Rx.RxState = -1;

            case obj.WAITFORRX_STATE
                obj.WaitForRxStateTime = obj.WaitForRxStateTime + (getCurrentTime(obj) - obj.StateEntryTimestamp);
                if obj.Tx.DataFrameSent
                    if obj.MACRecentFrameStatusTimestamp < getCurrentTime(obj)
                        obj.MACRecentFrameStatusTimestamp = getCurrentTime(obj);
                    end
                end

            otherwise % EIFS_STATE
                % Update Statistics
                obj.EIFSStateTime = obj.EIFSStateTime + (getCurrentTime(obj) - obj.StateEntryTimestamp);
        end
    end

    function navWaitExit(obj)
        % Reset NAVWait flags
        obj.Rx.NAVWaitEntry = false;
        updateNAV(obj, obj.Rx.NAVWaitEntryTS);
    end
end

methods
    function value = get.BasicRates(obj)
        if obj.Use6MbpsForControlFrames
            value = 6;
        else
            value = obj.BasicRates;
        end
    end

    function value = get.BasicRatesIndexes(obj)
        % MAC data rate set (Mbps)
        dataRateSet = [6 9 12 18 24 36 48 54];
        value = find(ismember(dataRateSet, obj.BasicRates))-1;
    end

    function set.BasicRates(obj, val)
        mandatoryBasicRates = [6 12 24];
        basicRates = [val mandatoryBasicRates];
        obj.BasicRates = unique(basicRates);
    end

    function set.TxFormat(obj, val)
        obj.TxFormat = val;
        obj.handleMPDUAggregationFlag(val);
    end

    function handleMPDUAggregationFlag(obj, txFormat)
        if txFormat == hFrameFormats.NonHT
            obj.MPDUAggregation = false; % MPDU aggregation is not disabled by default for Non-HT format
        elseif (txFormat == hFrameFormats.VHT || txFormat == hFrameFormats.HE_SU ...
                || txFormat == hFrameFormats.HE_EXT_SU || txFormat == hFrameFormats.HE_MU)
            obj.MPDUAggregation = true; % MPDU aggregation is enabled by default for VHT/HE formats
        end
    end

    % This function has to be called after declaring object and
    % all necessary properties

    function updateBSSProperties(obj)
        % Initialize the initial OBSS threshold value and update BSSColor
        % based on EnableSROperation
        if obj.EnableSROperation
            obj.UpdatedOBSSPDThreshold = obj.OBSSPDThreshold;

        else
            obj.UpdatedOBSSPDThreshold = -82;
            obj.BSSColor = 0;
        end
    end

    % Get Broadcast Destination Identifier value
    function value = get.BroadcastDestinationID(obj)
        value = obj.NumNodes + 2;
    end

    % Get Unknown Destination Identifier value
    function value = get.UnknownDestinationID(obj)
        value = obj.NumNodes + 1;
    end

    % Get current simulation time
    function time = getCurrentTime(obj)
        time = obj.CurrentTime;
    end

    % Validate Configuration parameters
    function validateConfig(obj)
        % Validate RTS threshold if RTS is enabled
        if obj.DisableRTS
            obj.RTSThreshold = obj.PSDUMaxLength; % Max PSDU length supported by 802.11ax
        else
            if obj.RTSThreshold > 65536
                error('RTS threshold must be less than or equal to 65536');
            end
        end

        % Get TxFormat value from TxFormat string, validate MCS range and
        % handle number of transmit chains
        switch obj.TxFormat
            case hFrameFormats.HE_MU
                % Validate NumTxChains
                if (obj.NumTxChains > 1)
                    error('For HE-MU format, number of transmit chains greater than 1 are not supported');
                end
            case hFrameFormats.HE_EXT_SU
                % Validate NumTxChains
                if (obj.NumTxChains > 2)
                    error('For HE-EXT-SU format, number of transmit chains should not be greater than 2');
                end
            case hFrameFormats.NonHT
                % Validate NumTxChains
                if (obj.NumTxChains > 1)
                    error('For Non-HT format, number of transmit chains should not be greater than 1');
                end
            case hFrameFormats.HTMixed
                % Validate NumTxChains
                if (obj.NumTxChains > 4)
                    error('For HTMixed format, number of transmit chains should not be greater than 4');
                end
            otherwise
                % Validate NumTxChains
                if (obj.NumTxChains > 8)
                    error('For HE-SU or VHT format, number of transmit chains should not be greater than 8');
                end
        end

        % Validate MaxDLStations
        if (obj.TxFormat ~= hFrameFormats.HE_MU) && obj.MaxDLStations > 1
            error('MaxDLStations is set to a value greater than 1. For formats other than HE-MU, a maximum of only 1 downlink station is allowed');
        end

        % Handle MPDUAggregation flag
        handleMPDUAggregationFlag(obj, obj.TxFormat);
    end
end

methods (Static)
    % Return the channel bandwidth in string format
    function cbwStr = getChannelBandwidthStr(cbw)
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

    function decimalVal = binaryToDecimal(binaryVal)
    %binaryToDecimal Convert binary to decimal

        decimalVal = 0;
        mul = 1;
        for idx = 1:numel(binaryVal)
            decimalVal = decimalVal + mul*binaryVal(idx);
            mul = mul*2;
        end
    end

    function flag = isGroupAddress(address)
    %isGroupAddress Returns true when the address is broadcast or group
    %address

        bits = bitget(hex2dec(address(1:2)), 1:8);
        flag = bits(1);
    end

    function availableMetrics = getMetricsList()
    %getMetricsList Return the available metrics in MAC
    %
    %   AVAILABLEMETRICS is a cell array containing all the available
    %   metrics in the MAC layer

       availableMetrics = {'MACInternalCollisionsAC', 'MACBackoffAC', 'MACDataTx', 'MACDataTxAC', ...
        'MACAggTxAC', 'MACRetries', 'MACTxRetriesAC', 'MACAckTx', 'MACBATx', 'MACRTSTx', ...
        'MACCTSTx', 'MACDataTxBytes', 'MACDataRxBytes', 'MACControlTxBytes', 'MACControlRxBytes', ...
        'MACTxQueueOverflow', 'MACTxFails', 'MACRx', 'MACDataRx', 'MACDataRxAC', ...
        'MACAggRxAC', 'MACAggRx', 'MACDuplicateAMPDURx', 'MACNonHTRx', 'MACHTRx', 'MACVHTRx', ...
        'MACHESURx', 'MACHEEXTSURx', 'MACHEMURx', 'MACRxDrop', 'MACCRCFailures', 'MACAckRx', 'MACRTSRx', ...
        'MACCTSRx', 'MACBARx', 'MACRespErrors', 'MACNonRespFrames', 'MACOthersFramesInWaitForResp', ...
        'IdleStateTime', 'ContendStateTime', 'SendingDataStateTime', 'WaitForRxStateTime', ...
        'EIFSStateTime', 'RxStateTime', 'MACThroughput', 'MACThroughputAC', 'MACAverageTimePerFrame', ...
        'MACTxSuccess', 'PacketLossRatio', 'MACMaxQueueLengthAC', 'MACDuplicateRxAC', ...
        'MACRTSSuccess', 'MACRecentFrameStatusTimestamp', 'MACNumBasicNavUpdates'};
    end
end
end
