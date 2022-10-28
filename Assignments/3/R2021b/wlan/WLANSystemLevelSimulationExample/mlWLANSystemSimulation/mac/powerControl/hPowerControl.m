classdef hPowerControl < handle
%hPowerControl Base class for transmission power control algorithms
%   This is the base class for implementing any power control algorithm
%   and defines the interface to be supported.
%
%   hPowerControl methods:
%
%   getTxPower - Get required power to transmit a frame to destination station
%
%   hPowerControl properties:
%
%   ControlInfo -  Structure containing information required to select Tx
%                  power
    
%   Copyright 2021 The MathWorks, Inc.

properties
    %ControlInfo Structure containing information required to select Tx
    %power
    %   This structure contains information required for power control
    %   algorithm to select transmission power. The MAC layer must fill the
    %   information required for all the supported power control algorithms
    %   before calling the getTxPower method. This structure can be
    %   extended to include other properties for custom algorithms. The
    %   control info fields are:
    %       MCSIndex    - MCS index used to transmit frame
    %       Bandwidth   - Channel bandwidth
    ControlInfo = struct('MCSIndex', 0, 'Bandwidth', 20);
end

methods
    % Constructor method
    function obj = hPowerControl(varargin)
        % Name-value pair check
        coder.internal.errorIf((mod(nargin, 2)~=0), 'wlan:ConfigBase:InvalidPVPairs');
        
        for i = 1:2:nargin
            obj.(varargin{i}) = varargin{i+1};
        end
    end
end

methods (Abstract)
    txPower = getTxPower(obj, controlInfo)
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
    %   power control algorithm to select transmission power. The MAC layer
    %   must fill the information required for all the supported power
    %   control algorithms before calling the getTxPower method. This
    %   structure can be extended to include other properties for custom
    %   algorithms. The control info fields are:
    %       MCSIndex    - MCS index used to transmit frame
    %       Bandwidth   - Channel bandwidth
end
end