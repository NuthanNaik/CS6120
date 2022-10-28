function frameToPHY = sendData(edcaMAC, retryFlags)
%sendData Generates a data frame
%
%   FRAMETOPHY = sendData(EDCAMAC, RETRYFLAGS) generates the data
%   frame and its relevant information.
%
%   FRAMETOPHY is the generated data frame.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   RETRYFLAGS is the Retransmission flags for dequeued frames.

%   Copyright 2021 The MathWorks, Inc.

tx = edcaMAC.Tx;
% Initialize
frameToPHY = edcaMAC.EmptyFrame;
frameToPHY.IsEmpty = false;

% Generate PSDUs for each user separately and multi-user padding in case of
% MU format
for userIdx = 1:edcaMAC.NumTxUsers
    % Generate single user data frame
    phyFrameData = generateDataPSDU(userIdx, retryFlags, edcaMAC);
    if phyFrameData.PSDULength(edcaMAC.UserIndexSU) >= edcaMAC.RTSThreshold
        tx.IsShortFrame = false;
    else
        tx.IsShortFrame = true;
    end
    
    % Get PSDU data for each user
    frameToPHY.SubframeBoundaries(:, :, userIdx) = phyFrameData.SubframeBoundaries(:, :, edcaMAC.UserIndexSU);
    frameToPHY.NumSubframes(userIdx) = phyFrameData.NumSubframes(edcaMAC.UserIndexSU);
    frameToPHY.Data(:, userIdx) = phyFrameData.Data(:, edcaMAC.UserIndexSU);
    frameToPHY.Timestamp(:, userIdx) = phyFrameData.Timestamp(:, edcaMAC.UserIndexSU);
    frameToPHY.MACFrame = phyFrameData.MACFrame;
    frameToPHY.PSDULength(userIdx) = phyFrameData.PSDULength(edcaMAC.UserIndexSU);
    frameToPHY.SequenceNumbers(:, userIdx) = phyFrameData.SequenceNumbers(:, edcaMAC.UserIndexSU);
end

if edcaMAC.TxFormat == hFrameFormats.HE_MU
    % Create MU PHY configuration object
    cfgHEMU = wlanHEMUConfig(tx.AllocationIndex);
    for userIdx = 1:edcaMAC.NumTxUsers
        cfgHEMU.User{userIdx}.MCS = edcaMAC.Tx.TxMCS(userIdx);
        cfgHEMU.User{userIdx}.APEPLength = frameToPHY.PSDULength(userIdx);
    end
    
    % Get PSDU lengths for each user
    psdulengths = cfgHEMU.getPSDULength();
    frameToPHY.PSDULength(1:edcaMAC.NumTxUsers) = psdulengths;
    
    s = cfgHEMU.validateConfig;
    tx.FrameTxTime = s.TxTime;
end

% Set a flag to indicate that the data frame has been sent
tx.DataFrameSent = true;

% Update MAC tx time stamp
edcaMAC.Tx.MACTxTimeStamp = getCurrentTime(edcaMAC);
end

function psduData = generateDataPSDU(userIdx, retryFlags, edcaMAC)
%generateDataPSDU(...) Generates and returns the data PSDU and its
%information.

tx = edcaMAC.Tx;
frameData = tx.TxFrame(userIdx);
acIndex = frameData.AC+1;

% Update statistics
edcaMAC.MACDataTx = edcaMAC.MACDataTx + frameData.MSDUCount;

if(frameData.DestinationID == edcaMAC.BroadcastID) % Broadcast destination
    stationIdx = edcaMAC.BroadcastDestinationID;
elseif(frameData.DestinationID == 0) % Unknown destination
    stationIdx = edcaMAC.UnknownDestinationID;
else % Valid unicast destination
    stationIdx = frameData.DestinationID;
end

tx.TxSequenceNumbers = zeros(edcaMAC.MaxSubframes, 1);
retry = retryFlags(stationIdx, acIndex);

% Assign sequence number to the frame. Sequence numbers will be
% maintained per AC. For an Aggregated frame, configuring the sequence
% number of the first subframe is sufficient. Sequence number of the
% remaining subframes will be assigned sequentially.

% Assign sequence numbers only in case of normal transmission or
% retransmission due to RTS retry
if (retry == 0) || (tx.TxWaitingForAck(stationIdx, acIndex) == 0)
    % Update Next sequence numbers
    nextSeqNum = tx.SequenceCounter(stationIdx, acIndex);
    tx.TxSequenceNumbers(1:frameData.MSDUCount) = rem((nextSeqNum : nextSeqNum+frameData.MSDUCount-1), 4096);
    
    % Increment and wrap around the sequence number, if it
    % exceeds the maximum sequence number value i.e. 4095
    tx.SequenceCounter(stationIdx, acIndex) = rem(nextSeqNum + frameData.MSDUCount, 4096);
else % Retransmission
    % Use last transmitted frame sequence number from the corresponding AC
    % in case of retransmission
    numRetryMPDUs = tx.TxWaitingForAck(stationIdx, acIndex);
    tx.TxSequenceNumbers(1:numRetryMPDUs) = edcaMAC.SeqNumWaitingForAck(1:numRetryMPDUs, acIndex);
    
    % Update number of MPDUs being aggregated (if any)
    frameData.MSDUCount = numRetryMPDUs;
    tx.TxFrame(userIdx).msduCount = frameData.MSDUCount;

    % Update retransmission statistics
    edcaMAC.MACRetries = edcaMAC.MACRetries + frameData.MSDUCount;
    edcaMAC.MACTxRetriesAC(acIndex) = edcaMAC.MACTxRetriesAC(acIndex) + frameData.MSDUCount;
end

% Retain the starting sequence number as reference for indexing
% into MSDU list in the 'frameData' for re-aggregation.
tx.TxSSN(acIndex) = mod(tx.SequenceCounter(stationIdx, acIndex)-tx.InitialSubframesCount(stationIdx, acIndex), 4096);

% Response frame duration
if edcaMAC.MPDUAggregation && ((edcaMAC.TxFormat == hFrameFormats.HTMixed) || (frameData.MSDUCount > 1))
    % Estimated time (in micro seconds) to transmit Block Acknowledgment.
    if edcaMAC.BABitmapLength == 64
        responseFrameLength = 32;
    else % edcaMAC.BABitmapLength == 256
        responseFrameLength = 56;
    end
else
    % Estimated time (in micro seconds) to transmit the Normal Acknowledgment.
    responseFrameLength = 14; % Ack or CTS length
end
cbw = 20; % response in transmitted in Non-HT 20 MHz
numSTS = 1; % Number of space time streams in Non-HT frame format
respMCS = responseMCS(edcaMAC, edcaMAC.TxFormat, cbw, edcaMAC.MPDUAggregation, edcaMAC.Tx.TxMCS(edcaMAC.UserIndexSU), edcaMAC.NumTxChains);
responseDuration = calculateTxTime(edcaMAC, cbw, respMCS, responseFrameLength, hFrameFormats.NonHT, numSTS);

% Acknowledgment not required
if edcaMAC.DisableAck || (frameData.DestinationID == edcaMAC.BroadcastID)
    tx.MSDUBytesNoAck = tx.MSDUBytesNoAck + sum(tx.TxMSDULengths(stationIdx, acIndex, 1:frameData.MSDUCount));
    durationField = 0;
else % Acknowledgment required
    durationField = responseDuration + edcaMAC.SIFSTime;
end

% Generate Data frame to transmit to PHY layer
psduData = generateDataFrame(edcaMAC, retry, durationField, frameData, userIdx);

if edcaMAC.TxFormat ~= hFrameFormats.HE_MU
    % Bandwidth for data transmission
    cbw = edcaMAC.AvailableBandwidth;
    % PPDU transmission time
    tx.FrameTxTime = calculateTxTime(edcaMAC, cbw, edcaMAC.Tx.TxMCS(edcaMAC.UserIndexSU), psduData.PSDULength(1), edcaMAC.TxFormat, edcaMAC.NumTxChains);
end

% Store the number of transmitted frames and their sequence numbers to
% verify with the received acknowledgment and retry, if needed.
edcaMAC.MACDataTxAC(acIndex) = edcaMAC.MACDataTxAC(acIndex) + frameData.MSDUCount;

if edcaMAC.MPDUAggregation
    edcaMAC.MACAggTxAC(acIndex) = edcaMAC.MACAggTxAC(acIndex) + 1;
end

% For frames with normal-ack policy, set 'txWaitingForAck' count
% when one of the following cases is true:
%   1. Normal transmission
%   2. Retransmission due to RTS retry
if ~edcaMAC.DisableAck && (~retry || (retry && ~tx.TxWaitingForAck(stationIdx, acIndex)))
    % Update Sequence numbers waiting for ACK
    edcaMAC.SeqNumWaitingForAck(1 : frameData.MSDUCount, acIndex) = tx.TxSequenceNumbers(1:frameData.MSDUCount);
    
    % Update number of frames waiting for ACK
    tx.TxWaitingForAck(stationIdx, acIndex) = frameData.MSDUCount;
end
end
