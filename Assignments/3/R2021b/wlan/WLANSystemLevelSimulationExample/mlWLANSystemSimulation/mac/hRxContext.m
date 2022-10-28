classdef hRxContext < handle
%hRxContext Create an object to maintain context specific to receiving
%state for a node
%
%   OBJ = hRxContext(NUMNODES) creates an object, OBJ to maintain context
%   specific to receiving state for a node. 
%
%   NUMNODES is the number of nodes in network.
%
%   hRxContext properties:
%   RxFrameLength     - Length of received frame
%   RxAggregatedMPDU  - Indication whether frame is aggregated or not
%   RxFrameFormat     - Format of received frame
%   RxRSSI            - Received signal strength
%   RxMCS             - MCS of received frame
%   ResponseMCS       - MCS Index of response frame
%   ResponseLength    - Length of response frame
%   ResponseFlag      - Flag to indicate whether response should be sent
%   RxState           - Next sub-state in Rx state to which node moves

%   Copyright 2021 The MathWorks, Inc.
  
properties
    
    %RxFrameLength Length of received frame
    %   RxFrameLength is a scalar value representing length of received
    %   frame in octets.
    RxFrameLength(1, 1) {mustBeNumeric} = 0;
    
    %RxAggregatedMPDU Indication whether frame is aggregated or not
    %   RxAggregatedMPDU is a logical value set to true if the received
    %   frame is an A-MPDU.
    RxAggregatedMPDU(1, 1) logical = false;
    
    %RxFrameFormat Format of received frame
    %   RxFrameFormat represents enumerated value of format of received
    %   frame. Enumeration is defined in 'hFrameFormats' class.
    RxFrameFormat = hFrameFormats.NonHT;
    
    %RxChannelBandwidth Channel bandwidth indicated in the Rx vector
    %   RxChannelBandwidth is the bandwidth indicated in the Rx vector
    %   of the received frame.
    RxChannelBandwidth = 20;
    
    %RxRSSI Received signal strength
    %   RxRSSI represents received signal strength as an integer in the
    %   range of [0 - 127]. The default value is 0.
    RxRSSI(1, 1) {mustBeNumeric, mustBeNonnegative, mustBeLessThanOrEqual(RxRSSI, 127)} = 0;
    
    %RxMCS MCS of received frame
    %   RxMCS is a scalar value representing MCS index of received
    %   frame.
    RxMCS(1, 1) {mustBeNonnegative} = 0;
    
    %ResponseMCS MCS index of response frame
    %   ResponseMCS is a scalar integer value specified in the range of
    %   [0 - 7] representing MCS Index of the frame to be sent as response
    %   to received frame.
    ResponseMCS(1, 1) {mustBeInteger, mustBeNonnegative, mustBeLessThanOrEqual(ResponseMCS, 7)} = 0;
    
    %ResponseLength Length of response frame
    %   ResponseLength is a scalar value representing length of response
    %   frame in octets.
    ResponseLength(1, 1) {mustBeNumeric, mustBeNonnegative} = 0;
    
    %ResponseFlag Flag to indicate whether response should be sent
    %   Set ResponseFlag to true when the sender is expecting a response
    %   to current frame.
    ResponseFlag(1, 1) logical = false;
    
    %RxState Sub-state of Rx state
    %   RxState represents sub-state in Rx state(either 0| 1| 2| 3).
    %   0 - Processing
    %   1 - Responding
    %   2 - TxEndRequest
    %   3 - NAVWait
    RxState(1, 1) {mustBeInteger} = -1;
    
end

properties(Constant, Hidden)
    PROCESSING = 0;
    RESPONDING = 1;
    TXENDREQUEST = 2;
    NAVWAIT = 3;
end

properties(Hidden)
    %RxErrorIndication Flag to indicate Rx error indication from PHY layer
    %   RxErrorIndication is a logical value that is set to true when Rx
    %   error indication is received from PHY layer.
    RxErrorIndication
    
    %MoveToSendData Flag to indicate to move to send data state.
    %   MoveToSendData is a logical value that is set to true to indicate
    %   to move to send data state when medium is idle.
    MoveToSendData
    
    %WaitingForNAVReset Flag to indicate that NAV should be reset
    %   WaitingForNAVReset is a logical value that is set to true to
    %   indicate that NAV should be reset to zero.
    WaitingForNAVReset
    
    %IgnoreResponseTimeout Flag to ignore response timeout trigger
    %   IgnoreResponseTimeout is a logical value that is set to true to
    %   indicate response timeout should be ignored.
    IgnoreResponseTimeout
    
    %LastRxSequenceNum Sequence number of last received frame
    %   LastRxSequenceNum is a vector of size N x 4 where N is number of nodes
    %   in network and 4 is the number of access categories. Each element
    %   in the vector is an integer in the range of [0 - 4095] representing
    %   sequence number of last received frame from corresponding node in
    %   corresponding AC.
    LastRxSequenceNum
    
    %BABitmap BA bitmap for all four access categories
    %   BABitmap is an array of size N x 4 x M where N is the number of
    %   associated nodes in the network, 4 is the number of access
    %   categories, and M is the maximum number of subframes in an
    %   aggregated frame. The third dimension represents Block Ack bitmap
    %   for frames from corresponding node and AC.
    BABitmap
    
    %LastSSN Last starting sequence number(SSN)
    %   LastSSN is an array of size N x 4 where N is the number of nodes in
    %   network and 4 is the number of access categories. Each element is
    %   in the range of [0 - 4095] and represents starting sequence number
    %   of last received frame from corresponding node in the corresponding
    %   AC.
    LastSSN
    
    %ProcessingEntry Flag to indicate entry into Processing sub-state.
    %   ProcessingEntry is set to true to indicate that processing sub-state
    %   is entered.
    ProcessingEntry
    
    %RespondingEntry Flag to indicate entry into Responding sub-state.
    %   RespondingEntry is set to true to indicate that responding sub-state
    %   is entered.
    RespondingEntry
    
    %TxEndRequestEntry Flag to indicate entry into TxEndRequest sub-state.
    %   TxEndRequestEntry is set to true to indicate that TxEndRequest
    %   sub-state is entered.
    TxEndRequestEntry = false;
    
    %NAVWaitEntry Flag to indicate entry into NAV Wait sub-state.
    %   NAVWaitEntry is set to true to indicate that NAV Wait sub-state
    %   is entered.
    NAVWaitEntry
    
    %ProcessingEntryTS Entry timestamp for Processing sub-state in Rx state
    ProcessingEntryTS
    
    %RespondingEntryTS Entry timestamp for Responding sub-state in Rx state
    RespondingEntryTS
    
    %TxEndReqEntryTS Entry timestamp for TxEndRequest sub-state in Rx state
    TxEndReqEntryTS
    
    %RTSEntryTS Entry timestamp for RTS
    RTSEntryTS
    
    %CTSEntryTS Entry timestamp for CTS
    CTSEntryTS
    
    %NAVWaitEntryTS Entry timestamp for NAV Wait state
    NAVWaitEntryTS
    
    %UpdateRTSNAV
    UpdateRTSNAV
    
    %TxRequestInvokeTime Duration after which Tx start and end requests must be
    %sent.
    TxRequestInvokeTime = 16;
    
    %WaitForResponseTimer Timer for waiting on response frame.
    %   (SIFS + SlotTime + PHYRxStartDelay) = (16 + 9 + 20)
    WaitForResponseTimer = 45;
    
    %WaitForNAVTimer Timer for waiting on NAV time, which is the maximum of
    %NAV, Inter-NAV and Intra-NAV
    WaitForNAVTimer
end

methods
    function obj = hRxContext(numNodes, bitmapLength, varargin)
        % Constructor to create object for maintaining context specific to
        % receiving state.
        
        obj.RxErrorIndication = false;
        obj.MoveToSendData = false;
        obj.WaitingForNAVReset = false;
        obj.IgnoreResponseTimeout = false;
        obj.LastRxSequenceNum = zeros(numNodes, 4);
        obj.BABitmap = zeros(numNodes, 4, bitmapLength);
        obj.LastSSN = zeros(numNodes, 4);
        obj.ProcessingEntry = false;
        obj.RespondingEntry = false;
        obj.TxEndRequestEntry = false;
        obj.NAVWaitEntry = false;
        obj.ProcessingEntryTS = 0;
        obj.RespondingEntryTS = 0;
        obj.TxEndReqEntryTS = 0;
        obj.NAVWaitEntryTS = 0;
        obj.RTSEntryTS = 0;
        obj.CTSEntryTS = 0;
        obj.UpdateRTSNAV = true;
        
        % Assign properties specified as name-value pairs
        for idx = 1:2:numel(varargin)
            obj.(varargin{idx}) = varargin{idx+1};
        end
    end
end
end
