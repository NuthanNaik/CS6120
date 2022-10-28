classdef hInterference < handle
%hInterference Create an object to model interference in the PHY
%receiver
%   OBJ = hInterference creates an object to model interference in the
%   PHY receiver
%
%   OBJ = hInterference(Name, Value) creates an object to model
%   interference in the PHY receiver, OBJ, with the specified property Name
%   set to the specified Value. You can specify additional name-value pair
%   arguments in any order as (Name1, Value1, ..., NameN, ValueN).
%
%   hInterference methods:
%
%   addSignal                - Add signal to the interference signal buffer
%   getResultantWaveform     - Return the resultant waveform after applying
%                              interference
%   updateSignalBuffer       - Update interference signal buffer and timer
%   getSignalBuffer          - Get active interference signals
%   getTotalSignalPower      - Get total power of interference signals
%   getTotalNumOfSignals     - Get number of active interference signals
%   getInterferenceTimer     - Get time at which the next interfering
%                              signal elapses
%   logInterferenceTime      - Log duration of interference experienced
%                              during signal reception
%   resetInterferenceLogTime - Reset timers for logging interference
%   getInterferenceTime      - Get interference time for current signal
%                              reception
%
%   hInterference properties:
%
%   BufferSize              - Interference signal buffer maximum size
%   SignalMetadataPrototype - Signal metadata prototype
%   ExtractMetadataFn       - Function handle to extract metadata from a
%                             signal

%   Copyright 2021 The MathWorks, Inc.

    properties
        % Maximum number of signals to be stored. The default value is 10.
        BufferSize {mustBeNonempty, mustBeInteger, mustBeNonnegative} = 10;

        % Prototype array or structure to store interference signal
        % metadata in addition to the source ID, receiver power and
        % duration. This allows metadata within a wlanSignal structure to
        % be used within the abstraction.
        SignalMetadataPrototype = [];

        % Function handle which consumes a wlanSignal structure and returns
        % a structure or array (specified by the SignalMetadataPrototype
        % property) containing metadata to store in the interference
        % buffer:
        %   SIGNALBUFFERELEMENT = ExtractMetadataFn(SIGNAL)
        % SIGNALBUFFERELEMENT must be a structure with the same fields as
        % SignalMetadataPrototype. This allows metadata within a wlanSignal
        % structure to be used within the abstraction.
        ExtractMetadataFn = @(x)[];
    end

    properties (SetAccess = private)
        % Timer (in microseconds) to update the tracked signal list.
        % Contains the smallest absolute (in simulation time timestamp)
        % time for a signal to be removed from the signal list.
        TimeUntilNextSignalUpdate  = -1;
    end

    properties (Access = private)
        % Array containing the details of all the signals being received
        % For each signal, it contains transmitting node ID, received
        % signal power in dBm, end time in absolute simulation time units,
        % and metadata defined by the SignalMetadataPrototype property.
        SignalBuffer

        % Array indicating if a buffer element is active or not at current
        % simulation time
        IsActive;

        % Array indicating the absolute time a buffer element will become
        % inactive
        SignalEndTime = [];

        % Number of signals present at a point of time
        NumSignals = 0;

        % Interference signals total power in watts
        TotalSignalPower = 0;

        % Total duration of interference accumulated over a signal of
        % interest
        InterferenceTime = 0;

        % End time of previous interference signal encountered during the
        % current signal of interest
        PrevInterferenceEndTime = 0;

        % Structure containing the default entry in the signal buffer
        DefaultSignalBufferElement
    end

    methods
        function obj =  hInterference(varargin)
        %hInterference Construct an instance of this class

            % Set name-value pairs
            for idx = 1:2:nargin
                obj.(varargin{idx}) = varargin{idx+1};
            end

            % Create default signal buffer entry
            obj.DefaultSignalBufferElement = struct('Waveform', complex([]), 'SourceID',-1, ...
                'RxPower',-1, ...
                'StartTime',-1, ...
                'EndTime',-1, ...
                'SampleRate',20e6, ...
                'Metadata', obj.SignalMetadataPrototype());

            % Allocate signal buffer
            obj.SignalBuffer = repmat(obj.DefaultSignalBufferElement,obj.BufferSize,1);

            % Initialize indices and other buffers
            obj.IsActive = false(1,obj.BufferSize);
            obj.SignalEndTime = -1*ones(1,obj.BufferSize);
        end
    end

    methods
        function addSignal(obj, wlanSignal)
        %addSignal Add signal to the interference signal buffer
        %
        %   addSignal(OBJ, WLANSIGNAL) adds a new interference signal to
        %   the signal buffer.
        %
        %   OBJ is instance of class hInterference.
        %
        %   WLANSIGNAL is the received WLAN waveform. It is represented
        %   as a structure holding the signal information.

            ppduDuration = wlanSignal.Metadata.Duration;

            sigPowerInWatts = power(10.0, (wlanSignal.Metadata.SignalPower - 30)/ 10.0); % Converting from dBm to watts

            % Update the total signal power (add current signal power to
            % the total power)
            obj.TotalSignalPower = obj.TotalSignalPower + sigPowerInWatts;
            obj.NumSignals = obj.NumSignals + 1;

            % Store the sender node ID, the corresponding Rx signal power,
            % the end time, and any metadata of the received waveform
            idx = find(~obj.IsActive,1); % Find an inactive buffer element
            assert(~isempty(idx), 'No empty signal buffer element when attempting to store a signal')
            obj.IsActive(idx) = true;
            obj.SignalEndTime(idx) = ppduDuration + wlanSignal.Metadata.StartTime; % Start time in signal metadata is current simulation time
            obj.SignalBuffer(idx).Waveform = wlanSignal.Waveform;
            obj.SignalBuffer(idx).SourceID = wlanSignal.Metadata.SourceID;
            obj.SignalBuffer(idx).RxPower = sigPowerInWatts;
            obj.SignalBuffer(idx).StartTime = wlanSignal.Metadata.StartTime;
            obj.SignalBuffer(idx).EndTime = obj.SignalEndTime(idx);
            obj.SignalBuffer(idx).SampleRate = wlanSignal.Metadata.Vector.ChannelBandwidth*1e6;
            obj.SignalBuffer(idx).Metadata = obj.ExtractMetadataFn(wlanSignal);

            % Update timer with the next minimum time (in simulation time
            % stamp) we need to update the signal buffer
            obj.TimeUntilNextSignalUpdate = min(obj.SignalEndTime(obj.IsActive));
        end

        function updateSignalBuffer(obj, currSimTime)
        %updateSignalBuffer Update interference signal buffer and timer
        %
        %   updateSignalBuffer(OBJ, CURRSIMTIME) updates the signal
        %   tracking buffer and timer. Elapsed signals are removed from the
        %   tracked signal list based on the current simulation time.
        %
        %   OBJ is instance of class hInterference.
        %
        %   CURRSIMTIME is the current simulation time

            % Remove the expired interferers from the signal set
            expiredSignalIdx = obj.IsActive & (obj.SignalEndTime<=currSimTime);

            if any(expiredSignalIdx)
                obj.TotalSignalPower = obj.TotalSignalPower - sum([obj.SignalBuffer(expiredSignalIdx).RxPower]);
                obj.NumSignals = obj.NumSignals - sum(expiredSignalIdx);
                obj.IsActive(expiredSignalIdx) = false;
                obj.SignalEndTime(expiredSignalIdx) = -1;
            end

            % Update timer with the next minimum time (in simulation time
            % stamp) we need to update the signal buffer
            if obj.NumSignals>0
                obj.TimeUntilNextSignalUpdate = min(obj.SignalEndTime(obj.IsActive));
            else
                obj.TimeUntilNextSignalUpdate = -1;
            end
        end

        function resultantWaveform = getResultantWaveform(obj, soi, soiStartTime, soiDuration, soiSampleRate)
        %getResultantWaveform Return the resultant waveform for the
        %reception duration
        %
        %   RESULTANTWAVEFORM = getResultantWaveform(OBJ, SOI, SOISTARTTIME,
        %   SOIDURATION, SOISAMPLERATE) Returns the resultant waveform
        %
        %   RESULTANTWAVEFORM - Resultant of all the waveforms in the
        %   SOIDURATION. It is a MxN matrix of complex values. Here 'M'
        %   represents number of IQ samples and 'N' represents the number
        %   of Rx antennas.
        %
        %   SOI Represents signal of interest waveform. It is a
        %   MxN matrix of complex values. Here 'M' represents number of
        %   IQ samples and 'N' represents the number of Rx antennas.
        %
        %   SOISTARTTIME  - Reception start time of receiver (in microseconds)
        %
        %   SOIDURATION   - Duration of reception (in microseconds). It
        %   is a scalar
        %
        %   SOISAMPLERATE - Sample rate of the signal of interest. It
        %   is a scalar

            % Reception end time (in microseconds)
            soiEndTime = soiStartTime + soiDuration;
            % Get indices of the overlapping signals
            waveformIndices = find(obj.IsActive,1);

            % Initialize the resultant waveform with the primary signal
            resultantWaveform = soi;
            [~, soiRxAntennas] = size(soi);

            % Get the resultant waveform from interfering waveforms
            if ~isempty(waveformIndices)
                % Calculate the number of samples per microsecond
                soiSamplesPermicrosec = soiSampleRate / 1e6;

                for idx = 1:length(waveformIndices)

                    % Fetch the interferer signal and its metadata
                    interferer = obj.SignalBuffer(waveformIndices(idx));
                    interfererStartTime = interferer.StartTime;
                    interfererEndTime = interferer.EndTime;
                    [~, interfererRxAntennas] = size(interferer.Waveform);
                    % Calculate the number of samples per microsecond
                    interfererSamplesPermicrosec = interferer.SampleRate / 1e6;

                    % Calculate the number of overlapping samples
                    overlapStartTime = max(soiStartTime, interfererStartTime);
                    overlapEndTime = min(soiEndTime, interfererEndTime);
                    numSOIOverlapSamples = floor((overlapEndTime - overlapStartTime) * soiSamplesPermicrosec);
                    numInterfererOverlapSamples = floor((overlapEndTime - overlapStartTime) * interfererSamplesPermicrosec);

                    % Calculate the overlapping start and end index of
                    % the soi waveform IQ samples
                    soiStartIdx = floor((overlapStartTime - soiStartTime) * soiSamplesPermicrosec) + 1;
                    soiEndIdx = soiStartIdx + numSOIOverlapSamples - 1;

                    % Calculate the overlapping start and end index of
                    % the interferer waveform IQ samples
                    iStartIdx = floor((overlapStartTime - interfererStartTime) * interfererSamplesPermicrosec) + 1;
                    iEndIdx = iStartIdx + numInterfererOverlapSamples - 1;

                    % Assume the number of antennas for SOI and interferer
                    % are the same. If we have different number of antennas
                    % for SOI and interferer we assume that the links are
                    % wired while adding SOI and interferer. For example if
                    % the SOI has 4 streams and the interferer has 2, then
                    % add the 2 interferer streams to the first 2 SOI
                    % streams and vice-versa.
                    numAntennas = min(soiRxAntennas, interfererRxAntennas);
                    interfererWaveform = zeros(numSOIOverlapSamples, numAntennas);

                    if numSOIOverlapSamples ~= numInterfererOverlapSamples
                        % Resample the waveform. Here the product
                        % numSOIOverlapSamples*numInterfererOverlapSamples should be less
                        % than 2^31 which is a limitation for resample
                        % function.
                        for antIdx = 1:numAntennas
                            interfererWaveform(1:numSOIOverlapSamples,antIdx) = ...
                                resample(interferer.Waveform(iStartIdx:iEndIdx, antIdx), ...
                                numSOIOverlapSamples, numInterfererOverlapSamples);
                        end
                    else
                        interfererWaveform = interferer.Waveform(iStartIdx:iEndIdx,:);
                    end

                    % Combine the IQ samples
                    resultantWaveform(soiStartIdx:soiEndIdx, 1:numAntennas) = ...
                        resultantWaveform(soiStartIdx:soiEndIdx, 1:numAntennas) + ...
                        interfererWaveform(:,1:numAntennas);
                end
            end
        end

        function logInterferenceTime(obj, soi, varargin)
        %logInterferenceTime Log duration of interference experienced
        %during signal reception
        %
        %   logInterferenceTime(OBJ, SOI) logs the duration of interference
        %   intersecting over the current signal reception where the
        %   interfering signal started before the start of signal of
        %   interest.
        %
        %   OBJ is instance of class hInterference.
        %
        %   SOI is a structure holding the information of the signal of
        %   interest.
        %
        %   logInterferenceTime(OBJ, SOI, INTERFERINGSIGNAL) logs the
        %   duration of interference intersecting over the current signal
        %   reception where the interfering signal started after the start
        %   of signal of interest.
        %
        %   INTERFERINGSIGNAL is a structure holding the information of the
        %   interfering signal.

            % Total duration for signal of interest
            signalOfInterestDuration = soi.Metadata.Duration;
            signalOfInterestEndTime = soi.Metadata.StartTime + signalOfInterestDuration;

            if isempty(varargin)
                % Check and log any active interference time with signal
                % strength < ED threshold, that started before the current
                % signal of interest reception

                interferenceEndTime = 0;

                % Find the longest interfering signal
                if obj.NumSignals>0
                    interferenceEndTime = max(obj.SignalEndTime(obj.IsActive));
                end

                if interferenceEndTime < signalOfInterestEndTime
                    %           <------------SoI------------>
                    %    <------Interference-1------>
                    interferenceTime = interferenceEndTime - soi.Metadata.StartTime;
                else
                    %           <------------SoI------------>
                    %    <----------Interference-1----------->
                    interferenceTime = signalOfInterestDuration;
                end

                obj.InterferenceTime = interferenceTime;
                obj.PrevInterferenceEndTime = interferenceEndTime;

            else % Interference that started after the signal of interest reception start
                interferingSignal = varargin{1};
                % Total duration for interfering signal
                interferingSignalDuration = interferingSignal.Metadata.Duration;
                % Remaining duration for signal of interest
                remainingSignalDuration = signalOfInterestDuration - (interferingSignal.Metadata.StartTime - soi.Metadata.StartTime);
                % End time of interfering signal
                interferenceEndTime = (interferingSignal.Metadata.StartTime + interferingSignalDuration);

                % Interference time
                if interferingSignalDuration < remainingSignalDuration
                    %      <------------------------SoI------------------------>
                    %           <----Interference-1---->
                    interferenceTime = interferingSignalDuration;
                else
                    %      <------------SoI------------>
                    %           <----------Interference-1---------->
                    interferenceTime = remainingSignalDuration;
                end

                if obj.PrevInterferenceEndTime
                    if (signalOfInterestEndTime > obj.PrevInterferenceEndTime)
                        % Handling > 1 interference signals
                        if interferingSignal.Metadata.StartTime > obj.PrevInterferenceEndTime
                            % <------------------------SoI------------------------>
                            %    <----Interference-1---->
                            %                               <----Interference-2---->
                            obj.InterferenceTime = obj.InterferenceTime + interferenceTime;
                            obj.PrevInterferenceEndTime = interferenceEndTime;
                        else
                            if interferenceEndTime > obj.PrevInterferenceEndTime
                                % <------------------------SoI------------------------>
                                %       <----Interference-1---->
                                %                   <----Interference-2---->
                                obj.InterferenceTime = obj.InterferenceTime + interferenceTime - ...
                                    (obj.PrevInterferenceEndTime - interferingSignal.Metadata.StartTime);
                                obj.PrevInterferenceEndTime = interferenceEndTime;
                            else
                                % <------------------------SoI------------------------>
                                %        <------------Interference-1------------>
                                %                <----Interference-2---->
    
                                % No change in interfering time
                            end
                        end
                    end
                else % First interfering signal
                    obj.InterferenceTime = interferenceTime;
                    obj.PrevInterferenceEndTime = interferenceEndTime;
                end
            end
        end

        function time = getInterferenceTime(obj)
        %getInterferenceTime Returns interference time for current signal
        %reception
        %
        %   TIME = getInterferenceTime(OBJ) returns the overall duration of
        %   interference experienced by the receiver over the current
        %   signal reception
        %
        %   TIME is the total interference time over the current signal in
        %   microseconds
        %
        %   OBJ is instance of class hInterference.

            time = obj.InterferenceTime;
        end

        function resetInterferenceLogTime(obj)
        %resetInterferenceLogTime Reset timers for logging interference
        %time on the next signal of interest

            obj.InterferenceTime = 0;
            obj.PrevInterferenceEndTime = 0;
        end

        function buffer = getSignalBuffer(obj)
        %getSignalBuffer Get active interference signals
        %
        %   getSignalBuffer(OBJ) returns a structure array containing
        %   active interference signals within the signal buffer. Call
        %   updateSignalBuffer() first to ensure the returned signals are
        %   up-to-date.

            buffer = obj.SignalBuffer(obj.IsActive);
        end

        function totalSignalPower = getTotalSignalPower(obj)
        %getTotalSignalPower Get total power of interference signals
        %
        %   getTotalSignalPower(OBJ) returns the total power of
        %   interference signals in Watts. Call updateSignalBuffer() first
        %   to ensure the returned signal power is up-to-date.

            totalSignalPower = obj.TotalSignalPower;
        end

        function numSignals = getTotalNumOfSignals(obj)
        %getTotalNumOfSignals Get number of active interference signals
        %
        %   getTotalNumOfSignals(OBJ) returns number of active interference
        %   signals. Call updateSignalBuffer() first to ensure the returned
        %   number of signals is up-to-date.
            numSignals = obj.NumSignals;
        end
    end
end