classdef (Abstract) hPHYTxInterface < handle
%hPHYTxInterface Define WLAN physical layer transmitter interface
%class
%   The class acts as a base class for all the WLAN physical layer
%   transmitters. It defines the interface to physical layer transmitter.
%   It declares the properties and methods to be used by higher layers to
%   interact with the phy transmitter.

%   Copyright 2021 The MathWorks, Inc.

% Public, tunable properties
properties
    %NodeID Node identifier
    %   Specify node identifier as an integer value representing the node.
    %   It is a unique identifier for the nodes in the network. The default
    %   value is 1.
    NodeID (1, 1) {mustBeInteger, mustBePositive} = 1;

    %NodePosition Node position
    %   Specify the position of node position as a row-vector of integer
    %   values representing the three-dimensional coordinate (x,y,z).
    NodePosition (1, 3) {mustBeNumeric, mustBeFinite} = [0 0 0];

    %IsNodeTypeAP Flag for node type
    %   Specify the type of node (AP/STA). Value true denotes AP & false
    %   denotes STA
    IsNodeTypeAP (1, 1) logical = false;

    %TxGain Signal transmission gain in dB
    %   Specify the Tx power as a scalar value. It specifies the signal
    %   transmission gain in dB. The default value is 1 dB.
    TxGain (1, 1) {mustBeNumeric, mustBeFinite} = 1.0;
end

% PHY transmitter statistics
properties (GetAccess = public, SetAccess = protected)
    % Number of waveforms transmitted
    PhyNumTransmissions = 0;
    
    % Number of transmissions when there are active transmissions in
    % overlapping basic service sets (BSS) and BSS coloring is enabled
    PhyNumTxWhileActiveOBSSTx = 0;

    % Number of bytes transmitted from PHY
    PhyTxBytes = 0;

    % Amount of time where PHY is transmitting
    PhyTxTime = 0;
end

methods (Abstract)
    %run Run physical layer transmit operations for a WLAN node
    %   run(OBJ, MACREQTOPHY, FRAMETOPHY) runs the following transmit
    %   operations
    %       * Handling the MAC requests
    %       * Transmitting the waveform
    %
    %   MACREQTOPHY is a structure containing the details of request from
    %   MAC layer. MAC request is valid only if the field 'IsEmpty' is
    %   false in this structure. The corresponding confirmation for the MAC
    %   request is indicated through the PHYConfirmIndication property.
    %
    %   FRAMETOPHY is a structure containing the frame metadata received
    %   from the MAC layer. When the field IsEmpty is false in this
    %   structure, the corresponding waveform transmission is indicated
    %   through the TransmitWaveform property.
    run(obj, macReqToPHY, frameToPHY)
end

methods (Static)
    function availableMetrics = getMetricsList()
    %getMetricsList Return the available metrics at PHY transmitter
    %
    %   AVAILABLEMETRICS is a cell array containing all the available
    %   metrics at the PHY transmitter

    availableMetrics  = {'PhyNumTransmissions', 'PhyTxBytes', 'PhyTxTime'};
    end
end
end
