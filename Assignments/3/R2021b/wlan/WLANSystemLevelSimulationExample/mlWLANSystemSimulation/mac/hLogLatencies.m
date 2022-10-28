function hLogLatencies(nodeID, ac, entryTs, clearTs)
%hLogLatencies Logs the given information of all frames exchanged in the
%network
%
%   This is an example helper function.
%
%   hLogLatencies(NODEID, AC, ENTRYTS, DISCARDTS) adds an entry in the
%   latency information table using the given inputs.
%
%   NODEID represents Node ID of the transmitter.
%
%   AC represents access category of the transmitted frame.
%
%   ENTRYTS is the timestamp at which the transmitted packet arrived to the
%   MAC from higher layers.
%
%   CLEARTS is the timestamp at which the packet is cleared from MAC
%   either after receiving acknowledgment or after completing maximum
%   retransmissions.

%   Copyright 2021 The MathWorks, Inc.

persistent latenciesInfo writeIdx maxIdx bufferSize

% Initialize buffer and write index
if isempty(latenciesInfo)
    writeIdx = 1;
    bufferSize = 10000;
    maxIdx = bufferSize;
    latenciesInfo = zeros(bufferSize, 4);
end

% At simulation end, hLogLatencies(...) is invoked with node ID of 0.
if nodeID == 0
    % Save the latencies information in 'macLatenciesLog.mat' as a table
    latenciesTable = array2table(latenciesInfo(1:writeIdx-1, :), ...
        'VariableNames', {'EntryTimestamp', 'NodeID', 'AC', 'ClearTimestamp'});
    save('macLatenciesLog.mat', 'latenciesTable');
else
    % Update the latencies information and write index
    latenciesInfo(writeIdx, :) = [entryTs, nodeID, ac, clearTs];
    writeIdx = writeIdx + 1;
    
    % Buffer is full
    if writeIdx > maxIdx
        % Increase the buffer size
        maxIdx = maxIdx + bufferSize;
        latenciesInfo = [latenciesInfo; zeros(bufferSize, 4)];
    end
end
end
