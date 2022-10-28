classdef hMACQueueManagement < handle
%hMACQueueManagement Create a WLAN MAC queue management object
%
%   OBJ = hMACQueueManagement(NUMNODES, MAXQUEUELENGTH, ...
%   MAXSUBFRAMESCOUNT) creates a WLAN MAC queue management object, OBJ, for
%   number of nodes NUMNODES with a maximum queue length of MAXQUEUELENGTH
%   and a maximum A-MPDU subframe count of MAXSUBFRAMESCOUNT.
%
%   hMACQueueManagement properties:
%   NumNodes            - Number of nodes in the network
%   MaxQueueLength      - Maximum size of a queue
%   MaxSubframesCount   - Maximum subframes present in an A-MPDU
%   TxQueueLengths      - Number of MSDUs buffered for transmission
%   RetryFlags          - Retransmission flags for dequeued frames
%   RetryQueueLengths   - Number of MSDUs in retransmission queue
%   MSDULengths         - Length of each MSDU buffered for transmission

%   Copyright 2021 The MathWorks, Inc.

properties(SetAccess = private, GetAccess = public)
    %NumNodes Number of nodes in the network
    % NumNodes is a scalar representing number of nodes in the network.
    NumNodes (1, 1) {mustBeNumeric}
    
    %MaxQueueLength Maximum size of a queue
    % MaxQueueLength is a scalar representing maximum number of MSDUs that
    % can be stored in a queue.
    MaxQueueLength (1, 1) {mustBeNumeric}
    
    %MaxSubframesCount Maximum number of subframes in an A-MPDU
    % MaxSubframesCount is a scalar representing maximum number of
    % subframes that can be present in an A-MPDU
    MaxSubframesCount  (1, 1) {mustBeNumeric}
    
    %TxQueueLengths Number of MSDUs buffered for transmission
    % TxQueueLengths is an array of size M x N where M is the number of
    % nodes in the network and N is the maximum number of ACs. Each element
    % represents number of MSDU's present in transmission queue in a
    % node in corresponding AC.
    TxQueueLengths
    
    %RetryFlags Retransmission flags for dequeued frames
    % RetryFlags is an array of size M x N where M is the number of
    % nodes in the network and N is the maximum number of ACs. Each
    % element is of type boolean where true indicates that MSDU's are
    % dequeued from retry queue and false indicates that MSDU's are
    % dequeued from transmission queue.
    RetryFlags
    
    %RetryQueueLengths Number of MSDUs in retransmission queue
    % RetryQueueLengths is an array of size M x N where M is the number of
    % nodes in network and N is the maximum number of ACs. Each element
    % represents number of MSDU's in retry queue of corresponding node
    % and AC that are not discarded.
    RetryQueueLengths
    
    %MSDULengths Length of each MSDU buffered for transmission
    % MSDULengths is an array of size M x N x O where M is the number of
    % nodes in network, N is the maximum number of ACs and O is the
    % maximum queue length. Each element represents length of MSDU present
    % in the queue of corresponding node and corresponding AC.
    MSDULengths
end

properties(Constant, Hidden)
    % Maximum number of users in a multi-user(MU) transmission using OFDMA.
    % In 20MHz OFDMA transmission max possible users are 9.
    MaxMUStations = 9;
    
    % Maximum number of access categories (AC). IEEE 802.11 quality of
    % service (QoS) defines application data priorities by grouping them
    % into 4 ACs.
    MaxACs = 4;
end

properties(Access = private)
    %Packet Application packet
    % Packet is a scalar structure containing the MSDU information
    Packet
    
    %WriteIndices Write indices of each queue
    % WriteIndices is an array of size M x N where M is number of
    % nodes in the network and N is the maximum number of ACs.
    WriteIndices
    
    %PacketToAggregate MSDUs information
    % PacketToAggregate is a scalar structure containing information of the
    % MSDUs to generate PSDU
    PacketToAggregate
    
    %RetryMSDUIndices MSDU indices that are waiting for retransmission
    % RetryMSDUIndices is an array of size M x N x O where M is the maximum
    % number of nodes in network, N is the maximum number of ACs and O is
    % the maximum queue length. Non- zero elements represents the indices
    % that are not discarded from corresponding AC of a node.
    RetryMSDUIndices
    
    %FrameList dequeued MSDUs corresponding to given nodes
    % FrameList is a vector of structures with N elements. Where N is the
    % maximum number of users in an MU transmission. Each structure
    % contains MSDUs information to generate PSDU.
    FrameList
end

properties(Hidden)
    %RetryQueues Retransmission queues per node per AC
    % RetryQueues is an array of size M x N where M is number of nodes
    % in the network and N is the maximum number of ACs. Each element
    % represents a frame of corresponding AC dequeued from a node.
    RetryQueues
    
    %TxQueues Transmission queues per node per AC
    % TxQueues is an array of size M x N x O where M is the number
    % of nodes in network, N is the maximum number of ACs and O is the
    % maximum queue length. Each element represents an MSDU structure.
    TxQueues
    
    %ReadIndices Read indices of each queue
    % ReadIndices is an array of size M x N where M is number of nodes
    % in the network and N is the maximum number of ACs.
    ReadIndices
end

methods(Access = private)
    function numDequeued = dequeueRetryQ(obj, nodeID, ac, numMSDU, staIdx)
        % Dequeues required number of MSDUs from retry queue and returns number
        % of MSDUs dequeued.
        
        % Find the indices that are not discarded
        retryIndices = find(obj.RetryMSDUIndices(nodeID, ac, :));
        
        % Retry queue contains less number of MSDUs than to be dequeued
        if obj.RetryQueueLengths(nodeID, ac) < numMSDU
            numMSDU = obj.RetryQueueLengths(nodeID, ac);
        end
        
        for idx = 1:numMSDU
            obj.FrameList(staIdx).Timestamp(idx) = obj.RetryQueues(nodeID, ac).Timestamp(retryIndices(idx));
            obj.FrameList(staIdx).MSDULength(idx) = obj.RetryQueues(nodeID, ac).MSDULength(retryIndices(idx));
            obj.FrameList(staIdx).FourAddressFrame(idx) = obj.RetryQueues(nodeID, ac).FourAddressFrame(retryIndices(idx));
            obj.FrameList(staIdx).MeshSourceAddress(idx, :) = obj.RetryQueues(nodeID, ac).MeshSourceAddress(retryIndices(idx), :);
            obj.FrameList(staIdx).MeshDestinationAddress(idx, :) = obj.RetryQueues(nodeID, ac).MeshDestinationAddress(retryIndices(idx), :);
            obj.FrameList(staIdx).MeshSequenceNumber(idx) = obj.RetryQueues(nodeID, ac).MeshSequenceNumber(retryIndices(idx));
            obj.FrameList(staIdx).Data(idx, :) = obj.RetryQueues(nodeID, ac).Data(retryIndices(idx), :);
        end
        % Set retry flag to true to indicate dequeue from retry queue
        obj.RetryFlags(nodeID, ac) = true;
        numDequeued = numMSDU;
    end
    
    function dequeuedMSDUInfo = dequeueTxQ(obj, nodeID, ac, numMSDU, staIdx, MSDUIdx)
        % Dequeues required number of MSDUs from transmission queue and inserts
        % them into FrameList at index corresponding to the staIdx and  MSDUIdx.
        
        dequeuedMSDUInfo = repmat(obj.Packet, obj.MaxSubframesCount, 1);
        for idx = MSDUIdx:MSDUIdx + numMSDU - 1
            
            readIndex = obj.ReadIndices(nodeID, ac);
            data = obj.TxQueues(nodeID, ac, readIndex).Data;
            obj.FrameList(staIdx).Data(idx,1:length(data)) = data';
            obj.FrameList(staIdx).Timestamp(idx) = obj.TxQueues(nodeID, ac, readIndex).Timestamp;
            obj.FrameList(staIdx).MSDULength(idx) = obj.TxQueues(nodeID, ac, readIndex).MSDULength;
            obj.FrameList(staIdx).FourAddressFrame(idx) = ~strcmpi(obj.TxQueues(nodeID, ac, readIndex).NextHopAddress, ...
                obj.TxQueues(nodeID, ac, readIndex).DestinationAddress);
            obj.FrameList(staIdx).MeshSourceAddress(idx, :) = obj.TxQueues(nodeID, ac, readIndex).SourceAddress;
            obj.FrameList(staIdx).MeshDestinationAddress(idx, :) = obj.TxQueues(nodeID, ac, readIndex).DestinationAddress;
            obj.FrameList(staIdx).MeshSequenceNumber(idx) = obj.TxQueues(nodeID, ac, readIndex).MeshSequenceNumber;
            obj.ReadIndices(nodeID, ac) = obj.ReadIndices(nodeID, ac) + 1;
            
            % Return dequeued MSDUs info
            dequeuedMSDUInfo(idx - MSDUIdx + 1).Timestamp = obj.TxQueues(nodeID, ac, readIndex).Timestamp;
            dequeuedMSDUInfo(idx - MSDUIdx + 1).MSDULength = obj.TxQueues(nodeID, ac, readIndex).MSDULength;
            dequeuedMSDUInfo(idx - MSDUIdx + 1).FourAddressFrame = ~strcmpi(obj.TxQueues(nodeID, ac, readIndex).NextHopAddress, ...
                obj.TxQueues(nodeID, ac, readIndex).DestinationAddress);
            dequeuedMSDUInfo(idx - MSDUIdx + 1).MeshSourceAddress = obj.TxQueues(nodeID, ac, readIndex).SourceAddress;
            dequeuedMSDUInfo(idx - MSDUIdx + 1).MeshDestinationAddress = obj.TxQueues(nodeID, ac, readIndex).DestinationAddress;
            dequeuedMSDUInfo(idx - MSDUIdx + 1).MeshSequenceNumber = obj.TxQueues(nodeID, ac, readIndex).MeshSequenceNumber;
            dequeuedMSDUInfo(idx - MSDUIdx + 1).Data = obj.TxQueues(nodeID, ac, readIndex).Data;
            
            % Read index must be reset to 1 after reaching
            % maximum queue length.
            if obj.ReadIndices(nodeID, ac) > obj.MaxQueueLength
                obj.ReadIndices(nodeID, ac) = 1;
            end
        end
    end
    
    function enqueueRetryQ(obj, nodeID, ac, frame)
        % Inserts frame containing 'numMSDU' number of packets from
        % transmission queue into retry queue and increments retry queue length
        
        obj.RetryQueues(nodeID, ac) = frame;
        obj.RetryQueueLengths(nodeID, ac) = obj.RetryQueueLengths(nodeID, ac) + frame.MSDUCount;
    end
    
    function fillCommonMSDUInfo(obj, nodeID, ac, staIdx, retryFlag)
        % Fills common MSDU information like DestinationMACAddress, AC and DestinationID in
        % FrameList at index set to staIdx.
        
        switch retryFlag
            case 1
                packetToAggregate = obj.RetryQueues(nodeID, ac);
                obj.FrameList(staIdx).AC = packetToAggregate.AC;
                obj.FrameList(staIdx).DestinationID = packetToAggregate.DestinationID;
                obj.FrameList(staIdx).DestinationMACAddress = packetToAggregate.DestinationMACAddress;
            case 0
                readIdx = obj.ReadIndices(nodeID, ac);
                packet = obj.TxQueues(nodeID, ac, readIdx);
                obj.FrameList(staIdx).AC = packet.AC;
                obj.FrameList(staIdx).DestinationID = packet.NextHopID;
                obj.FrameList(staIdx).DestinationMACAddress = packet.NextHopAddress;
        end
    end
end
methods
    
    function obj = hMACQueueManagement(NumNodes, MaxQueueLength, MaxSubframesCount)
        % Constructor to create a queue object for nodes in the network
        
        obj.NumNodes = NumNodes;
        obj.MaxQueueLength = MaxQueueLength;
        obj.MaxSubframesCount = MaxSubframesCount;
        
        % Initialize transmission queue information
        obj.Packet = struct('MSDULength', 0, ...
            'AC', 0, ... % Access category range [0 3]. Add 1 for indexing.
            'NextHopID', 0, ... % Immediate destination node ID
            'NextHopAddress', '000000000000', ... % MAC Frame RA. Corresponds to immediate destination node address
            'SourceAddress', '000000000000', ... % Original packet source
            'DestinationID', 0, ... % Final destination ID
            'DestinationAddress', '000000000000', ... % Final destination
            'Timestamp', 0, ... % Packet generation time stamp at origin
            'MeshSequenceNumber', 0, ... % Packet sequence number
            'Data', zeros(2304, 1, 'uint8'));
        obj.TxQueues = repmat(obj.Packet, NumNodes, hMACQueueManagement.MaxACs, MaxQueueLength);
        obj.TxQueueLengths = zeros(NumNodes, hMACQueueManagement.MaxACs);
        obj.ReadIndices = ones(NumNodes, hMACQueueManagement.MaxACs);
        obj.WriteIndices = ones(NumNodes, hMACQueueManagement.MaxACs);
        obj.MSDULengths = zeros(NumNodes, hMACQueueManagement.MaxACs, MaxQueueLength);
        
        % Initialize retry queue information
        obj.PacketToAggregate = struct('MSDUCount', 0, ...
            'MSDULength', zeros(MaxSubframesCount, 1),...
            'AC', 0, ...
            'DestinationID', 0,...
            'DestinationMACAddress', zeros(1,6),...
            'FourAddressFrame', false(MaxSubframesCount, 1), ...
            'MeshSourceAddress', repmat('000000000000', MaxSubframesCount, 1), ...
            'MeshDestinationAddress', repmat('000000000000', MaxSubframesCount, 1), ...
            'Timestamp', zeros(MaxSubframesCount, 1),...
            'MeshSequenceNumber', zeros(MaxSubframesCount, 1), ...
            'Data', zeros(MaxSubframesCount, 2304, 'uint8'));
        obj.RetryQueues = repmat(obj.PacketToAggregate, NumNodes, hMACQueueManagement.MaxACs);
        obj.RetryQueueLengths = zeros(NumNodes, hMACQueueManagement.MaxACs);
        obj.RetryFlags = false(NumNodes, hMACQueueManagement.MaxACs);
        obj.RetryMSDUIndices = zeros(NumNodes, hMACQueueManagement.MaxACs, MaxQueueLength);
    end
    
    function isSuccess = enqueue(obj, nodeID, ac, packet)
        %enqueue Inserts packet into queue
        %
        %   ISSUCCESS = enqueue(OBJ, NODEID, AC, PACKET) inserts packet in
        %   the queue maintained for a node in given AC.
        %
        %   ISSUCCESS is a logical value that indicates the status of enqueue.
        %   % 1 - Enqueue success
        %   % 0 - Enqueue fail
        %
        %   NODEID is the ID of the node into which packet must be
        %   enqueued.
        %
        %   AC is the access category of the packet.
        %
        %   PACKET is the MSDU to be enqueued.
        
        % Queue is full
        if obj.TxQueueLengths(nodeID, ac) == obj.MaxQueueLength
            isSuccess = false;
            
            % Insert packet into transmission queue and increment queue length.
            % Set corresponding MSDU lengths in MSDULengths array.
        else
            index = obj.WriteIndices(nodeID, ac);
            obj.TxQueues(nodeID, ac, index) = packet;
            obj.TxQueueLengths(nodeID, ac) = obj.TxQueueLengths(nodeID, ac) + 1;
            obj.MSDULengths(nodeID, ac, obj.TxQueueLengths(nodeID, ac)) = packet.MSDULength;
            
            obj.WriteIndices(nodeID, ac) = obj.WriteIndices(nodeID, ac) + 1;
            % Reset write index to 1 after reaching maximum queue length.
            if obj.WriteIndices(nodeID, ac) > obj.MaxQueueLength
                obj.WriteIndices(nodeID, ac) = 1;
            end
            
            isSuccess = true;
        end
    end
    
    function [txFrame, isSuccess] = dequeue(obj, nodeList, acList, numMSDU, numNodes)
        %dequeue Dequeues the required number of MSDUs
        %
        %   [TXFRAME, ISSUCCESS] = dequeue(OBJ, NODELIST, ACLIST,
        %   NUMMSDU, NUMSTATIOONS) dequeues MSDUs from either transmission
        %   or retry queues.
        %
        %   TXFRAME is the aggregate of frames from all dequeued nodes.
        %
        %   ISSUCCESS is a logical value that indicates the status of dequeue.
        %   % 1 - Dequeue success
        %   % 0 - Dequeue fail
        %
        %   NODELIST is an M x 1 array of node IDs from which packets must
        %   be dequeued, where M is the maximum number of users.
        %
        %   ACLIST is an M x 1 array of access categories corresponding to
        %   the node IDs from which packets must be dequeued, where M is
        %   the number of users.
        %
        %   NUMMSDU is an M x 1 array of required number of MSDUs
        %   corresponding to the node IDs from which packets must be
        %   dequeued, where M is the maximum number of users.
        %
        %   NUMNODES is the number of nodes for dequeue.
        
        isSuccess = false(hMACQueueManagement.MaxMUStations, 1);
        obj.FrameList = repmat(obj.PacketToAggregate, hMACQueueManagement.MaxMUStations, 1);
        
        % Index from which MSDU information should be updated in FrameList
        MSDUIdx = 1;
        
        for idx = 1:numNodes
            
            % Fill number of MSDUs to be dequeued
            obj.FrameList(idx).MSDUCount = numMSDU(idx);
            
            % Dequeue from retry queue if it is not empty
            if obj.RetryQueueLengths(nodeList(idx), acList(idx)) ~= 0
                
                
                % Fill MSDU fields that are in common and dequeue the MSDUs
                % from indices that are not already discarded.
                fillCommonMSDUInfo(obj,nodeList(idx), acList(idx), idx, 1);
                numDequeued = dequeueRetryQ(obj, nodeList(idx), acList(idx), numMSDU(idx), idx);
                
                remainingMSDU = numMSDU(idx) - numDequeued;
                % Dequeue from transmission queue if there are less number
                % of MSDUs than desired in retry queue.
                if remainingMSDU > 0
                    MSDUIdx = numMSDU(idx) - remainingMSDU + 1;
                    dequeuedMSDUInfo = dequeueTxQ(obj, nodeList(idx), acList(idx), remainingMSDU, idx, MSDUIdx);
                    
                    % Index the MSDUs that are dequeued from transmission
                    % queue.
                    nextRetryMSDUIdx = max(obj.RetryMSDUIndices(nodeList(idx), acList(idx), :)) + 1;
                    MSDUIndices = nextRetryMSDUIdx:nextRetryMSDUIdx + remainingMSDU - 1;
                    obj.RetryMSDUIndices(nodeList(idx), acList(idx),MSDUIndices) = MSDUIndices;
                    
                    % Insert these MSDUs into retry queue and increment
                    % retry queue length.
                    for index = 1:remainingMSDU
                        obj.RetryQueues(nodeList(idx), acList(idx)).Timestamp(MSDUIndices(index)) = ...
                            dequeuedMSDUInfo(index).Timestamp;
                        obj.RetryQueues(nodeList(idx), acList(idx)).MSDULength(MSDUIndices(index)) = ...
                            dequeuedMSDUInfo(index).MSDULength;
                        obj.RetryQueues(nodeList(idx), acList(idx)).FourAddressFrame(MSDUIndices(index)) = ...
                            dequeuedMSDUInfo(index).FourAddressFrame;
                        obj.RetryQueues(nodeList(idx), acList(idx)).MeshSourceAddress(MSDUIndices(index), :) = ...
                            dequeuedMSDUInfo(index).MeshSourceAddress;
                        obj.RetryQueues(nodeList(idx), acList(idx)).MeshDestinationAddress(MSDUIndices(index), :) = ...
                            dequeuedMSDUInfo(index).MeshDestinationAddress;
                        obj.RetryQueues(nodeList(idx), acList(idx)).MeshSequenceNumber(MSDUIndices(index)) = ...
                            dequeuedMSDUInfo(index).MeshSequenceNumber;
                        obj.RetryQueues(nodeList(idx), acList(idx)).Data(MSDUIndices(index), :) = ...
                            dequeuedMSDUInfo(index).Data;
                        obj.RetryQueueLengths(nodeList(idx), acList(idx)) = ...
                            obj.RetryQueueLengths(nodeList(idx), acList(idx)) + 1;
                    end
                end
                obj.RetryQueues(nodeList(idx), acList(idx)).MSDUCount = numMSDU(idx);
                isSuccess(idx) = true;
                
                % Dequeue packets from TxQueues of given node if retry
                % queue is empty
            elseif (obj.TxQueueLengths(nodeList(idx), acList(idx)) ~= 0)
                
                % Fill MSDU fields that are in common and dequeue the MSDUs
                % from transmission queue.
                fillCommonMSDUInfo(obj,nodeList(idx), acList(idx), idx, 0);
                dequeueTxQ(obj, nodeList(idx), acList(idx), numMSDU(idx), idx, MSDUIdx);
                
                % Insert the dequeued MSDUs into retry queue and
                % set Retryflag to false.
                enqueueRetryQ(obj, nodeList(idx), acList(idx), obj.FrameList(idx));
                
                % Index the packets in retry queue
                obj.RetryMSDUIndices(nodeList(idx), acList(idx),...
                    1:obj.RetryQueueLengths(nodeList(idx), acList(idx))) =...
                    (1:obj.RetryQueueLengths(nodeList(idx), acList(idx)))';
                
                obj.RetryFlags(nodeList(idx), acList(idx)) = false;
                obj.RetryQueues(nodeList(idx), acList(idx)).MSDUCount = numMSDU(idx);
                isSuccess(idx) = true;
                
                % No data in transmission and retry queues
            else
                isSuccess(idx) = false;
            end
            
        end
        
        % Aggregate frames from all dequeued nodes
        txFrame = obj.FrameList;
    end
    
    function discardedIndices = discardPackets(obj, nodeList, acList, MSDUIndices, numIndices, numNodes)
        %discardPackets Discard packets from transmission and retry queues
        %
        %   DISCARDEDINDICES = discardPackets(OBJ, NODELIST, ACLIST,
        %   MSDUINDICES, NUMINDICES, NUMNODES) discards packets.
        %
        %   DISCARDEDINDICES is an array of size N x M where N is the
        %   number of nodes in the network and M is the maximum subframe
        %   count. It contains the indices of discarded packets from all
        %   nodes.
        %
        %   NODELIST is an M x 1 array of node IDs from which packets
        %   must be discarded, where M is the maximum number of users.
        %
        %   ACLIST is an M x 1 array of access categories corresponding to
        %   the node IDs from which packets must be discarded, where M
        %   is the maximum number of users.
        %
        %   MSDUINDICES is an array of size M x N where M is the maximum
        %   subframe count and N is the maximum number of users. It
        %   contains the indices of packets to be discarded corresponding
        %   to node IDs.
        %
        %   NUMINDICES is an M x 1 array of number of indices of packets to
        %   be discarded corresponding to node IDs, where M is the
        %   maximum number of users.
        %
        %   NUMNODES is the number of nodes for discard.
        
        % Initialize
        discardedIndices = zeros(obj.MaxQueueLength, obj.NumNodes);
        
        for staIdx = 1:numNodes
            
            % Discard packets if retry queue is not empty.
            if obj.RetryQueueLengths(nodeList(staIdx), acList(staIdx)) ~= 0
                
                % Find indices that are not already discarded.
                retryMSDUIndices = obj.RetryMSDUIndices(nodeList(staIdx), acList(staIdx), :);
                
                for MSDUIdx = 1:numIndices(staIdx)
                    % Discard packet only if its index has not been
                    % discarded before
                    if any(retryMSDUIndices == MSDUIndices(MSDUIdx, staIdx))
                        % Indices of packets that are discarded are made 0
                        discardIdx = (retryMSDUIndices == MSDUIndices(MSDUIdx, staIdx));
                        obj.RetryMSDUIndices(nodeList(staIdx), acList(staIdx), discardIdx) = 0;
                        
                        % Decrement transmission queue length
                        obj.TxQueueLengths(nodeList(staIdx), acList(staIdx)) = ...
                            obj.TxQueueLengths(nodeList(staIdx), acList(staIdx)) - 1;
                        
                        % Decrement retry queue length
                        obj.RetryQueueLengths(nodeList(staIdx), acList(staIdx)) = ...
                            obj.RetryQueueLengths(nodeList(staIdx), acList(staIdx)) - 1;
                    end
                end
                
                % Indices that are discarded
                tempDiscardedIndices = retryMSDUIndices(ismember(retryMSDUIndices,  MSDUIndices(1:numIndices(staIdx), staIdx)));
                discardedIndices(1:length(tempDiscardedIndices),nodeList(staIdx)) = tempDiscardedIndices;
                
                % Update MSDULengths
                retryIndices = find(retryMSDUIndices);
                indexesToDiscard = ismember(retryIndices, tempDiscardedIndices);
                msduLengths = obj.MSDULengths(nodeList(staIdx), acList(staIdx), :);
                msduLengths(indexesToDiscard) = 0;
                notDiscardedMSDULengths = nonzeros(msduLengths);
                obj.MSDULengths(nodeList(staIdx), acList(staIdx), :) = [notDiscardedMSDULengths;...
                    zeros(obj.MaxQueueLength - length(notDiscardedMSDULengths), 1)];
            end
        end
    end
    
    function status = isFourAddressFrame(obj, nodeID, ac)
        %isFourAddressFrame Determine if the frame present in queues is
        %four address frame
        %
        %   STATUS = isFourAddressFrame(NODEID, AC) determines whether
        %   frame is four address frame or not.
        %
        %   STATUS is a logical value that indicates:
        %   % 1 - Four address frame
        %   % 0 - Three address frame
        %
        %   NODEID is a scalar value of node ID.
        %
        %   AC is a scalar value of access category corresponding to the
        %   node ID.
        
        if obj.RetryQueueLengths(nodeID, ac)
            retryIndices = find(obj.RetryMSDUIndices(nodeID, ac, :));
            status = obj.RetryQueues(nodeID, ac).FourAddressFrame(retryIndices(1));
        else
            readIndex = obj.ReadIndices(nodeID, ac);
            % FourAddressFrame is true when the next hop and the final
            % destination addresses are different
            status = ~strcmpi(obj.TxQueues(nodeID, ac, readIndex).NextHopAddress, ...
                obj.TxQueues(nodeID, ac, readIndex).DestinationAddress);
        end
    end
    
end
end
