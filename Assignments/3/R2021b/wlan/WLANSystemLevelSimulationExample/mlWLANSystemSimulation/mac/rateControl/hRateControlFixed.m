classdef hRateControlFixed < hRateControl
%hRateControlFixed Uses a fixed rate with hRateControl interface
%   OBJ = hRateControlFixed(NUMSTATIONS) creates a fixed rate selection
%   object that provides hRateControl interface.
%
%   NUMSTATIONS must be a scalar double value specifying the number of
%   stations in the network.
%
%   OBJ = hRateControlFixed(...,Name,Value) creates a fixed rate
%   selection object, OBJ, with the specified property Name
%   set to the specified Value. You can specify additional name-value pair
%   arguments in any order as (Name1,Value1, ...,NameN,ValueN).
%
%   hRateControlFixed methods:
%
%   getRate         - Get the MCS index for the destination station
%   updateStatus    - Update the status of transmitted frame
%
%   hRateControlFixed properties:
%
%	FixedMCS		 - Fixed MCS value to be used for transmission
%   TxFormat         - Physical layer frame format
%   NumTxChains      - Number of space time streams
    
%   Copyright 2021 The MathWorks, Inc.

properties
    %FixedMCS Fixed MCS value to be used for transmission
    %   FixedMCS is a scalar representing MCS value to be used for
    %   transmission. The default value is 4.
    FixedMCS (1, 1) {mustBeNumeric} = 4;
    
    %TxFormat Physical layer frame format
    %   TxFormat is the physical layer (PHY) frame format, specified as a
    %   constant value of class hFrameFormats. Specify this value as one of
    %   these: hFrameFormats.NonHT, hFrameFormats.HTMixed,
    %   hFrameFormats.VHT, hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU, or
    %   hFrameFormats.HE_MU. See <a
    %   href="matlab:help('hFrameFormats')">hFrameFormats</a> class for
    %   valid input values.
    TxFormat = hFrameFormats.NonHT;
    
    %NumTxChains Number of space time streams
    %   NumTxChains is a scalar representing number of multiple streams
    %   of data to transmit using the multiple-input multiple-output
    %   (MIMO) capability. The default value is 1.
    NumTxChains (1, 1) {mustBeNumeric} = 1;
end

properties(Access = private)
    % Number of stations in the network
    NumStations = 0;
end

methods
    % Constructor
    function obj = hRateControlFixed(numStations, varargin)
        % Validate the number of stations
        validateattributes(numStations, {'numeric'}, {'scalar', 'positive', ...
            'integer'}, mfilename, 'numStations');
        
        obj@hRateControl(varargin{:});
        
        % Update the number of stations
        obj.NumStations = numStations;
    end

    function init(~)
        % No action
    end
    
    function mcsIndex = getRate(obj, ~, txInfo)
    %getRate Get the MCS index to transmit a frame to destination station
    %   MCSINDEX = getRate(OBJ, TXINFO) returns the MCS index, MCSINDEX,
    %   for transmitting a frame.
    %
    %   MCSINDEX is a scalar positive integer specifying the MCS index.
    %
    %   OBJ is an object of type hRateControlFixed.
    %
    %   TXINFO is a structure containing the transmitting frame information
    %   required for rate control algorithm to select a data rate. The
    %   MAC layer must fill the information required for all the supported
    %   rate control algorithms before calling the getRate method. This
    %   structure can be extended to include other properties for custom
    %   algorithms. The Tx info fields are:
    %       FrameType   - Indicates the frame type as one of 'Data',
    %                     'Control', or 'Management'.
    %
    %       IsUnicast   - Indicates if the frame is unicast. If this flag
    %                     is set to false, the frame is considered to be a
    %                     groupcast frame.
    
        % Since wlanNonHTConfig accepts rates in the form of indices,
        % returning the index instead of actual data rate
        if strcmp(txInfo.FrameType, 'Data')
            mcsIndex = obj.FixedMCS;
        else
            mcsIndex = getControlRate(obj);
        end
    end
    
    function updateStatus(~, ~, ~)
        %updateStatus Update the status of transmitted frame
        
        % No action, as it is fixed-rate
    end
end

methods(Access = private)
    function mcsIndex = getControlRate(~)
        
        % Among all the control frames present in the frame exchange
        % sequence used in the simulation, only the rate with which RTS
        % must be transmitted is determined using getControlRate function.
        % Current simulation supports transmission of RTS at only 6 Mbps.
        
        % Hence return the MCS index corresponding to basic rate of 6 Mbps
        mcsIndex = 0;
        
    end
end
end
