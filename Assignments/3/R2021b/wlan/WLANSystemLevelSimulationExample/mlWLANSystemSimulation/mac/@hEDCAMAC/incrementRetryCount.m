function incrementRetryCount(edcaMAC)
%incrementRetryCount Increments the retry counter for the access category
%(AC) that has channel access.

%   Copyright 2021 The MathWorks, Inc.

tx = edcaMAC.Tx;
txStationIDs = tx.TxStationIDs(edcaMAC.UserIndexSU);
acIdx = edcaMAC.OwnerAC+1;

if tx.IsShortFrame
    if (tx.ShortRetries(txStationIDs, acIdx) < (edcaMAC.MaxShortRetries-1)) % && ~edcaMAC.RateControlDiscard
        % Increment the retry counter
        tx.ShortRetries(txStationIDs, acIdx) = tx.ShortRetries(txStationIDs, acIdx) + 1;
        % Increase the contention window
        edcaMAC.CW(acIdx) = min(edcaMAC.CW(acIdx)*2+1, edcaMAC.CWMax(acIdx));

    else % Maximum retry limit is reached
        % Update statistics
        edcaMAC.MACTxFails = edcaMAC.MACTxFails + tx.TxWaitingForAck(txStationIDs, acIdx);

        % Reset retry counter
        resetRetryCount(edcaMAC);

        % Discard packets from MAC queue
        isSuccess = false(tx.TxWaitingForAck(txStationIDs, acIdx), 1);
        numRetries = edcaMAC.MaxShortRetries-1;
        discardTxPackets(edcaMAC, isSuccess, numRetries);
    end
else % Long retry
    if (tx.LongRetries(txStationIDs, acIdx) < (edcaMAC.MaxLongRetries-1)) % && ~edcaMAC.RateControlDiscard
        % Increment the retry counter
        tx.LongRetries(txStationIDs, acIdx) = tx.LongRetries(txStationIDs, acIdx) + 1;
        % Increase the contention window
        edcaMAC.CW(acIdx) = min(edcaMAC.CW(acIdx)*2+1, edcaMAC.CWMax(acIdx));

    else % Maximum retry limit is reached
        % Update statistics
        edcaMAC.MACTxFails = edcaMAC.MACTxFails + tx.TxWaitingForAck(txStationIDs, acIdx);

        % Reset retry counter
        resetRetryCount(edcaMAC);

        % Discard packets from MAC queue
        isSuccess = false(tx.TxWaitingForAck(txStationIDs, acIdx), 1);
        numRetries = edcaMAC.MaxLongRetries-1;
        discardTxPackets(edcaMAC, isSuccess, numRetries);
    end
end
