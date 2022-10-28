function nextInvokeTime = handleEventsContention(obj, phyIndication, elapsedTime)
%handleEventsContention Handle the operations in Contention state
%
%   NEXTINVOKETIME = handleEventsContention(OBJ, PHYINDICATION, ...
%   ELAPSEDTIME) performs actions on MAC layer Contention state.
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
    % Move to Receiving state
    obj.CCAState = hPHYPrimitives.CCABusyIndication;
    updateAvailableBandwidth(obj, phyIndication);
    stateChange(obj, obj.RECEIVING_STATE);
    % In the receiving state, next invoke time is controlled by the
    % physical layer receiver
    nextInvokeTime = -1;
    return;
end

% Wait for SIFS time before invoking backoff algorithm
if obj.BackoffInvokeTime > 0
    obj.BackoffInvokeTime = obj.BackoffInvokeTime - elapsedTime;
    if obj.BackoffInvokeTime <= 0
        % Update the leftover elapsed time after decrementing the
        % backoff invoke timer
        elapsedTime = abs(obj.BackoffInvokeTime);
    end
end

% Invoke backoff algorithm if SIFS time has elapsed
if obj.BackoffInvokeTime <= 0
    % Call backoff algorithm
    backoffAlgorithm(obj, elapsedTime);
    nextInvokeTime = obj.NextInvokeTime;
else
    nextInvokeTime = obj.BackoffInvokeTime;
end
end


function backoffAlgorithm(edcaMAC, elapsedTime)
%backoffAlgorithm Performs contention for each access category (AC) based
%on Enhanced Distributed Channel Access (EDCA).
%
%   backoffAlgorithm(EDCAMAC, ELAPSEDTIME) performs contention for each
%   access category.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   ELAPSEDTIME is the time elapsed in microseconds between the previous
%   and current call of this function.

% Initialize txop AC
txopAC = -1;

nextInvokeTimeAC = zeros(1, 4);
elapsedTimeAC = repmat(elapsedTime, 1, 4);

% For each access category
for acIndex = [2 1 3 4]
    nextInvokeTimeAC(acIndex) = 0;
    
    if (edcaMAC.AIFSSlotCounter(acIndex) ~= 0)
        % Decrement AIFS counter
        if (edcaMAC.AIFSSlotCounter(acIndex) > elapsedTimeAC(acIndex))
            edcaMAC.AIFSSlotCounter(acIndex) = edcaMAC.AIFSSlotCounter(acIndex) - elapsedTimeAC(acIndex);
            nextInvokeTimeAC(acIndex) = edcaMAC.AIFSSlotCounter(acIndex);
            elapsedTimeAC(acIndex) = 0;
        else
            elapsedTimeAC(acIndex) = elapsedTimeAC(acIndex) - edcaMAC.AIFSSlotCounter(acIndex);
            edcaMAC.AIFSSlotCounter(acIndex) = 0;
        end
        
        if (edcaMAC.AIFSSlotCounter(acIndex) == 0) && (edcaMAC.BackoffCounter(acIndex) == 0)
            if (edcaMAC.ContendFromTx == false) && (sum(edcaMAC.EDCAQueues.TxQueueLengths(:, acIndex)) == 0)
                % If contend is triggered from Rx and queue length is 0
                % after AIFS, don't go for random backoff
                edcaMAC.BackoffCounter(acIndex) = 0;
            else
                % Select a random backoff between 0 and cw
                edcaMAC.BackoffCounter(acIndex) = randi([0, edcaMAC.CW(acIndex)])*edcaMAC.SlotTime;

                % Update counters
                edcaMAC.MACBackoffAC(acIndex) = edcaMAC.MACBackoffAC(acIndex) + edcaMAC.BackoffCounter(acIndex);
            end
        end
    end
    
    % AIFS slot counter is 0
    if (edcaMAC.AIFSSlotCounter(acIndex) == 0)
        if (edcaMAC.BackoffCounter(acIndex) ~= 0)
            if (edcaMAC.BackoffCounter(acIndex) > elapsedTimeAC(acIndex))
                % Decrement backoff counter
                edcaMAC.BackoffCounter(acIndex) = edcaMAC.BackoffCounter(acIndex) - elapsedTimeAC(acIndex);
                nextInvokeTimeAC(acIndex) = edcaMAC.BackoffCounter(acIndex);
            else
                edcaMAC.BackoffCounter(acIndex) = 0;
            end
        end
        
        if (edcaMAC.BackoffCounter(acIndex) == 0)
            edcaMAC.BackoffCompleted(acIndex) = true;
            % AC has queued frames to transmit
            if sum(edcaMAC.EDCAQueues.TxQueueLengths(:, acIndex))
                % High priority AC won the channel in the same time slot.
                % i.e. an internal collision occurred
                % Refer section - 10.22.2.2 in IEEE Std 802.11-2016
                if txopAC ~= -1
                    % Run scheduler to get the station that experienced
                    % internal collision
                    numStations = 1;
                    runScheduler(edcaMAC, numStations);
                    % Increment retry count
                    incrementRetryCount(edcaMAC);
                    % Update internal collision statistics
                    edcaMAC.MACInternalCollisionsAC(txopAC+1) = edcaMAC.MACInternalCollisionsAC(txopAC+1) + 1;
                end
                % Update the txop AC
                txopAC = acIndex - 1;
                % Assign owner AC
                edcaMAC.OwnerAC = txopAC;
            end
        end
    end
end

% Channel contention completed and no AC has frames to transmit
if (txopAC == -1) && ~any([edcaMAC.AIFSSlotCounter edcaMAC.BackoffCounter]) && all(edcaMAC.BackoffCompleted)
    % Move to IDLE state
    stateChange(edcaMAC, edcaMAC.IDLE_STATE);
    edcaMAC.NextInvokeTime = 0;
elseif (txopAC ~= -1) % One of the ACs got channel access
    % Move to SendingData state
    stateChange(edcaMAC, edcaMAC.SENDINGDATA_STATE);
    edcaMAC.NextInvokeTime = 0;
else % Contention still in progress
    if nnz(nextInvokeTimeAC)
        edcaMAC.NextInvokeTime = min(nextInvokeTimeAC(nextInvokeTimeAC ~= 0));
    else
        edcaMAC.NextInvokeTime = 0;
    end
end
end
