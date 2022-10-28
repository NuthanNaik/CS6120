function [macReqToPHY, frameToPHY, nextInvokeTime] = ...
    handleEventsSendingData(obj, phyIndication, elapsedTime)
%handleEventsSendingData Runs MAC Layer state machine for sending data
%
%   This function performs the following operations:
%   1. Sends Transmission vector to Physical Layer before
%   transmitting any frame.
%   2. Generate and send the date frame to PHY
%   3. Generate and send RTS Frame if Frame length is '>='
%   RTSThreshold value.
%
%   [MACREQTOPHY, FRAMETOPHY, NEXTINVOKETIME] =
%   handleEventsSendingData(OBJ, ELAPSEDTIME) performs MAC Layer
%   Sending Data Actions.
%
%   MACREQTOPHY returns Transmission Request to PHY Layer.
%
%   FRAMETOPHY returns Data frame to PHY Layer.
%
%   NEXTINVOKETIME returns the time (in microseconds) after which the
%   run function must be invoked again.
%
%   OBJ is an object of type hEDCAMAC.
%
%   PHYINDICATION is indication from PHY Layer.
%
%   ELAPSEDTIME is the time elapsed in microseconds between the
%   previous and current call of this function.

%   Copyright 2021 The MathWorks, Inc.

% Initialize
macReqToPHY = obj.EmptyPHYIndication;
frameToPHY = obj.EmptyFrame;
nextInvokeTime = 0;

switch(obj.Tx.TxState)
    case obj.Tx.TXINIT_STATE
        % Schedule stations
        obj.runScheduler(obj.MaxDLStations);
        
        % Dequeue packets for transmission
        obj.edcaQueueManagement('dequeue');
        
        % Calculate PSDU length and MPDU length(s)
        [psduLength, mpduLengths, subframeLengths] = getPSDULength(obj);
        obj.Tx.TxPSDULength = psduLength;
        obj.Tx.TxMPDULengths = mpduLengths;
        obj.Tx.TxSubframeLengths = subframeLengths;
        
        if obj.Tx.TxFrame(obj.UserIndexSU).DestinationID == obj.BroadcastID
            % Transmit broadcast frames with maximum basic rate
            obj.Tx.TxMCS(obj.UserIndexSU) = max(obj.BasicRatesIndexes);
            
            % No acknowledgment for broadcast frames
            obj.Tx.NoAck = true;
            
            % Reset transmission invoke time
            obj.NextInvokeTime = 0;
            
            obj.Tx.TxState = obj.Tx.TRANSMITDATA_STATE;
            
        else % Unicast frame
            % Ack policy for this frame transmission
            obj.Tx.NoAck = obj.DisableAck;
            
            if obj.Tx.TxPSDULength(obj.UserIndexSU) >= obj.RTSThreshold && ~(obj.TxFormat == hFrameFormats.HE_MU)
                % Move to substate TRANSMITRTS_STATE
                obj.Tx.TxState = obj.Tx.TRANSMITRTS_STATE;
            else
                % Reset Tx Invoke time
                obj.NextInvokeTime = 0;
                % Move to substate TRANSMITDATA_STATE
                obj.Tx.TxState = obj.Tx.TRANSMITDATA_STATE;
            end
        end
        
    case obj.Tx.TRANSMITDATA_STATE
        % Wait for SIFS if RTS/CTS exchange is involved,
        % else wait time will be zero.
        obj.NextInvokeTime = obj.NextInvokeTime - elapsedTime;
        nextInvokeTime = obj.NextInvokeTime*(obj.NextInvokeTime > 0);
        
        if obj.NextInvokeTime <= 0
            if ~phyIndication.IsEmpty && (phyIndication.MessageType == hPHYPrimitives.TxStartConfirm)
                % Generate and send data frame to PHY Layer
                frameToPHY = sendData(obj, obj.EDCAQueues.RetryFlags);

                % Create a structure with necessary data to pass while
                % triggering the event.
                notificationData = struct('NodeID', obj.NodeID, 'TxFrameType', 'Data', ...
                    'TxFrame', frameToPHY, ...
                    'TxMCS', obj.Tx.TxMCS(obj.UserIndexSU), ...
                    'TxTime', obj.Tx.FrameTxTime);
                obj.EventDataObj.Data = notificationData;

                % Notify about transmission from MAC to PHY
                notify(obj, 'TxEvent', obj.EventDataObj);

                % Reset flags
                obj.Tx.RTSSent = false;
                obj.Tx.WaitingForCTS = false;
                
                % Move to substate WAITFORPHY_STATE
                obj.Tx.TxState = obj.Tx.WAITFORPHY_STATE;
                obj.NextInvokeTime = obj.Tx.FrameTxTime;
                nextInvokeTime = obj.NextInvokeTime;
            else
                obj.Tx.MSDUBytesNoAck = 0;
                
                % Prepare Tx Request to PHY Layer
                macReqToPHY = sendTxRequest(obj, "Start", obj.AvailableBandwidth, obj.TxFormat, obj.Tx.TxMCS, obj.Tx.TxPSDULength);
            end
        end
        
    case obj.Tx.TRANSMITRTS_STATE
        if ~phyIndication.IsEmpty && (phyIndication.MessageType == hPHYPrimitives.TxStartConfirm)
            % Generate and send RTS frame to PHY layer
            frameToPHY = sendRTS(obj);
            obj.MACControlTxBytes = obj.MACControlTxBytes + frameToPHY.PSDULength;

            % Create a structure with necessary data to pass while
            % triggering the event.
            notificationData = struct('NodeID', obj.NodeID, 'TxFrameType', 'Control', ...
                'TxFrame', frameToPHY, ...
                'TxMCS', obj.Tx.RTSRate, ...
                'TxTime', obj.Tx.FrameTxTime);
            obj.EventDataObj.Data = notificationData;

            % Notify about transmission from MAC to PHY
            notify(obj, 'TxEvent', obj.EventDataObj);
            
            % Set RTS sent and waiting for CTS flags
            obj.Tx.RTSSent = true;
            obj.Tx.WaitingForCTS = true;
            % Reset Sent Data frame flag
            obj.Tx.DataFrameSent = false;
            
            % For next run, change the state to WaitForPHY
            obj.Tx.TxState = obj.Tx.WAITFORPHY_STATE;
            obj.NextInvokeTime = obj.Tx.FrameTxTime;
            nextInvokeTime = obj.NextInvokeTime;
        else
            rtsFrameLength = 20;

            rateControlInfo = obj.RateControl.TxInfo;
            rateControlInfo.FrameType = 'Control';
            rateControlInfo.IsUnicast = true;
            % Method invocation using dot notation is done for MATLAB
            % compiler support
            rate = obj.RateControl.getRate(obj.DestinationStationID, rateControlInfo);
            if obj.Use6MbpsForControlFrames
                % Use 6Mbps for control frames
                rate = obj.Tx.BasicRate;
            end
            obj.Tx.RTSRate = rate;

            % Prepare Tx Request to PHY Layer
            macReqToPHY = sendTxRequest(obj, "Start", obj.AvailableBandwidth, hFrameFormats.NonHT, ...
                [rate; zeros(8,1)], [rtsFrameLength; zeros(8,1)]);
        end
        
    otherwise % Wait For PHY
        if ~obj.Tx.WaitForPHYEntry
            obj.Tx.PHYTxEntryTS = getCurrentTime(obj);
            hPlotStateTransition([obj.NodeID obj.OperatingFreqID], 2,  getCurrentTime(obj), obj.Tx.FrameTxTime, obj.NumNodes);
            obj.Tx.WaitForPHYEntry = true;
        end
        
        % Wait for frame transmission time
        obj.NextInvokeTime = obj.NextInvokeTime - elapsedTime;
        nextInvokeTime = obj.NextInvokeTime*(obj.NextInvokeTime > 0);
        
        % Frame transmission time is completed
        if obj.NextInvokeTime <= 0
            % Send Tx End Request
            if ~phyIndication.IsEmpty && (phyIndication.MessageType == hPHYPrimitives.TxEndConfirm)
                % Move to Contend if the transmitted frame does not require a response
                if obj.Tx.NoAck && ~obj.Tx.RTSSent
                    % Update Statistics
                    if obj.MACRecentFrameStatusTimestamp < getCurrentTime(obj)
                        obj.MACRecentFrameStatusTimestamp = getCurrentTime(obj);
                    end
                    obj.MACDataTxBytes = obj.MACDataTxBytes + obj.Tx.MSDUBytesNoAck;
                    obj.MACDataTxBytesAC(obj.Tx.TxACs(obj.UserIndexSU)) = obj.MACDataTxBytesAC(obj.Tx.TxACs(obj.UserIndexSU)) + obj.Tx.MSDUBytesNoAck;
                    obj.MACTxSuccess = obj.MACTxSuccess + sum(obj.Tx.TxMSDUCount(1:obj.NumTxUsers));
                    obj.MACAverageTimePerFrame = obj.MACAverageTimePerFrame + sum(obj.Tx.MACTxTimeStamp - obj.Tx.TxFrame(obj.UserIndexSU).Timestamp(1:obj.Tx.TxMSDUCount(obj.UserIndexSU)));
                    
                    % Reset retry count
                    resetRetryCount(obj);

                    % Discard packets from MAC queue
                    isSuccess = true(obj.Tx.InitialSubframesCount(obj.Tx.TxStationIDs(obj.UserIndexSU), obj.Tx.TxACs(obj.UserIndexSU)), 1);
                    numRetries = 0;
                    discardTxPackets(obj, isSuccess, numRetries);
                    
                    % Move to Contend state
                    stateChange(obj, obj.CONTENTION_STATE);
                else
                    % Move to WaitForRx state if the transmitted frame requires a response
                    stateChange(obj, obj.WAITFORRX_STATE);
                end
                % For next run, Reset the states
                obj.Tx.TxState = obj.Tx.TXINIT_STATE;
                obj.Tx.WaitForPHYEntry = false;
            else
                macReqToPHY = sendTxRequest(obj, "End");
            end
        end
end
end


function frameToPHY = sendRTS(edcaMAC)
%sendRTS Generates an RTS frame
%
%   FRAMETOPHY = sendRTS(EDCAMAC) generates an RTS frame and updates the Tx
%   context with the frame transmission time.
%
%   FRAMETOPHY is the generated RTS frame.
%
%   EDCAMAC is an object of type hEDCAMAC.

if ((edcaMAC.MPDUAggregation) && (edcaMAC.TxFormat == hFrameFormats.HTMixed)) || any(edcaMAC.Tx.TxMSDUCount(1:edcaMAC.NumTxUsers) > 1)
    % For aggregated frames acknowledgment is Block Ack
    if edcaMAC.BABitmapLength == 64
        baFrameLength = 32;
    else % edcaMAC.BABitmapLength == 256
        baFrameLength = 56;
    end
    cbw = 20;
    numSTS = 1;
    respMCS = responseMCS(edcaMAC, edcaMAC.TxFormat, cbw, edcaMAC.MPDUAggregation, edcaMAC.Tx.TxMCS(edcaMAC.UserIndexSU), edcaMAC.NumTxChains);
    ackDuration = calculateTxTime(edcaMAC, cbw, respMCS, baFrameLength, hFrameFormats.NonHT, numSTS);
else % Non aggregated MPDU
    % For non-aggregated frames acknowledgment is Normal Ack
    ackFrameLength = 14;
    cbw = 20;
    numSTS = 1;
    respMCS = responseMCS(edcaMAC, edcaMAC.TxFormat, cbw, edcaMAC.MPDUAggregation, edcaMAC.Tx.TxMCS(edcaMAC.UserIndexSU), edcaMAC.NumTxChains);
    ackDuration = calculateTxTime(edcaMAC, cbw, respMCS, ackFrameLength, hFrameFormats.NonHT, numSTS);
end

% Bandwidth for data transmission
cbw = edcaMAC.AvailableBandwidth;
% Calculate Duration field of the RTS frame
duration = 3*edcaMAC.SIFSTime + edcaMAC.CTSDuration + ackDuration + ...
    calculateTxTime(edcaMAC, cbw, edcaMAC.Tx.TxMCS(edcaMAC.UserIndexSU), edcaMAC.Tx.TxPSDULength(edcaMAC.UserIndexSU), edcaMAC.TxFormat, edcaMAC.NumTxChains);

if edcaMAC.Tx.NoAck
    % If acknowledgments are disabled, subtract the acknowledgment duration
    % and a SIFS
    duration = duration - ackDuration - edcaMAC.SIFSTime;
end

% Create a structure with fields corresponding to elements of the
% ControlFrameData bus object. This used as input to the
% generateControlFrame function.
rtsFrameData = struct('FrameType', 'RTS', ...
    'Duration', duration, ...
    'Address1', edcaMAC.Tx.TxFrame(edcaMAC.UserIndexSU).DestinationMACAddress, ...
    'Address2', edcaMAC.MACAddress);

% Generate RTS frame
[frameToPHY, rtsLen] = generateControlFrame(edcaMAC, rtsFrameData);

% Bandwidth for RTS transmission
cbw = 20;
numSTS = 1; % Number of spatial streams for RTS transmission
% Calculate RTS frame duration
edcaMAC.Tx.FrameTxTime = calculateTxTime(edcaMAC, cbw, edcaMAC.Tx.RTSRate, rtsLen, hFrameFormats.NonHT, numSTS);
edcaMAC.Tx.IsShortFrame = true;

% Update MAC RTS transmission counter
edcaMAC.MACRTSTx = edcaMAC.MACRTSTx + 1;

end
