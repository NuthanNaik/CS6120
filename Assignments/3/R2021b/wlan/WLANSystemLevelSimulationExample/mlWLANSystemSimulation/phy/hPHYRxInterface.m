classdef (Abstract) hPHYRxInterface < handle
%hPHYRxInterface Define WLAN physical layer Receiver interface
%class
%   The class acts as a base class for all the physical layer types. It
%   defines the interface to physical layer at Receiving side. It
%   declares the properties and methods to be used by higher layers to
%   interact with the physical layer.

%   Copyright 2021 The MathWorks, Inc.

% Public, tunable properties
properties
    %NodeID Node identifier of the receiving WLAN node
    %   Specify the node ID as a scalar integer value greater than 0.
    %   The default value is 1.
    NodeID (1, 1) {mustBeInteger, mustBePositive} = 1;

    %NumberOfNodes Number of nodes from which signal might come
    %   Specify the number of nodes as a scalar positive integer value.
    NumberOfNodes (1, 1) {mustBeInteger, mustBePositive} = 10;

    %EDThreshold Energy detection threshold in dBm
    %   Specify the ED threshold as a scalar negative value. It is used
    %   as a threshold for the received signal power in order to start
    %   decoding the signal and indicate CCABUSY to MAC layer. The
    %   default value is -82 dBm.
    EDThreshold (1, 1) {mustBeNumeric, mustBeFinite} = -82;

    %RxGain receiver gain in dB
    %   Specify the receiver gain as a scalar double value. It is used in
    %   applying the receiver gain on the power of the received WLAN
    %   signal. The default value is 0 dB.
    RxGain (1, 1) {mustBeNumeric, mustBeFinite} = 0;
end

% PHY receiver statistics
properties (GetAccess = public, SetAccess = protected)
    % Number of PHY energy detections less than ED threshold
    EnergyDetectionsLessThanED = 0;

    % Number of PHY Rx triggers while previous Rx is in progress
    RxTriggersWhilePrevRxIsInProgress = 0;

    % Number of PHY Rx triggers while Tx is in progress
    RxTriggersWhileTxInProgress = 0;

    % Total number of preamble failures
    PhyPreambleDecodeFailures = 0;

    % Number of PHY header decode failures
    PhyHeaderDecodeFailures = 0;

    % Number of waveforms received
    PhyRx = 0;

    % Number of bytes received to PHY
    PhyRxBytes = 0;

    % Number of waveforms dropped
    PhyRxDrop = 0;

    % Number of inter-BSS frames
    PhyNumInterFrames = 0;

    % Number of inter-BSS frames dropped
    PhyNumInterFrameDrops = 0;

    % Number of intra-BSS frames
    PhyNumIntraFrames = 0;

    % Number of PHY energy detections greater than OBSS PD threshold
    EnergyDetectionGreaterThanOBSSPD = 0;

    % Total duration of interference experienced while another reception is
    % in progress
    TotalRxInterferenceTime = 0;

    % Total number of multi user PPDU destined to others
    MUPPDUsDestinedToOthers = 0;
end

properties (Access = protected)
    % Energy detection threshold in watts
    EDThresoldInWatts;
end

methods
    % Set ED Threshold
    function set.EDThreshold(obj, value)
        obj.EDThreshold = value;
        convertEnergyDBMToWatts(obj, value);
    end
end

methods (Static)
    function availableMetrics = getMetricsList()
    %getMetricsList Return the available metrics at PHY receiver
    %
    %   AVAILABLEMETRICS is a cell array containing all the available
    %   metrics at the PHY receiver

    availableMetrics  = {'EnergyDetectionsLessThanED', 'TotalRxInterferenceTime', 'RxTriggersWhilePrevRxIsInProgress', ...
        'RxTriggersWhileTxInProgress', 'PhyPreambleDecodeFailures', 'PhyHeaderDecodeFailures', 'PhyRx', 'PhyRxDrop', ...
        'PhyRxBytes'};
    end
end

methods (Abstract)
    %run physical layer receive operations for a WLAN node and returns the
    %next invoke time, indication to MAC, and decoded data bits along with
    %the decoded data length
    %
    %   [NEXTINVOKETIME, INDICATIONTOMAC, FRAMETOMAC] = run(OBJ,
    %   ELAPSEDTIME, WLANRXSIGNAL) receives and processes the waveform
    %
    %   NEXTINVOKETIME is the next event time, when this method must be
    %   invoked again.
    %
    %   INDICATIONTOMAC is an output structure to be passed to MAC layer
    %   with the Rx indication (CCAIdle/CCABusy/RxStart/RxEnd/RxErr). This
    %   output structure is valid only when its property IsEmpty is set to
    %   false.
    %
    %   FRAMETOMAC is an output structure to be passed to MAC layer. This
    %   output structure is valid only when its property IsEmpty is set to
    %   false. The type of this structure corresponds to EmptyFrame
    %   property of this object.
    %
    %   ELAPSEDTIME is the time elapsed since the previous call to this.
    %
    %   WLANSIGNAL is an input structure which contains the WLAN
    %   signal received from the channel. This is a valid signal when
    %   the property IsEmpty is set to false in the structure.
    [nextInvokeTime, indicationToMAC, frameToMAC] = run(obj, elapsedTime, wlanSignal)

    %setPHYMode Handle the PHY mode set request from the MAC layer
    %
    %   setPHYMode(OBJ, PHYMODE) handles the PHY mode set request from
    %   the MAC layer.
    %
    %   PHYMODE is an input structure from MAC layer to configure the
    %   PHY Rx mode.
    setPHYMode(obj, phyMode)
end

methods (Access = private)
    function convertEnergyDBMToWatts(obj, value)
        %convertEnergyDBMToWatts Convert ED threshold value from dBm to
        %watts
        obj.EDThresoldInWatts = power(10.0, (value - 30)/ 10.0);
    end
end
end
