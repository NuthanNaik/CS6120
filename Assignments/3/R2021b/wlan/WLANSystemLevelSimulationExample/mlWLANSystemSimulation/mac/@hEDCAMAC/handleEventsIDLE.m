function nextInvokeTime = handleEventsIDLE(obj, phyIndication, ~)
%handleEventsIDLE Handle the operations in IDLE state
%
%   NEXTINVOKETIME = HANDLEEVENTSIDLE(OBJ, PHYINDICATION) performs
%   actions on MAC layer IDLE state.
%
%   PHYINDICATION is the CCAState indicates by the physical layer.
%
%   NEXTINVOKETIME returns the time in microseconds after which the
%   run function must be invoked again.

%   Copyright 2021 The MathWorks, Inc.

nextInvokeTime = -1;

if ~phyIndication.IsEmpty && (phyIndication.MessageType == hPHYPrimitives.CCABusyIndication)
    % Move to Receiving state
    obj.CCAState = hPHYPrimitives.CCABusyIndication;
    updateAvailableBandwidth(obj, phyIndication);
    stateChange(obj, obj.RECEIVING_STATE);
    % In the receiving state, next invoke time is controlled by the
    % physical layer receiver
    nextInvokeTime = -1;
    
elseif nnz(obj.EDCAQueues.TxQueueLengths)
    if obj.AggressiveChannelAccess
        % Move to SendingData state
        stateChange(obj, obj.SENDINGDATA_STATE);
    else
        % Move to Contention state
        stateChange(obj, obj.CONTENTION_STATE);
    end
    nextInvokeTime = 0;
end
end
