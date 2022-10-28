function nextInvokeTime = handleEventsEIFS(obj, phyIndication, elapsedTime)
%handleEventsEIFS Handle the operations in EIFS state
%
%   NEXTINVOKETIME = handleEventsEIFS(OBJ, PHYINDICATION, ...
%   ELAPSEDTIME) performs actions on MAC layer EIFS state.
%
%   NEXTINVOKETIME returns the time in microseconds after which
%   the run function must be invoked again.
%
%   PHYINDICATION is the CCAState indicates by the physical layer.
%
%   ELAPSEDTIME is the time elapsed in microseconds between the
%   previous and current call of this function.

%   Copyright 2021 The MathWorks, Inc.

if ~phyIndication.IsEmpty && (phyIndication.MessageType == hPHYPrimitives.CCABusyIndication)
    % Update NAV before moving to receiving state
    updateNAV(obj, obj.StateEntryTimestamp);
    % Exit EIFS state and move to receiving state
    obj.CCAState = hPHYPrimitives.CCABusyIndication;
    updateAvailableBandwidth(obj, phyIndication);
    stateChange(obj, obj.RECEIVING_STATE);
    % In the receiving state, next invoke time is controlled by the
    % physical layer receiver
    nextInvokeTime = -1;
    return;
end

% Update EIFS timer
obj.NextInvokeTime = obj.NextInvokeTime - elapsedTime;

% Exit state if error recovery time is completed
if obj.NextInvokeTime <= 0
    % Update NAV
    updateNAV(obj, obj.StateEntryTimestamp);
    
    if ~obj.InterNAV && ~obj.IntraNAV && ~obj.NAV
        % Exit EIFS state and move to contention state
        stateChange(obj, obj.CONTENTION_STATE);
    else
        % Exit EIFS state and move to receiving state and continue
        % in NAV wait substate
        stateChange(obj, obj.RECEIVING_STATE);
        obj.Rx.RxState = obj.Rx.NAVWAIT;
    end
end
nextInvokeTime = obj.NextInvokeTime;
end

