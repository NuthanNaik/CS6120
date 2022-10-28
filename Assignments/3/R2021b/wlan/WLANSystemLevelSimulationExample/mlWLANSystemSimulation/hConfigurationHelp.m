classdef hConfigurationHelp
%hConfigurationHelp Provides help for the configuration structures defined in mat files
%
%   hConfigurationHelp('wlanNodeConfig') provides help for the
%   wlanNodeConfig structure which defines the MAC and PHY configuration
%   for a WLAN node.
%
%   hConfigurationHelp('wlanTrafficConfig') provides help for the
%   wlanTrafficConfig structure which defines the application traffic
%   configuration for a WLAN node.

%   Copyright 2021 The MathWorks, Inc.

properties(Constant)
    %wlanNodeConfig Structure defining the MAC and PHY configuration of a node
    %
    %   The fields of the structure are described below in separate
    %   sections for MAC layer, PHY, and channel:
    %
    %   MAC layer configuration fields:
    %   -------------------------------
    %   TxFormat
    %       Description: Transmitting packet format
    %       Value:       Accepts "NonHT", "HTMixed", "VHT", "HE_SU",
    %                    "HE_EXT_SU", and "HE_MU".
    %       Default:     "HE_SU"
    %
    %   Bandwidth
    %       Description: Channel bandwidth (in MHz)
    %       Value:       Accepts 20, 40, 80, or 160.
    %       Default:     20
    %
    %   TxMCS
    %       Description: Specifies the modulation and coding scheme (MCS)
    %                    index that is used for transmitting the frame.
    %                    This value applies only when RateControl is set to
    %                    "FixedRate".
    %       Value:       When TxFormat is set to "HE_SU", accepts
    %                    numbers in the range [0, 11]. 
    %                    At a bandwidth of 20 MHz when TxFormat is set to
    %                    "VHT" and NumTxChains is 3 or 6, accepted range is
    %                    [0, 9]. If the NumTxChains is not 3 or 6, accepted
    %                    range is [0, 8].
    %                    At a bandwidth of 40 MHz when TxFormat is set to
    %                    "VHT", accepted range is [0, 9]
    %                    At a bandwidth of 80 MHz when TxFormat is set to
    %                    "VHT" and NumTxChains is 3 or 7, all the values in
    %                    the range [0, 9] except MCS value 6 are accepted.
    %                    At a bandwidth of 80 MHz when TxFormat is set to
    %                    "VHT" and NumTxChains is 6, accepted range is [0,
    %                    8]. If the NumTxChains is not 6, accepted range is
    %                    [0, 9].
    %                    At a bandwidth of 160 MHz when TxFormat is set to
    %                    "VHT" and NumTxChains is 3, accepted range is [0,
    %                    8]. If the NumTxChains is not 3, accepted range is
    %                    [0, 9]
    %                    When TxFormat is set to "HTMixed" or "NonHT",
    %                    accepted range is [0,7].
    %                    When TxFormat is set to "HE_EXT_SU", accepted
    %                    range is [0,2].
    %                    When TxFormat is set to "HTMixed", the MCS value
    %                    input in the range [0,7] is automatically mapped
    %                    to the index in the range [0,31] based on the
    %                    NumTxChains value.
    %       Default:     7
    %
    %   NumTxChains
    %       Description: Number of transmit chains.
    %       Value:       When TxFormat is set to "VHT" or "HE_SU", accepts 
    %                    numbers in the range [1,8]. When TxFormat is set to
    %                    "HTMixed", accepted range is [1,4]. When TxFormat is
    %                    set to "HE_EXT_SU", accepted range is [1,2]. When
    %                    TxFormat is set to "NonHT", only 1 transmit chain is
    %                    allowed.
    %       Default:     1
    %
    %   MPDUAggregation
    %       Description: Flag that enables MPDU aggregation when set to true.
    %                    Applies only when TxFormat is set to "HTMixed" format.
    %       Value:       A logical scalar (true or false)
    %       Default:     true
    %
    %   DisableAck
    %       Description: Flag indicating the transmitter does not solicit
    %                    acknowledgment for the frame.
    %       Value:       A logical scalar (true or false)
    %       Default:     false
    %
    %   MaxSubframes
    %       Description: Specifies the maximum number of subframes that can be 
    %                    aggregated in the A-MPDU.
    %       Value:       Accepts a number in the range [1,256].
    %       Default:     64
    %
    %   RTSThreshold
    %       Description: Specifies the threshold length of the frame below
    %                    which RTS/CTS protection is not used for data
    %                    transmission. Applies only when DisableRTS is set
    %                    to false.
    %       Value:       Accepts a number in the range [0,65536].
    %       Default:     65536
    %
    %   DisableRTS
    %       Description: Flag that disables RTS/CTS exchange for all the
    %                    data transmissions when set to true.
    %       Value:       A logical scalar (true or false)
    %       Default:     false
    %
    %   MaxShortRetries
    %       Description: Specifies the retry limit for frames less than or
    %                    equal to RTS threshold.
    %       Value:       Accepts a number in the range [1,255].
    %       Default:     7
    %
    %   MaxLongRetries
    %       Description: Specifies the retry limit for frames greater than
    %                    RTS threshold.
    %       Value:       Accepts a number in the range [1,255].
    %       Default:     7
    %
    %   BasicRates
    %       Description: Set of data rates (in Mbps) representing basic
    %                    rate set
    %       Value:       Accepts a vector of data rate values. The values
    %                    must be from the set [6, 9, 12, 18, 24, 36, 48, 54].
    %       Default:     [6 12 24]
    %
    %   Use6MbpsForControlFrames
    %       Description: Flag that forces to use 6 Mbps data rate for all
    %                    control frames ignoring the values in BasicRateSet.
    %       Value:       A logical scalar (true or false)
    %       Default:     false
    %
    %   BandAndChannel
    %       Description: Operating band and channel number
    %       Value:       A cell array of vector in the format {[x, y]} where  
    %                    x = band, y = channel number. The value of x can be
    %                    2.4, 5, or 6. The value of y can be any valid channel
    %                    number.
    %       Default:     {[2.4, 6]}
    %
    %   CWMin
    %       Description: Minimum value for the contention window range for each
    %                    access category.
    %       Value:       A row vector of size 4, indicating the CWMin values
    %                    for four access categories. Each value in the row
    %                    vector must be in the range [1,1023].
    %       Default:     [15 15 7 3]
    %
    %   CWMax
    %       Description: Maximum value for the contention window range for each
    %                    access category.
    %       Value:       A row vector of size 4, indicating the CWMax values
    %                    for four access categories. Each value in the row
    %                    vector must be in the range [1,1023].
    %       Default:     [1023 1023 15 7]
    %
    %   AIFSSlots
    %       Description: Number of arbitrary interframe space (AIFS) slots for
    %                    each access category.
    %       Value:       A row vector of size 4, indicating the number of AIFS 
    %                    slots for four access categories. Each value in the 
    %                    row vector must be in the range [2,15].
    %       Default:     [3 7 2 2]
    %
    %   RateControl
    %       Description: Rate control algorithm to use
    %       Value:       Accepts either "FixedRate" or "ARF"
    %       Default:     "FixedRate"
    %
    %   PowerControl
    %       Description: Power control algorithm to use
    %       Value:       Accepts only "FixedPower"
    %       Default:     "FixedPower"
    %
    %   Physical layer configuration fields:
    %   ------------------------------------
    %   TxPower
    %       Description: Transmit power
    %       Value:       A scalar number representing the transmit power in dBm
    %       Default:     15
    %
    %   TxGain
    %       Description: Transmit gain
    %       Value:       A scalar number representing the transmit gain in dB
    %       Default:     1
    %
    %   RxGain
    %       Description: Receive gain
    %       Value:       A scalar number representing the receive gain in dB
    %       Default:     0
    %
    %   EDThreshold
    %       Description: Energy detection threshold value
    %       Value:       A scalar number representing the threshold in dBm
    %       Default:     -82
    %
    %   RxNoiseFigure
    %       Description: Receiver noise figure
    %       Value:       A scalar number representing the noise figure in dB
    %       Default:     7
    %
    %   Channel configuration fields:
    %   ------------------------------------
    %   NodePosition
    %       Description: Position of the node
    %       Value:       Vector of [x,y,z] format, in units of meters
    %       Default:     [0 0 0]
    %
    %   ReceiverRange
    %       Description: Distance (in meters) beyond which the receiver
    %                    ignores signal to reduce the simulation
    %                    complexity
    %       Value:       A scalar number representing the range in meters
    %       Default:     1000
    %
    %   FreeSpacePathloss
    %       Description: Flag that enables free space pathloss when set to true
    %       Value:       A logical scalar (true or false)
    %       Default:     true
    wlanNodeConfig = [];
    
    %wlanTrafficConfig Structure defining the application traffic configuration
    %
    %   The fields of the structure are described below:
    %
    %   SourceNode
    %       Description: ID of the node transmitting the packet, at
    %                    which the application is running
    %       Value:       A scalar number less than or equal to number of
    %                    nodes in the network
    %       Default:     1
    %
    %   DestinationNode
    %       Description: ID of the node to which the packet originated at
    %                    SourceNode is intended
    %       Value:       A scalar number less than or equal to number of
    %                    nodes in the network
    %       Default:     4
    %
    %   PacketSize
    %       Description: Size of the generated application packets
    %       Value:       A scalar number in the range [1,2034]
    %       Default:     1500
    %
    %   DataRateKbps
    %       Description: Rate at which application packets are generated
    %       Value:       A scalar number representing the data rate in Kbps
    %       Default:     600000
    %
    %   AccessCategory
    %       Description: Access category where 0 represents best-effort 
    %                    traffic (BE), 1 represents background traffic
    %                    (BK), 2 represents video traffic (VI), 3
    %                    represents voice traffic (VO).
    %       Value:       A scalar number in the range [0,3]
    %       Default:     0
    %
    %  To configure multiple applications in the network, the
    %  wlanTrafficConfig structure must be replicated, and the structures
    %  must be configured with desired SourceNode and DestinationNode
    %  values.
    wlanTrafficConfig = [];
end

methods
    function obj = hConfigurationHelp(structureName)
        switch(structureName)
            case 'wlanNodeConfig'
                doc('obj.wlanNodeConfig');
            case 'wlanTrafficConfig'
                doc('obj.wlanTrafficConfig');
        end
    end
end
end