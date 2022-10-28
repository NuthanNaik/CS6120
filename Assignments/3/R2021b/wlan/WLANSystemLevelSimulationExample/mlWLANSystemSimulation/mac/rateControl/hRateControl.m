classdef hRateControl < handle
%hRateControl Base class for rate control algorithms
%   This is the base class for implementing any rate control algorithm and
%   defines the interface to be supported.
%
%   hRateControl methods:
%
%   getRate      - Get the MCS index for the destination station
%   updateStatus - Update the status of transmitted frame
%
%   hRateControl properties:
%
%   TxInfo       - Transmitting frame information structure
%   TxStatusInfo - Transmit status information structure
    
%   Copyright 2021 The MathWorks, Inc.

properties
    %TxInfo Transmitting frame information structure
    %   This structure contains the transmitting frame information required
    %   for rate control algorithm to select a data rate. The MAC layer
    %   must fill the information required for all the supported rate
    %   control algorithms before calling the getRate method. This
    %   structure can be extended to include other properties for custom
    %   algorithms. The Tx info fields are:
    %       FrameType   - Indicates the frame type as one of 'Data',
    %                     'Control', or 'Management'.
    %
    %       IsUnicast   - Indicates if the frame is unicast. If this flag
    %                     is set to false, the frame is considered to be a
    %                     groupcast frame.
    TxInfo = struct('FrameType', 'Data', 'IsUnicast', 0);
    
    %TxStatusInfo Transmit status information structure
    %   This structure contains the transmission status information
    %   required for rate control algorithms. The MAC layer must fill the
    %   information required for all the supported rate control algorithms
    %   before calling the updateStatus method. This structure can be
    %   extended to include other properties for custom algorithms. The
    %   status info fields are:
    %       MCS         - MCS index for which Tx status is being updated
    %
    %       FrameType   - Indicates type of the transmitted frame as
    %                     'Data', 'Control' or 'Management' for which
    %                     status is being updated
    %
    %       IsFail      - Indicates the success/failure status of a
    %                     transmission. To update an MPDU status, a logical
    %                     scalar value is used. To update an A-MPDU status,
    %                     a vector of logical values is used.
    %
    %       NumRetries  - Number of retries done for the transmission
    %
    %       RSSI        - Received signal strength of acknowledgment
    TxStatusInfo = struct('MCS', 0, 'FrameType', 'Data', 'IsFail', 0, 'NumRetries', 0, 'RSSI', -82);
end

methods
    % Constructor method
    function obj = hRateControl(varargin)
        % Name-value pair check
        coder.internal.errorIf((mod(nargin, 2)~=0), 'wlan:ConfigBase:InvalidPVPairs');
        
        for i = 1:2:nargin
            obj.(varargin{i}) = varargin{i+1};
        end
    end
end

methods (Abstract)
    init(obj)
    %init Perform initialization of rate control algorithm
    %   init(OBJ) Perform initialization of rate control algorithm after
    %   setting all the configuration.
    %
    %   OBJ is an object of type hRateControl.
    
    mcsIndex = getRate(obj, rxStationID, txInfo)
    %getRate Get the MCS index to transmit a frame to destination station
    %   MCSINDEX = getRate(OBJ, RXSTATIONID, TXINFO) returns the MCS index,
    %   MCSINDEX, for transmitting a frame to a station with the node ID
    %   indicated by RXSTATIONID.
    %
    %   MCSINDEX is a scalar positive integer specifying the MCS index used
    %   for the station, RXSTATIONID.
    %
    %   OBJ is an object of type hRateControl.
    %
    %   RXSTATIONID is a scalar positive integer specifying the receiving
    %   station ID.
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
    
    updateStatus(obj, rxStationID, txStatusInfo)
    %updateStatus Update the status of transmitted frame
    %   updateStatus(OBJ, RXSTATIONID, TXSTATUSINFO) updates the status
    %   for a recent transmission to station with node ID, RXSTATIONID.
    %
    %   OBJ is an object of type hRateControl.
    %
    %   RXSTATIONID is a scalar positive integer specifying the receiving
    %   station ID.
    %
    %   TXSTATUSINFO is a structure containing the transmit status
    %   information, required for rate control algorithms. The MAC layer
    %   must fill the information required for all the supported rate
    %   control algorithms before calling this method. This structure can
    %   be extended to include other properties for custom algorithms. The
    %   status info fields are:
    %       FrameType   - Indicates type of the transmitted frame as
    %                     'Data', 'Control' or 'Management' for which
    %                     status is being updated
    %       IsFail      - Indicates the success/failure status of a
    %                     transmission. To update an MPDU status, a logical
    %                     scalar value is used. To update an A-MPDU status,
    %                     a vector of logical values is used.
    %
    %       NumRetries  - Number of retries done for the transmission
    %
    %       RSSI        - Received signal strength of acknowledgment
end
end
