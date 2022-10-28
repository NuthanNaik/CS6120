classdef hPowerControlFixed < hPowerControl
%hPowerControlFixed Uses fixed transmit power with hPowerControl interface
%   OBJ = hPowerControlFixed creates a fixed transmit power selection object
%   that provides hPowerControl interface.
%
%   hPowerControlFixed methods:
%
%   getTxPower - Get required power to transmit a frame to destination station
%
%   hPowerControlFixed properties:
%
%   FixedPower - Fixed power to be used for signal transmission

%   Copyright 2021 The MathWorks, Inc.

properties
    %FixedPower Fixed power to be used for signal transmission
    %   FixedPower is a scalar specified in the range of [0 - 30]
    %   representing power in dBm to be used for signal transmission. The
    %   default value is 15.
    FixedPower (1, 1) {mustBeNumeric} = 15;
end
    
    methods
        % Constructor
        function obj = hPowerControlFixed(varargin)
            obj@hPowerControl(varargin{:});
        end
        
        function txPower = getTxPower(obj, ~)
        %getTxPower Get required power to transmit a frame to destination station
        %   TXPOWER = getTxPower(OBJ, CONTROLINFO) returns transmission power,
        %   TXPOWER required for transmitting a frame to destination station. 
        %
        %   TXPOWER is a scalar integer specifying the power in dBm required to
        %   transmit a frame.
        %
        %   OBJ is an object of type hPowerControl.
        %
        %   CONTROLINFO is a structure containing information required for
        %   power control algorithm to select transmission power. The MAC
        %   layer must fill the information required for all the supported
        %   power control algorithms before calling the getTxPower method.
        %   This structure can be extended to include other properties for
        %   custom algorithms. The control info fields are:
        %       MCSIndex    - MCS index used to transmit frame
        %       Bandwidth   - Channel bandwidth
        
            txPower = obj.FixedPower;
        end
        
        % Set fixed transmitter power in dBm
        function set.FixedPower(obj, value)
            validateattributes(value, {'numeric'}, {'real', 'scalar'}, mfilename, 'FixedPower');
            obj.FixedPower = value;
        end
    end
end

