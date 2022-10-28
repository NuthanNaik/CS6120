classdef hChannel
%hChannel Create an object for WLAN channel
%   CHANNEL = hChannel creates an object for WLAN channel
%
%   CHANNEL = hChannel(Name, Value) creates an object for WLAN channel
%   with the specified property Name set to the specified Value. You can
%   specify additional name-value pair arguments in any order as (Name1,
%   Value1, ..., NameN, ValueN).
%
%   hChannel methods:
%
%   run - Run the channel models
%
%   hChannel properties:
%
%   ReceiverID              - Receiver node identifier
%   Frequency               - Operating frequency (GHz)
%   ReceiverPosition        - Receiver node position
%   ApplyFreeSpacePathloss  - Flag to enable free space pathloss
%   ApplyCustomPathlossModel- Flag to enable custom pathloss
%   PathlossFn              - Function handle to the path loss function
%   Abstracted              - Flag to specify the type of PHY(abstracted or full)

%   Copyright 2021 The MathWorks, Inc.

properties
    %ReceiverID Receiver node identifier
    %   Specify the receiver node identifier.
    ReceiverID = 0;

    % Frequency Operating frequency (GHz)
    Frequency = 5.18;

    %ApplyCustomPathlossModel Flag to enable custom pathloss model
    %   Set this property to true to apply a custom pathloss model. The
    %   Model used is implemented using the property PathlossFn. The
    %   default is false.
    ApplyCustomPathlossModel = false;

    %PathlossFn Function handle for custom pathloss model
    %   Specify a function handle to a custom path loss model:
    %      PL = PathlossFn(SourceID,ReceiverID,Frequency)
    %         PL is the returned pathloss in dB (positive)
    %         SourceID is the transmitting node identifier
    %         ReceiverID is the receiving node identifier
    %         Frequency is the carrier frequency in GHz
    %   This property is applicable when ApplyCustomPathlossModel is true.
    PathlossFn;

    %ApplyFreeSpacePathloss Flag to enable free space pathloss
    %   Set this property to true to apply free space pathloss. This
    %   property is applicable when ApplyCustomPathlossModel is false.
    ApplyFreeSpacePathloss = true;

    %ReceiverPosition Receiver node position
    %   Specify this property as a row vector with 3 elements. This
    %   property is applicable when ApplyFreeSpacePathloss is true.
    ReceiverPosition = [0 0 0];

    %Abstracted Flag to specify the type of PHY(abstracted or full)
    %   Specify this property as true if abstracted phy is used, otherwise
    %   set false. The default value is true.
    Abstracted = true;
end

methods
    function obj = hChannel(varargin)
        % Name-value pairs
        for idx = 1:2:nargin
            obj.(varargin{idx}) = varargin{idx+1};
        end
    end

    function wlanSignal = run(obj, wlanSignal)
    %run Run the channel models
    %   WLANSIGNAL = run(OBJ, WLANSIGNAL) applies the configured
    %   channel impairments on the given WLAN signal
    %
    %   WLANSIGNAL is a structure with at least these properties, in
    %   addition to other properties:
    %       SourceNodePosition  - Source node position specified as a
    %                             row vector with 3 integers
    %       SourceID            - Source node identifier specified as
    %                             an integer
    %       SignalPower         - Transmit signal power in dBm


        if obj.ApplyCustomPathlossModel
            % Calculate free space path loss (in dB)
            pathLoss = obj.PathlossFn(wlanSignal.Metadata.SourceID,obj.ReceiverID,obj.Frequency);
            % Apply pathLoss on the signal power of the waveform
            wlanSignal.Metadata.SignalPower = wlanSignal.Metadata.SignalPower - pathLoss;
        elseif obj.ApplyFreeSpacePathloss
            % Calculate distance between sender and receiver in meters
            distance = norm(wlanSignal.Metadata.SourcePosition - obj.ReceiverPosition);
            % Apply free space path loss
            lambda = physconst('LightSpeed')/(obj.Frequency*1e9);
            % Calculate free space path loss (in dB)
            pathLoss = fspl(distance, lambda);
            % Apply pathLoss on the signal power of the waveform
            wlanSignal.Metadata.SignalPower = wlanSignal.Metadata.SignalPower - pathLoss;
        end

        if ~obj.Abstracted
            if (obj.ApplyCustomPathlossModel ||  obj.ApplyFreeSpacePathloss)
                % Modify the IQ samples such that it will contains the pathLoss effect
                scale = 10.^(-pathLoss/20);
                [numSamples, ~] = size(wlanSignal.Waveform);
                wlanSignal.Waveform(1:numSamples, :) = (wlanSignal.Waveform(1:numSamples, :)) * scale;
            end
        end
    end
end
end