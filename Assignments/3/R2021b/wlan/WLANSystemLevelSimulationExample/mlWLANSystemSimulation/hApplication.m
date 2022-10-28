classdef hApplication < handle
%hApplication Create an object to represent application layer
%   APP = hApplication(NUMNODES) creates an object for application layer,
%   where NUMNODES is the number of nodes in the network.
%
%   APP = hApplication(NUMNODES, Name, Value) creates an object for
%   application layer with the specified property Name set to the specified
%   Value. You can specify additional name-value pair arguments in any
%   order as (Name1, Value1, ..., NameN, ValueN).
%
%   hApplication properties:
%
%   NodeID          - Node identifier
%   FillPayload     - Fill packet payload bytes, instead of just length

%   Copyright 2021 The MathWorks, Inc.

properties
    %NodeID Node identifier
    NodeID = 0;

    %FillPayload Fill the payload bytes in the generated application packet
    %   Set this property to true to fill payload in application packet
    FillPayload = true;
end

properties (Constant)
    %MaxPacketLength Maximum number of bytes for the application data
    MaxPacketLength = 2304;
end

properties(Access = private)
    %Applications Context of the applications added to the application
    %layer
    % This is a column cell vector where each cell is a structure with the
    % following fields:
    %   App             - Handle object for application traffic pattern
    %                     such as networkTrafficOnOff, networkTrafficFTP,
    %                     networkTrafficVoIP, networkTrafficVideoConference
    %   TimeLeft        - Time left for the generation of next packet from
    %                     the associated traffic pattern object
    %   DestinationID   - Destination node identifier of the application
    %   PriorityID      - Traffic priority identifier
    Applications = cell(1, 1);

    %ApplicationsCount Count of applications already added
    ApplicationsCount = 0;

    %NextInvokeTime Next invoke time for application packet generation
    %operation
    NextInvokeTime = 0;

    % Maximum interfaces
    MaxInterfaces = 3;
end

% Statistics
properties
    % Vector of size 4-by-N, where N is the maximum number of interfaces.
    % Each element contains total number of packets, transmitted from all
    % the applications tied to an interface. Each row corresponds to a
    % priority identifier.
    AppTxAC;

    % Vector of size 1-by-N, where N is the maximum number of interfaces.
    % Each element contains total number of packets overflowed at MAC, from
    % all the applications tied to an interface.
    AppTxOverflow;

    % Vector of size 4-by-N, where N is the maximum number of interfaces.
    % Each element contains total number of packets, received from all the
    % applications tied to an interface. Each row corresponds to a priority
    % identifier.
    AppRxAC;

    % Vector of size 1-by-N, where N is the maximum number of interfaces.
    % Each element contains total number of bytes, transmitted from all the
    % applications tied to an interface.
    AppTxBytes;

    % Vector of size 1-by-N, where N is the maximum number of interfaces.
    % Each element contains total number of bytes received at application
    % layer, from all the applications tied to an interface.
    AppRxBytes;

    % Vector of size 1-by-N, where N is the maximum number of interfaces.
    % Each element contains average packet latency at application layer,
    % for all the applications tied to an interface.
    AppAvgPacketLatency;

    % Vector of size 4-by-N, where N is the maximum number of interfaces.
    % Each element contains average packet latency at application layer for
    % all the applications tied to an interface. Each row corresponds to a
    % priority identifier.
    AppAvgPacketLatencyAC;

    % Vector of size M-by-N, where M is the maximum number of nodes and N
    % is the maximum number of interfaces. Each element contains number of
    % packets sent to MAC layer per a destination from all the applications
    % tied to an interface. Each element in a row corresponds to a
    % destination node.
    AppTxPerDestination;
end

properties(Constant)
    ApplicationPacket = struct('PacketLength', 0, ... % in octets
        'PriorityID', 0, ... % Identifier for the data used in MAC layer
        'DestinationID', 0, ... % Final destination ID
        'Timestamp', 0, ... % Packet generation time stamp at origin
        'Data', zeros(hApplication.MaxPacketLength, 1, 'uint8'));
end

methods
    function obj = hApplication(numNodes, varargin)
        % Name-value pairs
        for idx = 1:2:numel(varargin)
            obj.(varargin{idx}) = varargin{idx+1};
        end

        % Initialize APP statistics
        [obj.AppTxBytes, obj.AppTxOverflow, obj.AppRxBytes, obj.AppAvgPacketLatency] = deal(zeros(1,obj.MaxInterfaces));
        [obj.AppTxAC, obj.AppRxAC, obj.AppAvgPacketLatencyAC] = deal(zeros(4, obj.MaxInterfaces));
        obj.AppTxPerDestination = zeros(numNodes, obj.MaxInterfaces);
    end

    function nextInvokeTime = runApplication(obj, elapsedTime, pushData)
    %runApplication Generate application packet and returns the next invoke
    %time
    %
    %   NEXTINVOKETIME = runApplication(OBJ, ELAPSEDTIME, PUSHDATA)
    %   generates application packet and calculates the time to generate
    %   the next packet, if time elapsed since last call is sufficient to
    %   generate a packet. Otherwise, returns balance wait time remaining
    %   for generating the packet.
    %
    %   NEXTINVOKETIME is the next event time (in microseconds) after which
    %   this method must be invoked again.
    %
    %   ELAPSEDTIME - Time completed since last run (in microseconds)
    %
    %   PUSHDATA - A function handle for pumping data to the lower layer

        % Application installed
        if obj.ApplicationsCount > 0
            minNextInvokeTime = inf;
            if elapsedTime < obj.NextInvokeTime
                % Not yet ready to generate the next packet
                for idx=1:obj.ApplicationsCount
                    obj.Applications{idx}.TimeLeft = obj.Applications{idx}.TimeLeft - elapsedTime;
                    if obj.Applications{idx}.TimeLeft < minNextInvokeTime
                        minNextInvokeTime = obj.Applications{idx}.TimeLeft;
                    end
                end
                obj.NextInvokeTime = minNextInvokeTime;
            else
                % Ready to generate the next packet
                for idx=1:obj.ApplicationsCount
                    obj.Applications{idx}.TimeLeft = obj.Applications{idx}.TimeLeft - elapsedTime;
                    if obj.Applications{idx}.TimeLeft <= 0
                        % Generate packet from the application traffic pattern

                        % Method invocation using dot notation is done for MATLAB
                        % compiler support
                        [dt, packetSize, packetData] = obj.Applications{idx}.App.generate;
                        % Generate packet for transmission
                        packet = obj.ApplicationPacket;
                        packet.Data = packetData;
                        packet.PacketLength = packetSize;
                        packet.PriorityID = obj.Applications{idx}.PriorityID;
                        packet.DestinationID = obj.Applications{idx}.DestinationID;
                        obj.Applications{idx}.TimeLeft = obj.Applications{idx}.TimeLeft + ceil(dt*1e3); % In microseconds

                        % Push the data to the lower layer
                        pushData(packet);
                    end

                    % Next invoke time
                    if obj.Applications{idx}.TimeLeft < minNextInvokeTime
                        minNextInvokeTime = obj.Applications{idx}.TimeLeft;
                    end
                end
                obj.NextInvokeTime = minNextInvokeTime;
            end
            nextInvokeTime = obj.NextInvokeTime;

        % No applications installed
        else
            nextInvokeTime = -1;
        end
    end

    function addApplication(obj, app, metaData)
    %addApplication Add application traffic model to the node
    %
    %   addApplication(OBJ, APP, METADATA) adds the application traffic
    %   model for the node.
    %
    %   APP is a handle object that generates the application
    %   traffic. It should be one of networkTrafficOnOff or
    %   networkTrafficVoIP or networkTrafficFTP
    %
    %   METADATA is a structure and contains following fields.
    %   DestinationNode - Destination node id
    %   AccessCategory - Access category

        obj.ApplicationsCount = obj.ApplicationsCount + 1;
        appIdx = obj.ApplicationsCount;

        if obj.FillPayload % Generate packet with payload
            app.GeneratePacket = true;
        end
        obj.Applications{appIdx}.App = app;
        obj.Applications{appIdx}.TimeLeft = 0;
        obj.Applications{appIdx}.DestinationID = metaData.DestinationNode;
        obj.Applications{appIdx}.PriorityID = metaData.AccessCategory;
    end

    function receivePacket(obj, packet, freqID)
        % receivePacket Update statistics for the packets received from network
        obj.AppRxAC(packet.PriorityID+1, freqID) = obj.AppRxAC(packet.PriorityID+1, freqID) + 1;
        obj.AppRxBytes(freqID) = obj.AppRxBytes(freqID) + packet.PacketLength;
    end
end

methods(Static)
    function availableMetrics = getMetricsList(~)
    %getMetricsList Return the available metrics in application
    %
    %   AVAILABLEMETRICS is a cell array containing all the available
    %   metrics in the application layer

        availableMetrics = {'AppTxAC', 'AppTxBytes', 'AppRxAC', 'AppRxBytes', ...
            'AppTxOverflow', 'AppAvgPacketLatency', 'AppAvgPacketLatencyAC'};
    end
end
end
