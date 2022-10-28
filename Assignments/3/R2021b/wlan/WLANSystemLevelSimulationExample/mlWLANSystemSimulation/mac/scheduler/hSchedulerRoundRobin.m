classdef hSchedulerRoundRobin < handle
%hSchedulerRoundRobin create round-robin scheduler object
%
%   obj = hSchedulerRoundRobin(NumStations) creates a round-robin
%   scheduler object, obj, for a multi-user network with number of stations
%   set to NumStations.
%
%   hSchedulerRoundRobin properties:
%   NumStations         - Number of stations in the network

%   Copyright 2021 The MathWorks, Inc.

properties (SetAccess = private)
    %NumStations Number of stations in the network
    %   NumStations is a scalar whose value represents number of stations
    %   in a multi-user network.
    NumStations (1, 1) {mustBeNumeric}
end

properties(Constant, Hidden)
    % In a 20MHz channel up to 9 users can be served in multi-user(MU)
    % transmission using OFDMA.
    MaxMUStations = 9;
    
    % IEEE 802.11 quality of service (QoS) defines application
    % data priorities by grouping them into 4 access categories.
    MaxACs = 4;
end

properties(Access = private)
    % Counter to track number of chances of transmission for each station
    NumServes
    
    % Stations with secondary AC data in transmission queues
    SecondaryACStations
    
    % Stations with secondary AC data in retry queues
    SecondaryACRetryStations
    
    % Structure containing ID's,AC's and RU indices of scheduled stations
    % ScheduleInfo.DstStationIDs   - Node IDs of scheduled stations
    % ScheduleInfo.ACs             - ACs of scheduled stations
    % ScheduleInfo.AllocationIndex - OFDMA allocation index
    % ScheduleInfo.RUIndices       - Resource unit indices for OFDMA transmission
    ScheduleInfo
    
    % Allocation index for OFDMA transmission
    AllocationIndices = [192 96 128 112 15 7 3 1 0];
end

methods(Access = private)
    
    function secondaryACs = secondaryACs(obj, retryFlag, txQueueLengths)
        % SecondaryACStations(...) Returns access categories of stations that does
        % not contain primary ac data.
        
        secondaryACs = zeros(hSchedulerRoundRobin.MaxMUStations, 1);
        switch retryFlag
            % Determines secondary access categories of normal transmission
            % stations when retryFlag is 0.
            case 0
                stationsList = obj.SecondaryACStations;
                % Determines secondary access categories of retry stations when
                % retryFlag is 1.
            case 1
                stationsList = obj.SecondaryACRetryStations;
        end
        
        if ~isempty(stationsList)
            for staIdx = 1:length(stationsList)
                % Find station IDs with secondary AC data
                ac = find(txQueueLengths(stationsList(staIdx), :), 1);
                % Secondary ACs with data for a given station
                secondaryACs (staIdx) = ac;
            end
            secondaryACs = nonzeros(secondaryACs);
        else
            secondaryACs = zeros(0, 1);
        end
    end
    
    function scheduleStations(obj, primaryAC, maxUsers, txQueueLengths, retryQueueLengths)
        % scheduleStations(...) Schedules destination stations
        
        % Bitmap to indicate status of scheduling of each station.
        scheduleFlags = zeros(obj.NumStations, 1);
        
        % Stations with non-zero transmission buffer lengths
        txBufferedStations = find(~all(txQueueLengths == 0, 2))';
        txBufferedACs = zeros(length(txBufferedStations), 1);
        
        % Get number of previous chances of transmission for above stations
        % and sort them.
        numServes = obj.NumServes(txBufferedStations);
        [sortedNumServes, sortedIndices] = sort(numServes);
        
        % Rearrange active stations according to ascending order of number
        % of chances of transmission.
        txBufferedStations = txBufferedStations(sortedIndices);
        
        % Find retry stations with primary AC data and set schedule flags
        % to 1.
        primaryACRetryStations = find(retryQueueLengths(:, primaryAC))';
        scheduleFlags(primaryACRetryStations) = 1;
        
        % Find stations with primary AC data in transmission queues that
        % doesn't have primary AC data for retry and set corresponding
        % schedule flags to 1.
        primaryACStations = find(txQueueLengths(:, primaryAC))';
        primaryACStations = primaryACStations(scheduleFlags(primaryACStations) == 0);
        scheduleFlags(primaryACStations) = 1;
        
        % Assign weights as -3 for stations with primary AC data in retry
        % queues and -2 for stations with primary AC data in transmission
        % queues and set their corresponding ACs as primary AC.
        sortedNumServes(ismember(txBufferedStations, primaryACRetryStations)) = -3;
        txBufferedACs(ismember(txBufferedStations, primaryACRetryStations)) = primaryAC;
        sortedNumServes(ismember(txBufferedStations, primaryACStations)) = -2;
        txBufferedACs(ismember(txBufferedStations, primaryACStations)) = primaryAC;
        
        acList = [1 2 3 4];
        % Get list of secondary ACs.
        acList(acList == primaryAC) = [];
        
        % Find stations with secondary AC data in retry queues and without
        % primary AC data both for normal transmission and retry.
        obj.SecondaryACRetryStations = find((sum(retryQueueLengths(:, acList), 2) ~= 0));
        obj.SecondaryACRetryStations = obj.SecondaryACRetryStations(scheduleFlags(obj.SecondaryACRetryStations) == 0);
        
        % Sort the list of stations with secondary AC data for retry
        % according to number of serves and set their schedule flags to 1.
        [~, sortedRetrySecondaryACIndices] = sort(obj.NumServes(obj.SecondaryACRetryStations));
        obj.SecondaryACRetryStations = obj.SecondaryACRetryStations(sortedRetrySecondaryACIndices);
        scheduleFlags(obj.SecondaryACRetryStations) = 1;
        
        % Assign weight as -1 to secondary AC retry stations and get their
        % corresponding secondary ACs.
        sortedNumServes(ismember(txBufferedStations, obj.SecondaryACRetryStations)) = -1;
        txBufferedACs(ismember(txBufferedStations, obj.SecondaryACRetryStations)) = ...
            secondaryACs(obj, 1, txQueueLengths);
        
        % Find stations with secondary AC data for normal transmission.
        obj.SecondaryACStations = txBufferedStations(scheduleFlags(txBufferedStations) == 0);
        
        % Sort the list of stations with secondary AC data for normal
        % transmission according to number of serves and get their
        % corresponding secondary ACs.
        [~, sortedSecondaryACIndices] = sort(obj.NumServes(obj.SecondaryACStations));
        obj.SecondaryACStations = obj.SecondaryACStations(sortedSecondaryACIndices);
        txBufferedACs(scheduleFlags(txBufferedStations) == 0) = ...
            secondaryACs(obj, 0, txQueueLengths);
        
        % Sort according to weights
        [~, tempSortedIndices] = sort(sortedNumServes);
        
        if length(txBufferedStations) >= maxUsers
            obj.ScheduleInfo.DstStationIDs(1:maxUsers) = ...
                txBufferedStations(tempSortedIndices(1:maxUsers));
            obj.ScheduleInfo.ACs(1:maxUsers) = txBufferedACs(tempSortedIndices(1:maxUsers));
        else
            obj.ScheduleInfo.DstStationIDs(1:length(txBufferedStations)) ...
                = txBufferedStations(tempSortedIndices);
            obj.ScheduleInfo.ACs(1:length(txBufferedStations)) = txBufferedACs(tempSortedIndices);
        end
        
        % Increment the number of chances of transmission of scheduled stations
        obj.NumServes(nonzeros(obj.ScheduleInfo.DstStationIDs)) = ...
            obj.NumServes(nonzeros(obj.ScheduleInfo.DstStationIDs)) + 1;
        
        % Get corresponding allocation index and assign RU indices.
        obj.ScheduleInfo.AllocationIndex = obj.AllocationIndices(nnz(obj.ScheduleInfo.DstStationIDs));
        obj.ScheduleInfo.RUIndices(1:nnz(obj.ScheduleInfo.DstStationIDs)) ...
            = 1:nnz(obj.ScheduleInfo.DstStationIDs);
    end
end


methods
    
    function obj = hSchedulerRoundRobin(NumStations)
        % Constructor to create scheduler object.
        obj.NumStations = NumStations;
        obj.ScheduleInfo = struct('DstStationIDs', zeros(hSchedulerRoundRobin.MaxMUStations, 1),...
            'ACs', zeros(hSchedulerRoundRobin.MaxMUStations, 1),...
            'AllocationIndex', 0, ...
            'RUIndices', zeros(hSchedulerRoundRobin.MaxMUStations, 1));
        
        % Initializing private properties
        obj.NumServes = zeros(obj.NumStations, 1);
    end
    
    function scheduleInfo = runScheduler(obj, primaryAC, maxUsers, ...
            txQueueLengths, retryQueueLengths)
        %runScheduler Schedules destination stations for OFDMA downlink
        %
        %   [SCHEDULEINFO, ALLOCATIONINDEX] = runScheduler(OBJ, PRIMARYAC,
        %   MAXUSERS, TXQUEUELENGTHS, RETRYQUEUELENGTHS) schedules
        %   destination stations.
        %
        %   SCHEDULEINFO is a structure with fields DSTSTATIONIDS, ACS and
        %   RUINDICES.
        %   DSTSTATIONIDS   - IDs of scheduled stations
        %   ACS             - Access Categories of scheduled stations
        %   ALLOCATIONINDEX - Allocation index for OFDMA transmission
        %   RUINDICES       - Resource unit indices for OFDMA transmission
        %
        %   PRIMARYAC is the primary access category of the transmission.
        %
        %   MAXUSERS is the maximum number of users in a multi-user
        %   transmission.
        %
        %   TXQUEUELENGTHS is an array of size M x 4 where M is the number
        %   of stations in the network and 4 is the maximum number of ACs.
        %   Each element represents the number of MSDU's buffered in
        %   transmission queue in a station in corresponding AC.
        %
        %   RETRYQUEUELENGTHS is the number of MSDUs buffered for retry.
        %
        %   RETRYQUEUELENGTHS is an array of size M x 4 where M is the
        %   number of stations in network and 4 is the maximum number of
        %   ACs. Each element represents the number of MSDU's buffered in
        %   re-transmission queue of corresponding station and AC
        
        % Initialize
        obj.ScheduleInfo.DstStationIDs = zeros(hSchedulerRoundRobin.MaxMUStations, 1);
        obj.ScheduleInfo.ACs = zeros(hSchedulerRoundRobin.MaxMUStations, 1);
        obj.ScheduleInfo.RUIndices = zeros(hSchedulerRoundRobin.MaxMUStations, 1);
        scheduleStations(obj, primaryAC, maxUsers, txQueueLengths, retryQueueLengths);
        scheduleInfo = obj.ScheduleInfo;
    end
end

end
