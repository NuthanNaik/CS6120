function nextInvokeTime = handleEventsWaitForRx(obj, phyIndication, elapsedTime)
%handleEventsWaitForRx Runs MAC Layer state machine for receiving
%response frames
%
%   This function performs the following operations:
%   1. Waits for response frames of data and RTS.
%   2. If it doesn't receive any frame within timeout duration,
%      try to retransmit that particular data or RTS frame again.
%   3. Discards packet from retransmission buffer, if maximum
%      retransmission limit is reached.
%   4. Moves to EIFS state, if it receives an error.
%   5. Moves to Rx state, if it receives any frame other than ACK/CTS/BA.
%
%   NEXTINVOKETIME = handleEventsWaitForRx(OBJ, PHYINDICATION,
%   ELAPSEDTIME) performs MAC Layer wait for rx actions.
%
%   NEXTINVOKETIME returns the time (in microseconds) after which the
%   run function must be invoked again.
%
%   PHYINDICATION is indication from PHY Layer.
%
%   ELAPSEDTIME is the time elapsed in microseconds between the
%   previous and current call of this function.

%   Copyright 2021 The MathWorks, Inc.

% Initialize
nextInvokeTime = obj.SlotTime;

% Process if there is any indication received from PHY layer
if ~phyIndication.IsEmpty
    isFail = handlePhyIndicationWaitForRx(obj, phyIndication);
    updateTxStatus(obj, isFail);
    if obj.MACState ~= obj.WAITFORRX_STATE
        nextInvokeTime = obj.NextInvokeTime*(obj.NextInvokeTime > 0);
        return;
    end
end

% Update response timeout counter
obj.Rx.WaitForResponseTimer = obj.Rx.WaitForResponseTimer - elapsedTime;
if obj.Rx.WaitForResponseTimer > 0
    nextInvokeTime = obj.Rx.WaitForResponseTimer;
end

% Process if any response frame is received
if ~(obj.RxData.IsEmpty)
    isFail = processResponse(obj, obj.RxData);
    nextInvokeTime = 0;
    updateTxStatus(obj, isFail);
    return;
end

if obj.Rx.WaitForResponseTimer <= 0
    isFail = handleResponseTimeout(obj);
    updateTxStatus(obj, isFail);
    % Update next invoke time, if state changed while handling response
    % timeout
    if obj.MACState ~= obj.WAITFORRX_STATE
        nextInvokeTime = obj.NextInvokeTime*(obj.NextInvokeTime > 0);
    end
end

end

function updateTxStatus(obj, isFail)
%updateTxStatus Update transmission status to the rate control algorithm
%   updateTxStatus(OBJ, ISFAIL) updates the transmission status to the
%   configured rate control algorithm.
%
%   ISFAIL is a flag indicating whether the transmission has failed 

tx = obj.Tx;
rx = obj.Rx;
% Update transmission status to rate control algorithm
if all(isFail >= 0)
    % Fill the required Tx status info for rate control algorithm
    rateControlInfo = obj.RateControl.TxStatusInfo;
    rateControlInfo.IsFail = isFail;
    rateControlInfo.RSSI = rx.RxRSSI;
    if tx.WaitingForCTS
        % RTS transmission status
        rateControlInfo.FrameType = 'Control';
        % Reset waiting For CTS flag
        tx.WaitingForCTS = false;
    else
        % Data transmission status
        rateControlInfo.FrameType = 'Data';
        if tx.IsShortFrame
            rateControlInfo.NumRetries = tx.ShortRetries(obj.DestinationStationID, obj.OwnerAC+1);
        else
            rateControlInfo.NumRetries = tx.LongRetries(obj.DestinationStationID, obj.OwnerAC+1);
        end
    end
    updateStatus(obj.RateControl, obj.DestinationStationID, rateControlInfo);
end
end

function isFail = handlePhyIndicationWaitForRx(edcaMAC, phyIndication)
%handlePhyIndicationWaitForRx handles physical layer indication in wait for Rx state
%   ISFAIL = handlePhyIndicationWaitForRx(EDCAMAC, PHYINDICATION) handles
%   indications from physical layer in wait for Rx state and sets the
%   corresponding Rx state context and MAC context for a node.
%
%   ISFAIL returns 1 to indicate transmission failure, 0 to indicate
%   transmission success, and -1 to indicate no status.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   PHYINDICATION is the indication received from PHY layer.

isFail = -1;
rx = edcaMAC.Rx;

% PHY Rx start indication
if phyIndication.MessageType == hPHYPrimitives.RxStartIndication
    % Ignore response timeout trigger
    rx.IgnoreResponseTimeout = true;
    % Received frame length
    rx.RxFrameLength = phyIndication.PSDULength(edcaMAC.UserIndexSU);
    % Aggregated MPDU
    rx.RxAggregatedMPDU = phyIndication.AggregatedMPDU;
    % Received frame MCS
    rx.RxMCS = phyIndication.MCSIndex(edcaMAC.UserIndexSU);
    % Received frame format
    rx.RxFrameFormat = phyIndication.FrameFormat;
    % Received channel bandwidth
    rx.RxChannelBandwidth = phyIndication.ChannelBandwidth;
    % Received signal strength
    rx.RxRSSI = phyIndication.RSSI;
    
    % PHY Rx error indication
elseif phyIndication.MessageType == hPHYPrimitives.RxErrorIndication
    % Set PHY Rx error flag
    rx.RxErrorIndication = true;
    rx.IgnoreResponseTimeout = true;
    % Consider Rx error indication as response failure
    handleResponseFailure(edcaMAC);
    isFail = 1;
    
    % PHY CCA Busy indication
elseif phyIndication.MessageType == hPHYPrimitives.CCABusyIndication
    edcaMAC.CCAState = hPHYPrimitives.CCABusyIndication;
    updateAvailableBandwidth(edcaMAC, phyIndication);
    
    % PHY CCA Idle indication
elseif phyIndication.MessageType == hPHYPrimitives.CCAIdleIndication
    updateAvailableBandwidth(edcaMAC, phyIndication);
    % Ignore CCA Idle indication if CCA state is already idle
    if (edcaMAC.CCAState == hPHYPrimitives.CCAIdleIndication)
        return;
    end
    
    % Reset PHY state
    edcaMAC.CCAState = hPHYPrimitives.CCAIdleIndication;
    
    if (rx.RxErrorIndication)
        % Reset PHY Rx error flag
        rx.RxErrorIndication = false;
        % Move to EIFS state
        stateChange(edcaMAC, edcaMAC.EIFS_STATE);
    elseif rx.MoveToSendData
        % Reset flag
        rx.MoveToSendData = false;
        % Move to SendData state
        stateChange(edcaMAC, edcaMAC.SENDINGDATA_STATE);
    else
        % Move to contend state
        stateChange(edcaMAC, edcaMAC.CONTENTION_STATE);
    end
end
end

function isFail = processResponse(edcaMAC, frameFromPHY)
%processResponse Decodes and processes the response frame.
%   ISFAIL = processResponse(EDCAMAC, FRAMEFROMPHY) decodes and processes response
%   frame and updates corresponding context specific to receiving state,
%   MAC context and rate context.
%
%   ISFAIL returns 1 to indicate transmission failure, 0 to indicate
%   transmission success, and -1 to indicate no status. A vector indicates
%   the status for multiple subframes in an A-MPDU.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   FRAMEFROMPHY is the received response frame.

rx = edcaMAC.Rx;
tx = edcaMAC.Tx;
isFail = 1;
if edcaMAC.BABitmapLength == 64
    baFrameLength = 32;
else % edcaMAC.BABitmapLength == 256
    baFrameLength = 56;
end

% Update MAC Rx statistics
edcaMAC.MACNonHTRx = edcaMAC.MACNonHTRx + 1;

% Fill required fields in RxVector
rxVector = edcaMAC.EmptyPHYIndication;
rxVector.IsEmpty = false;
rxVector.PSDULength(edcaMAC.UserIndexSU) = rx.RxFrameLength;
rxVector.AggregatedMPDU = rx.RxAggregatedMPDU;
rxVector.MCSIndex(edcaMAC.UserIndexSU) = rx.RxMCS;
rxVector.FrameFormat = rx.RxFrameFormat;
rxVector.ChannelBandwidth = rx.RxChannelBandwidth;
rxVector.RSSI = rx.RxRSSI;

if edcaMAC.FrameAbstraction
    macFrame = edcaMAC.RxData.MACFrame;
else
    mpduBits = edcaMAC.RxData.Data;
    size = numel(mpduBits)/8;
    macFrame = zeros(size,1);
    idx = 1;
    for i = 1:size
        macFrame(i) = hEDCAMAC.binaryToDecimal(mpduBits(idx:idx+7));
        idx = idx+8;
    end
end

% Create a structure with necessary data to pass while
% triggering the event.
notificationData = struct('NodeID', edcaMAC.NodeID, 'RxVector', rxVector, 'RxFrame', macFrame);
edcaMAC.EventDataObj.Data = notificationData;

% Notify about reception at MAC from PHY
notify(edcaMAC, 'RxEvent', edcaMAC.EventDataObj);

% If received response frame length is not matching with the length of
% Ack/CTS/BA frames, consider it as Tx failure and switch to Rx to process
% the received frame
if (rx.RxFrameLength ~= edcaMAC.AckOrCtsFrameLength) && (rx.RxFrameLength ~= baFrameLength)
    
    if tx.WaitingForCTS
        frameType = 'Control';
        mcs = tx.RTSRate;
        numTxAttempts = tx.ShortRetries(edcaMAC.DestinationStationID, edcaMAC.OwnerAC+1) + 1;
        isSuccess = false;
    else
        frameType = 'Data';
        mcs = tx.TxMCS(edcaMAC.UserIndexSU);
        if tx.IsShortFrame
            numTxAttempts = tx.ShortRetries(edcaMAC.DestinationStationID, edcaMAC.OwnerAC+1) + 1;
        else
            numTxAttempts = tx.LongRetries(edcaMAC.DestinationStationID, edcaMAC.OwnerAC+1) + 1;
        end
        numSubframesWaitingForAck = tx.TxWaitingForAck(edcaMAC.DestinationStationID, edcaMAC.OwnerAC+1);
        isSuccess = false(numSubframesWaitingForAck, 1);
    end

    % Increase retry count
    incrementRetryCount(edcaMAC);
    
    % Create a structure with necessary data to pass while
    % triggering the event.
    notificationData = struct('NodeID', edcaMAC.NodeID, 'FrameType', frameType, ...
        'IsSuccess', isSuccess, ...
        'NumTxAttempts', numTxAttempts, ...
        'MCS', mcs);
    edcaMAC.EventDataObj.Data = notificationData;

    % Notify about transmission status
    notify(edcaMAC, 'TxStatusEvent', edcaMAC.EventDataObj);

    % Update MAC non-response frames reception counter
    edcaMAC.MACNonRespFrames = edcaMAC.MACNonRespFrames + 1;

    % Copy the received frame to MAC Rx buffer
    edcaMAC.RxData = frameFromPHY;

    % Move to receiving state
    stateChange(edcaMAC, edcaMAC.RECEIVING_STATE);
    return;
end

% Decode the received MPDU
if edcaMAC.FrameAbstraction
    [rxCfg, fcsPass] = decodeAbstractedMACFrame(edcaMAC, frameFromPHY.MACFrame, 1);
else % Full MAC frame
    % PSDU bits
    psdu = frameFromPHY.Data(1:(rx.RxFrameLength*8), edcaMAC.UserIndexSU);
    [rxCfg, ~, fcsPass] = decodeMACFrame(edcaMAC, psdu, rx.RxFrameFormat, 0);
end

if fcsPass
    % Update MAC Rx success
    edcaMAC.MACRx = edcaMAC.MACRx + 1;
    % Get the number of frames waiting for acknowledgment
    acIndex = edcaMAC.TID2AC(rxCfg.TID+1) + 1;

    % Frame is intended to this node
    if strcmp(rxCfg.Address1, edcaMAC.MACAddress)
        % If received frame is CTS and node is waiting for CTS frame
        if strcmp(rxCfg.FrameType, 'CTS') && tx.WaitingForCTS
            % Update MAC response frame reception counter
            edcaMAC.MACCTSRx = edcaMAC.MACCTSRx + 1;
            edcaMAC.MACRTSSuccess = edcaMAC.MACRTSSuccess + 1;
            % Update rx control bytes
            edcaMAC.MACControlRxBytes = edcaMAC.MACControlRxBytes + frameFromPHY.PSDULength;

            % Set flag to indicate move to SendData state on medium IDLE
            rx.MoveToSendData = true;
            
            % Return the transmission status
            isFail = 0;

            % Create a structure with necessary data to pass while
            % triggering the event.
            notificationData = struct('NodeID', edcaMAC.NodeID, 'FrameType', 'Control', ...
                'IsSuccess', ~isFail, ...
                'NumTxAttempts', tx.ShortRetries(edcaMAC.DestinationStationID, edcaMAC.OwnerAC+1) + 1, ...
                'MCS', tx.RTSRate);
            edcaMAC.EventDataObj.Data = notificationData;

            % Notify about transmission status
            notify(edcaMAC, 'TxStatusEvent', edcaMAC.EventDataObj);

            % If received frame is Ack and node is waiting for Ack
        elseif strcmp(rxCfg.FrameType, 'ACK') && any(tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), :))
            % Update MAC average time for frame value
            edcaMAC.MACAverageTimePerFrame = edcaMAC.MACAverageTimePerFrame + (tx.MACTxTimeStamp - tx.TxFrame(1).Timestamp(1));
            % Update MAC response frame reception counter
            edcaMAC.MACAckRx = edcaMAC.MACAckRx + 1;
            % Update rx control bytes
            edcaMAC.MACControlRxBytes = edcaMAC.MACControlRxBytes + frameFromPHY.PSDULength;
            psduLength = tx.TxMSDULengths(tx.TxStationIDs(edcaMAC.UserIndexSU), edcaMAC.OwnerAC+1, 1);
            % Update MAC data tx counters
            edcaMAC.MACDataTxBytes = edcaMAC.MACDataTxBytes + psduLength;
            edcaMAC.MACDataTxBytesAC(edcaMAC.Tx.TxACs(edcaMAC.UserIndexSU)) = edcaMAC.MACDataTxBytesAC(edcaMAC.Tx.TxACs(edcaMAC.UserIndexSU)) + psduLength;
            edcaMAC.MACTxSuccess = edcaMAC.MACTxSuccess + 1;
            
            % Return the transmission status
            isFail = 0;

            % Create a structure with necessary data to pass while
            % triggering the event.
            if tx.IsShortFrame
                numTxAttempts = tx.ShortRetries(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex) + 1;
            else
                numTxAttempts = tx.LongRetries(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex) + 1;
            end
            
            notificationData = struct('NodeID', edcaMAC.NodeID, 'FrameType', 'Data', ...
                'IsSuccess', ~isFail, ...
                'NumTxAttempts', numTxAttempts, ...
                'MCS', tx.TxMCS(edcaMAC.UserIndexSU));
            edcaMAC.EventDataObj.Data = notificationData;

            % Notify about transmission status
            notify(edcaMAC, 'TxStatusEvent', edcaMAC.EventDataObj);
            
            % Reset retry count and waiting for Ack flag
            resetRetryCount(edcaMAC);

            % Discard packets from MAC queue
            isSuccess = true;
            numRetries = numTxAttempts - 1;
            discardTxPackets(edcaMAC, isSuccess, numRetries);
            
            % If received frame is Block Ack and node is waiting for Block Ack
        elseif strcmp(rxCfg.FrameType, 'Block Ack') && (tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex) > 0)
            % Reset contention window
            edcaMAC.CW(edcaMAC.OwnerAC+1) = edcaMAC.CWMin(edcaMAC.OwnerAC+1);
            
            % Get sequence numbers of the frames that are acknowledged in BA bitmap
            baSeqNums = getSeqNumsFromBitmap(rxCfg.BlockAckBitmap, rxCfg.SequenceNumber);
            
            % Get sequence numbers of the AMPDU subframes which are not
            % acknowledged for access category of the BA
            txSeqNums = edcaMAC.SeqNumWaitingForAck(1:tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex), acIndex);
            ackedIndices = ismember(txSeqNums, baSeqNums);
            ackedSeqNums = txSeqNums(ackedIndices);
            % Sequence numbers that are not acknowledged in this BA
            seqNumsToBeAcked = txSeqNums(~ackedIndices);

            edcaMAC.MACTxSuccess = edcaMAC.MACTxSuccess + numel(ackedSeqNums);
            edcaMAC.MACBARx = edcaMAC.MACBARx + 1;
            % Remove acknowledged MSDUs from MAC queue
            tx.MSDUDiscardCount(edcaMAC.UserIndexSU) = numel(ackedSeqNums);
            tx.MSDUDiscardIndices(1:tx.MSDUDiscardCount(edcaMAC.UserIndexSU), edcaMAC.UserIndexSU) = ...
                reshape(find(ismember(mod(tx.TxSSN(acIndex): ...
                tx.TxSSN(acIndex)+ tx.InitialSubframesCount(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex)-1, 4096),...
                ackedSeqNums)), [], 1);
            msduIndices = find(ismember(mod(txSeqNums-tx.TxSSN(acIndex), 4096)+1, tx.MSDUDiscardIndices(1:tx.MSDUDiscardCount(edcaMAC.UserIndexSU), edcaMAC.UserIndexSU)));
            psduLength = sum(tx.TxMSDULengths(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex, msduIndices));
            edcaMAC.MACDataTxBytes = edcaMAC.MACDataTxBytes + psduLength;
            edcaMAC.MACDataTxBytesAC(edcaMAC.Tx.TxACs(edcaMAC.UserIndexSU)) = edcaMAC.MACDataTxBytesAC(edcaMAC.Tx.TxACs(edcaMAC.UserIndexSU)) + psduLength;
            % Update rx control bytes
            edcaMAC.MACControlRxBytes = edcaMAC.MACControlRxBytes + frameFromPHY.PSDULength;

            % Update statistics
            edcaMAC.MACAverageTimePerFrame = edcaMAC.MACAverageTimePerFrame + sum(tx.MACTxTimeStamp - tx.TxFrame(edcaMAC.UserIndexSU).Timestamp(msduIndices));

            % All the subframes are acknowledged
            if(isempty(seqNumsToBeAcked))
                
                if tx.IsShortFrame
                    numTxAttempts = tx.ShortRetries(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex) + 1;
                else
                    numTxAttempts = tx.LongRetries(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex) + 1;
                end
                numSubframesWaitingForAck = tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex);
                isSuccess = true(numSubframesWaitingForAck, 1);

                % Reset retry count
                resetRetryCount(edcaMAC);

                % Discard packets from MAC queue
                numRetries = numTxAttempts - 1;
                discardTxPackets(edcaMAC, isSuccess, numRetries);

                % Return the transmission status
                isFail = false;
                
            else % Some or all subframes of the A-MPDU are not acknowledged
                tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex) = numel(seqNumsToBeAcked);
                % Update context of the sequence numbers that are need to be
                % acknowledged
                edcaMAC.SeqNumWaitingForAck(1:tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex), acIndex) = seqNumsToBeAcked;

                if tx.IsShortFrame
                    numTxAttempts = tx.ShortRetries(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex) + 1;
                    maxTxAttempts = edcaMAC.MaxShortRetries;
                else
                    numTxAttempts = tx.LongRetries(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex) + 1;
                    maxTxAttempts = edcaMAC.MaxLongRetries;
                end
                
                % Increase retry count
                incrementRetryCount(edcaMAC);
                
                % Return the transmission status
                isFail = ~ackedIndices;
                isSuccess = ackedIndices;
                
                if ~isempty(ackedSeqNums) && ... % At least one subframe is acknowledged
                        (numTxAttempts ~= maxTxAttempts) % Max retry limit is not reached
                    frame = tx.TxFrame(edcaMAC.UserIndexSU);

                    % Create a structure with necessary data to pass while
                    % triggering the event.
                    notificationData = struct('NodeID', edcaMAC.NodeID, 'AccessCategory', tx.TxACs(edcaMAC.UserIndexSU) - 1, ...
                        'MCS', tx.TxMCS(edcaMAC.UserIndexSU), ...
                        'MSDULengths', frame.MSDULength(msduIndices), ...
                        'SourceAddress', frame.MeshSourceAddress(msduIndices, :), ...
                        'DestinationAddress', frame.MeshDestinationAddress(msduIndices, :), ...
                        'TimeInQueue', getCurrentTime(edcaMAC) - frame.Timestamp(msduIndices), ...
                        'TxSuccess', true(numel(msduIndices), 1), ...
                        'NumRetries', numTxAttempts - 1);
                    edcaMAC.EventDataObj.Data = notificationData;

                    % Notify about packet removal from MAC queue
                    notify(edcaMAC, 'TxDiscardEvent', edcaMAC.EventDataObj);
                end
                edcaQueueManagement(edcaMAC, 'discard');
            end
            % Create a structure with necessary data to pass while
            % triggering the event.
            notificationData = struct('NodeID', edcaMAC.NodeID, 'FrameType', 'Data', ...
                'IsSuccess', isSuccess, ...
                'NumTxAttempts', numTxAttempts, ...
                'MCS', tx.TxMCS(edcaMAC.UserIndexSU));
            edcaMAC.EventDataObj.Data = notificationData;

            % Notify about transmission status
            notify(edcaMAC, 'TxStatusEvent', edcaMAC.EventDataObj);
            
        else % Received frame is not an acknowledgment
            % Response failure
            handleResponseFailure(edcaMAC);
            % Update MAC response frame reception counter
            edcaMAC.MACNonRespFrames = edcaMAC.MACNonRespFrames + 1;
            
            % Copy the received frame to MAC Rx buffer
            edcaMAC.RxData = frameFromPHY;
            % Move to Rx state
            stateChange(edcaMAC, edcaMAC.RECEIVING_STATE);
        end
        
        % Received frame is destined to others
    else
        % Response failure
        handleResponseFailure(edcaMAC);
        % Update MAC response frame destined to others, reception counter
        edcaMAC.MACOthersFramesInWaitForResp = edcaMAC.MACOthersFramesInWaitForResp + 1;
        
        if edcaMAC.EnableSROperation
            if isIntraBSSFrame(edcaMAC, rxCfg, edcaMAC.BSSID) % Frame is intra-BSS
                duration = rxCfg.Duration;
                
                % Update intra NAV
                if edcaMAC.IntraNAV < duration
                    edcaMAC.IntraNAV = duration;
                    % Update MAC intra NAV counter
                    edcaMAC.MACNumIntraNavUpdates = edcaMAC.MACNumIntraNavUpdates + 1;
                end
                
                if strcmp(rxCfg.FrameType, 'CTS')
                    % Reset waiting for NAV reset flag
                    rx.WaitingForNAVReset = false;
                end
            else % Received frame is inter-BSS or neither inter nor intra-BSS
                if strcmp(rxCfg.FrameType, 'CTS') ||...
                        strcmp(rxCfg.FrameType, 'ACK') || strcmp(rxCfg.FrameType, 'Block Ack') || rx.RxRSSI >= edcaMAC.UpdatedOBSSPDThreshold
                    
                    duration = rxCfg.Duration;
                    
                    % Update inter NAV
                    if edcaMAC.InterNAV < duration
                        edcaMAC.InterNAV = duration;
                        % Update MAC basic NAV counter
                        edcaMAC.MACNumBasicNavUpdates = edcaMAC.MACNumBasicNavUpdates + 1;    
                    end
                else
                    edcaMAC.LimitTxPower = true;
                end
            end
        else
            duration = rxCfg.Duration;
            
            % Update NAV
            if edcaMAC.NAV < duration
                edcaMAC.NAV = duration;
                % Update MAC basic NAV counter
                edcaMAC.MACNumBasicNavUpdates = edcaMAC.MACNumBasicNavUpdates + 1;
            end
            if strcmp(rxCfg.FrameType, 'CTS')
                % Reset waiting for NAV reset flag
                rx.WaitingForNAVReset = false;
            end
        end
        
        if edcaMAC.IntraNAV ~= 0  || edcaMAC.InterNAV ~= 0 || edcaMAC.NAV ~= 0
            % Move to NAV wait state
            stateChange(edcaMAC, edcaMAC.RECEIVING_STATE);
            edcaMAC.Rx.RxState = edcaMAC.Rx.NAVWAIT;
        end
        
    end
    
    % Failed to decode the received frame
else
    % Response failure
    handleResponseFailure(edcaMAC);
    % Update MAC response error counters
    edcaMAC.MACRespErrors = edcaMAC.MACRespErrors + 1;
    edcaMAC.MACRxDrop = edcaMAC.MACRxDrop + 1;
    edcaMAC.MACCRCFailures = edcaMAC.MACCRCFailures + 1;
    % Move to EIFS state, when there is no energy in the channel
    if (edcaMAC.CCAState == hPHYPrimitives.CCAIdleIndication)
        stateChange(edcaMAC, edcaMAC.EIFS_STATE);
    else
        rx.RxErrorIndication = true;
    end
end
end

function isFail = handleResponseTimeout(edcaMAC)
%handleResponseTimeout Increments the retry counter and invokes the
%retransmission
%   ISFAIL = handleResponseTimeout(EDCAMAC) increments the retry counter
%   and invokes the retransmission and updates corresponding rx context, tx
%   context and rate context. EDCAMAC is an object of type hEDCAMAC.
%
%   ISFAIL indicates if the frame transmission really failed due to lack of
%   acknowledgment.
isFail = -1;
rx = edcaMAC.Rx;

if rx.IgnoreResponseTimeout == false
    % Response failure
    handleResponseFailure(edcaMAC);
    
    if edcaMAC.CCAState == hPHYPrimitives.CCAIdleIndication
        % Move to contend state
        stateChange(edcaMAC, edcaMAC.CONTENTION_STATE);
    end
    rx.IgnoreResponseTimeout = true;
    isFail = true;
end
end

function handleResponseFailure(edcaMAC)
%handleResponseFailure Performs the operations required when expected
%response is not received
%   handleResponseFailure(EDCAMAC) performs the operations required when
%   expected response is not received and updates corresponding tx context
%   and rate context. EDCAMAC is an object of type hEDCAMAC.

tx = edcaMAC.Tx;

if tx.WaitingForCTS
    frameType = 'Control';
    mcs = tx.RTSRate;
    numTxAttempts = tx.ShortRetries(edcaMAC.DestinationStationID, edcaMAC.OwnerAC+1) + 1;
    isSuccess = false;
else
    frameType = 'Data';
    mcs = tx.TxMCS(edcaMAC.UserIndexSU);
    if tx.IsShortFrame
        numTxAttempts = tx.ShortRetries(edcaMAC.DestinationStationID, edcaMAC.OwnerAC+1) + 1;
    else
        numTxAttempts = tx.LongRetries(edcaMAC.DestinationStationID, edcaMAC.OwnerAC+1) + 1;
    end
    numSubframesWaitingForAck = tx.TxWaitingForAck(edcaMAC.DestinationStationID, edcaMAC.OwnerAC+1);
    isSuccess = false(numSubframesWaitingForAck, 1);
end

% Increase retry count
incrementRetryCount(edcaMAC);

% Create a structure with necessary data to pass while
% triggering the event.
notificationData = struct('NodeID', edcaMAC.NodeID, 'FrameType', frameType, ...
    'IsSuccess', isSuccess, ...
    'NumTxAttempts', numTxAttempts, ...
    'MCS', mcs);
edcaMAC.EventDataObj.Data = notificationData;

% Notify about transmission status
notify(edcaMAC, 'TxStatusEvent', edcaMAC.EventDataObj);

% Reset RTSSent flag
tx.RTSSent = false;
end

function seqNums = getSeqNumsFromBitmap(baBitmap, ssn)
%getSeqNumsFromBitmap(...) Returns acknowledged sequence numbers using
%bitmap and starting sequence number.

% Convert hexadecimal bitmap to binary bitmap
bitmapDec = hex2dec((reshape(baBitmap, 2, [])'));
bitmapDec(1:end) = bitmapDec(end:-1:1);
bitmapDecSize = numel(bitmapDec);
bitmapBits = zeros(8*bitmapDecSize,1);
idx = 1;
for i = 1:bitmapDecSize
    bitmapBits(idx:8*i) = bitget(bitmapDec(i), 1:8)';
    idx = idx+8;
end

% Return the successfully acknowledged sequence numbers
seqNums = rem(ssn+find(bitmapBits)-1, 4096);
end
