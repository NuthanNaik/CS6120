classdef hWirelessNetworkSimulator < handle
    %hWirelessNetworkSimulator Create an object to simulate wireless
    %network
    %
    %   SIMULATOR = hWirelessNetworkSimulator(NODES) creates an object to
    %   simulate wireless network.
    %   This class implements functionality to,
    %       1. Simulate a wireless network for the given simulation time
    %       2. Schedule or cancel events to process during the simulation
    %
    %   NODES Specify nodes as a cell array of wireless node objects.
    %
    %   hWirelessNetworkSimulator methods:
    %
    %   run                - Run the simulation
    %   scheduleEvent      - Schedule an event to process at specified
    %                        simulation time
    %   scheduleEventAfter - Schedule an event to process after specified
    %                        time from the current simulation time
    %   cancelEvent        - Cancel scheduled event
    %   addNodes           - Add nodes to the simulation
    %   currentTime        - Get current simulation time

    %   Copyright 2021 The MathWorks, Inc.

    properties (SetAccess = private)
        %Nodes List (cell array) of configured nodes in the network
        Nodes
    end

    properties (Access = private)
        %Events List of events queued for future processing
        Events

        %EventsInvokeTimes List of times, in microseconds, corresponding
        %to list of the event in 'Events' for processing
        EventsInvokeTimes

        %NodesNextInvokeTimes List of next invoke time for nodes in
        %network
        NodesNextInvokeTimes

        %TimeAdvanceEvents List of events queued for processing, when
        %there is time advance in the simulation
        TimeAdvanceEvents

        %CurrentTime Current simulation time, in microseconds
        CurrentTime = 0;

        %TimeElapsedFromLastCall Time elapsed, in microseconds, between
        %previous and the current call to node
        TimeElapsedFromLastCall

        %NumNodes Number of nodes in the simulation
        NumNodes

        %EventCounter Counter for assigning unique identifier for the
        %scheduled event
        EventCounter = 0;

        %CallbackInput Input structure to callback function
        CallbackInput = struct('UserData', [], 'EventID', 0);
    end

    methods
        % Constructor
        function obj = hWirelessNetworkSimulator(nodes)
            obj.Nodes = nodes;
            obj.NumNodes = numel(nodes);
            obj.NodesNextInvokeTimes = zeros(1, obj.NumNodes);
            obj.TimeElapsedFromLastCall = zeros(1, obj.NumNodes);
        end

        function currentTime = currentTime(obj)
            %currentTime(OBJ) Get current simulation time, in milliseconds
            %
            %   OBJ Object of type hWirelessNetworkSimulator.

            currentTime = obj.CurrentTime/1e3;
        end

        function addNodes(obj, nodes)
            %addNodes(OBJ, NODES) Add nodes to the simulation
            %
            %   addNodes(NODES) Add nodes to the simulation. You can add
            %   nodes before the start of simulation, and during the
            %   simulation.
            %
            %   OBJ Object of type hWirelessNetworkSimulator.
            %
            %   NODES Specify nodes as a cell array of wireless node
            %   objects.

            obj.Nodes = [obj.Nodes nodes];
            numNodes = numel(nodes);
            obj.NodesNextInvokeTimes = [obj.NodesNextInvokeTimes zeros(1, numNodes)];
            obj.TimeElapsedFromLastCall = [obj.TimeElapsedFromLastCall zeros(1, numNodes)];
            obj.NumNodes = numel(obj.Nodes);
        end

        function eventIdentifier = scheduleEventAfter(obj, callbackFcn, userData, callAfter, varargin)
            %scheduleEventAfter Schedule an event to process after
            %specified time from the current simulation time
            %
            %   EVENTIDENTIFIER = scheduleEventAfter(OBJ, CALLBACKFCN,
            %   USERDATA, CALLAFTER) Schedule an event in the
            %   simulation. The event is added to scheduled events list,
            %   and is processed after specified time during the
            %   simulation.
            %
            %   CALLBACKFCN Function handle, associated with the event.
            %
            %   USERDATA User data to be passed to the callback function
            %   (CALLBACKFCN) associated with the event. If multiple
            %   parameters are to be passed as inputs to the callback
            %   function, use a structure or a cell array.
            %
            %   CALLAFTER Time to process the event from current simulation
            %   time, in milliseconds.
            %
            %   EVENTIDENTIFIER This value is an integer, indicating the
            %   unique identifier for the scheduled event. This value can
            %   be used to cancel the scheduled event.
            %
            %   EVENTIDENTIFIER = scheduleEventAfter(OBJ, CALLBACKFCN,
            %   USERDATA, CALLAFTER, PERIODICITY) Schedule a periodic
            %   event in the simulation. The event is added to scheduled
            %   events list, and is processed after specified time during
            %   the simulation with specified periodicity.
            %
            %   PERIODICITY Periodicity of the scheduled event, in
            %   milliseconds.
            %
            %   1. To schedule a periodic event i.e., an event called
            %   periodically in the simulation, set periodicity value with
            %   some time value.
            %
            %   2. To schedule a time advance event i.e. an event called
            %   when there was time advance in the simulation, set
            %   periodicity value as 0.

            % Schedule event
            callAt = round((obj.CurrentTime/1e3), 3) + callAfter;
            if nargin == 5
                eventIdentifier = scheduleEvent(obj, callbackFcn, userData, callAt, varargin{1});
            else
                eventIdentifier = scheduleEvent(obj, callbackFcn, userData, callAt);
            end
        end

        function eventIdentifier = scheduleEvent(obj, callbackFcn, userData, callAt, varargin)
            %scheduleEvent Schedule an event to process at specified
            %simulation time
            %
            %   EVENTIDENTIFIER = scheduleEvent(OBJ, CALLBACKFCN,
            %   USERDATA, CALLAT) Schedule an event in the simulation.
            %   The event is added to scheduled events list, and is
            %   processed at specified absolute time during the simulation.
            %
            %   CALLBACKFCN Function handle, associated with the event.
            %
            %   USERDATA User data to be passed to the callback function
            %   (CALLBACKFCN) associated with the event. If multiple
            %   parameters are to be passed as inputs to the callback
            %   function, use a structure or a cell array.
            %
            %   CALLAT Absolute simulation time to process the event, in
            %   milliseconds.
            %
            %   EVENTIDENTIFIER This value is an integer, indicating the
            %   unique identifier for the scheduled event. This value can
            %   be used to cancel the scheduled event.
            %
            %   EVENTIDENTIFIER = scheduleEvent(OBJ, CALLBACKFCN,
            %   USERDATA, CALLAT, PERIODICITY) Schedule a periodic event
            %   in the simulation. The event is added to scheduled events
            %   list, and is processed at specified absolute time during
            %   the simulation with specified periodicity.
            %
            %   PERIODICITY Periodicity of the scheduled event, in
            %   milliseconds.
            %
            %   1. To schedule a periodic event i.e. an event called
            %   periodically in the simulation, set periodicity value with
            %   some time value.
            %
            %   2. To schedule a time advance event i.e. an event called
            %   when there was time advance in the simulation, set
            %   periodicity value as 0.

            % Create event
            event.CallbackFcn = callbackFcn;
            event.UserData = userData;
            obj.EventCounter = obj.EventCounter + 1;
            event.EventIdentifier = obj.EventCounter;
            eventIdentifier = event.EventIdentifier;

            % One-time event (no periodicity)
            if nargin == 4
                event.CallbackPeriodicity = Inf;
            else
                event.CallbackPeriodicity = varargin{1}*1e3; % Convert to microseconds
            end

            % Add event to events queue
            if event.CallbackPeriodicity == 0
                % Add a time advance event to the events list
                obj.TimeAdvanceEvents = [obj.TimeAdvanceEvents event];
            else
                % Add periodic or one-time event to the events list
                addEventAt(obj, event, callAt*1e3); % Convert to microseconds
            end
            
            % Sort event in order of time
            sortEvents(obj);
        end

        function cancelEvent(obj, eventIdentifier)
            %cancelEvent Cancel scheduled event
            %
            %   cancelEvent(OBJ, EVENTIDENTIFIER) Cancel the scheduled
            %   events associated with the event identifier
            %   (EVENTIDENTIFIER).
            %
            %   EVENTIDENTIFIER This value is an integer, indicating the
            %   unique identifier for the scheduled event.

            % Cancel periodic or one-time event
            for eventIdx = 1:numel(obj.Events)
                if obj.Events(eventIdx).EventIdentifier == eventIdentifier
                    obj.Events(eventIdx) = [];
                    obj.EventsInvokeTimes(eventIdx) = [];
                    return
                end
            end

            % Cancel time advance event
            for eventIdx = 1:numel(obj.TimeAdvanceEvents)
                if obj.TimeAdvanceEvents(eventIdx).EventIdentifier == eventIdentifier
                    obj.TimeAdvanceEvents(eventIdx) = [];
                    return
                end
            end
        end

        function run(obj, simulationTime)
            %run Run the simulation
            %
            %   run(OBJ, SIMULATIONTIME) Runs the simulation for all the
            %   specified nodes with associated events, for the specified
            %   simulation time.
            %
            %   OBJ Object of type hWirelessNetworkSimulator.
            %
            %   SIMULATIONTIME Simulation time in milliseconds.

            % Initialize simulation parameters
            timeAdvance = 0;
            sortEvents(obj);
            % Convert simulation time to microseconds, as all the layers
            % inside node operates in microseconds granularity.
            simulationTime = simulationTime*1e3;

            % Run simulator
            while(obj.CurrentTime < simulationTime)
                % Run all nodes
                if timeAdvance == 0
                    for nodeIdx = 1:obj.NumNodes
                        obj.NodesNextInvokeTimes(nodeIdx) = runNode(obj.Nodes{nodeIdx}, obj.TimeElapsedFromLastCall(nodeIdx));
                        obj.TimeElapsedFromLastCall(nodeIdx) = 0;
                    end
                else % Run nodes which are required to run at current time
                    for nodeIdx = 1:obj.NumNodes
                        % Update next invoke time
                        if obj.NodesNextInvokeTimes(nodeIdx) > 0
                            obj.NodesNextInvokeTimes(nodeIdx) = obj.NodesNextInvokeTimes(nodeIdx) - timeAdvance;
                        end
                        % Call node if next invoke time is 0
                        if obj.NodesNextInvokeTimes(nodeIdx) == 0
                            obj.NodesNextInvokeTimes(nodeIdx) = runNode(obj.Nodes{nodeIdx}, timeAdvance + obj.TimeElapsedFromLastCall(nodeIdx));
                            obj.TimeElapsedFromLastCall(nodeIdx) = 0;
                        else
                            obj.TimeElapsedFromLastCall(nodeIdx) = obj.TimeElapsedFromLastCall(nodeIdx) + timeAdvance;
                        end
                    end
                end

                % Distribute the transmitted packets (if any)
                packetDistributed = distributePackets(obj, obj.Nodes);

                % Process events scheduled at current time
                processEvents(obj, timeAdvance);
                
                % Calculate invoke time for next event
                timeAdvance = nextInvokeTime(obj, packetDistributed);

                % Advance the simulation time to the next event
                obj.CurrentTime = obj.CurrentTime + timeAdvance;
            end
        end
    end

    methods(Access = private)
        % Sort events in time order
        function sortEvents(obj)
            [obj.EventsInvokeTimes, sIdx] = sort(obj.EventsInvokeTimes);
            obj.Events = obj.Events(sIdx);
        end

        % Invoke current event
        function invokeEvent(obj, event)
            if isempty(event.UserData)
                event.CallbackFcn();
            else
                callbackInput = obj.CallbackInput;
                callbackInput.UserData = event.UserData;
                callbackInput.EventID = event.EventIdentifier;
                event.CallbackFcn(callbackInput);
            end
        end

        % Add current event to list
        function addEventAt(obj, event, callAt)
            obj.Events = [obj.Events event];
            obj.EventsInvokeTimes = [obj.EventsInvokeTimes callAt];
        end

        % Calculate time, in microseconds, for advancing the simulation to
        % next event
        function dt = nextInvokeTime(obj, packetDistributed)
            % Call all nodes when packet is distributed
            if packetDistributed
                dt = 0;
            else
                % Get minimum time from next invoke times of nodes and events
                nextNodeDt = min(obj.NodesNextInvokeTimes(obj.NodesNextInvokeTimes ~= -1));
                if ~isempty(obj.EventsInvokeTimes)
                    nextEventTimes = obj.EventsInvokeTimes(obj.EventsInvokeTimes ~= obj.CurrentTime);
                    nextEventDt = nextEventTimes(1) - obj.CurrentTime;
                    dt = min(nextEventDt, nextNodeDt);
                else
                    dt = nextNodeDt;
                end
            end
        end

        % Process events scheduled at current time. If the event is
        % periodic, update next invocation time for the events with
        % specified periodicity. Otherwise, remove the event from event
        % list.
        function processEvents(obj, timeAdvance)
            % Process all time advance events
            if timeAdvance > 0
                for eventIdx = 1:numel(obj.TimeAdvanceEvents)
                    invokeEvent(obj, obj.TimeAdvanceEvents(eventIdx));
                end
            end
            
            % Process periodic or one-time events
            numEvents = numel(obj.Events);
            for eventIdx = 1:numEvents
                % As events are sorted in order of time, process the first
                % event at current time
                currentEventIdx = 1;
                if obj.EventsInvokeTimes(currentEventIdx) == obj.CurrentTime
                    % Process current event
                    currentEvent = obj.Events(currentEventIdx);
                    invokeEvent(obj, currentEvent);
                    % Update next invocation time for the current periodic
                    % event
                    if currentEvent.CallbackPeriodicity ~= inf
                        callAt = obj.CurrentTime + currentEvent.CallbackPeriodicity;
                        obj.EventsInvokeTimes(currentEventIdx) = callAt;        
                        % Sort event in order of time
                        sortEvents(obj);
                    else % Remove current one-time event from the list of events
                        obj.Events(currentEventIdx) = [];
                        obj.EventsInvokeTimes(currentEventIdx) = [];
                    end
                else % Ignore the rest of events
                    break
                end
            end
        end

        % Distribute the transmitted packets.
        function txFlag = distributePackets(obj, nodes)
            %distributePackets Distribute the transmitting data from the
            %nodes into the receiving buffers of all the nodes
            %
            %   TXFLAG = distributePackets(OBJ, NODES) distributes the
            %   transmitting data from the nodes, NODES, into the receiving
            %   buffers of all the nodes and return, TXFLAG, to indicate if
            %   there is any transmission in the network
            %
            %   TXFLAG indicates if there is any transmission in the network
            %
            %   NODES Specify nodes as a cell array of wireless node
            %   objects.

            % Reset the transmission flag to specify that the channel is free
            txFlag = false;

            % Get the data from all the nodes to be transmitted
            for nodeIdx = 1:obj.NumNodes
                txNode = nodes{nodeIdx};
                for interfaceIdx = 1:txNode.NumInterfaces
                    % Node has data to transmit
                    if (txNode.TxBuffer{interfaceIdx, 2}.Metadata.SubframeCount ~= 0)
                        txFrequency = txNode.TxBuffer{interfaceIdx, 1};
                        txData = txNode.TxBuffer{interfaceIdx, 2};
                        txFlag = true;
                        for rxIdx = 1:obj.NumNodes
                            % Copy Tx data into the receiving buffers of other nodes
                            if rxIdx ~= nodeIdx
                                rxNode = nodes{rxIdx};
                                pushChannelData(rxNode, txNode.Position, txFrequency, txData);
                            end
                        end
                    end
                end
            end
        end
    end
end
