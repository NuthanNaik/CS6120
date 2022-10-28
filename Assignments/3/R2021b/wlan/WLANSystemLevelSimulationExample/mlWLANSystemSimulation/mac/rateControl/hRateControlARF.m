classdef hRateControlARF < hRateControl
    %hRateControlARF Auto rate fallback (ARF) algorithm
    %   CFG = hRateControlARF(NUMSTATIONS) creates an auto rate fallback
    %   (ARF) object. This object provides functionality for ARF algorithm.
    %
    %   NUMSTATIONS must be a scalar double value specifying the number of
    %   stations in the network.
    %
    %   CFG = hRateControlARF(...,Name,Value) creates an auto rate fallback
    %   (ARF) object, CFG, with the specified property Name set to the
    %   specified Value. You can specify additional name-value pair arguments
    %   in any order as (Name1,Value1, ...,NameN,ValueN).
    %
    %   hRateControlARF methods:
    %
    %   getRate         - Get the MCS index for the destination station
    %   updateStatus    - Update the status of transmitted frame
    %
    %   hRateControlARF properties:
    %
    %   SuccessThreshold  - Successful transmission threshold for rate increment
    %   FailureThreshold  - Failure transmission threshold for rate decrement
    %   TxFormat          - Physical layer frame format
    %   NumTxChains       - Number of space time streams
    %   Bandwidth         - Bandwidth of the channel (in MHz)
    
    %   Copyright 2021 The MathWorks, Inc.
    
    properties
        %SuccessThreshold Successful transmission threshold for rate increment
        % Number of successful transmissions after which rate is increased.
        %   Specify the value as a scalar integer. The default is 4.
        SuccessThreshold(1,1) {mustBeNumeric, mustBeInteger} = 4;
        
        %FailureThreshold Failure transmission threshold for rate decrement
        % Number of transmission failures after which rate is decreased
        %   Specify the value as a scalar integer. The default is 2.
        FailureThreshold(1,1) {mustBeNumeric, mustBeInteger} = 2;
        
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
        
        %Bandwidth Bandwidth of the channel (in MHz)
        %   Specify Bandwidth in MHz as 20, 40, 80, or 160. The default
        %   value is 20.
        Bandwidth = 20;
    end
    
    properties (Dependent)
        MaxMCS
    end
    
    properties(Access = private)
        % Number of stations in the network
        NumStations = 0;
        
        % Current data rate index used for a receiving station for data frames
        CurrentRateIdx;
        
        % Flag indicating that the previous transmission status incremented
        % the current rate for data frames
        PrevIncrementFlag;
        
        % Count for consecutive successful transmissions of data frames
        ConsecutiveSuccessCount;
        
        % Count for consecutive transmission failures of data frames
        ConsecutiveFailureCount;
    end
    
    methods
        % Constructor method
        function obj = hRateControlARF(numStations, varargin)
            % Validate the number of stations
            validateattributes(numStations, {'numeric'}, {'scalar', 'positive', ...
                'integer'}, mfilename, 'numStations');
            
            obj@hRateControl(varargin{:});
            
            % Update the number of stations
            obj.NumStations = numStations;
            
            % Initialize
            obj.CurrentRateIdx = zeros(1, numStations);
            obj.PrevIncrementFlag = zeros(1, numStations);
            obj.ConsecutiveSuccessCount = zeros(1, numStations);
            obj.ConsecutiveFailureCount = zeros(1, numStations);
        end
        
        function init(obj)
            obj.CurrentRateIdx = ones(1, obj.NumStations) * obj.MaxMCS;
        end
        
        function value = get.MaxMCS(obj)
            % Get the maximum MCS value based on configured frame format,
            % bandwidth, and number of space time streams.
            
            switch obj.TxFormat
                case {hFrameFormats.NonHT, hFrameFormats.HTMixed}
                    value = 7;
                case hFrameFormats.VHT
                    % In VHT format, maximum mcs value depends on bandwidth
                    % and number of space time streams
                    switch obj.Bandwidth
                        case  20
                            if (obj.NumTxChains == 3) || (obj.NumTxChains == 6)
                                value = 9;
                            else
                                value = 8;
                            end
                        case 40
                            value = 9;
                        case 80
                            if (obj.NumTxChains == 6)
                                value = 8;
                            else
                                value = 9;
                            end
                        case 160
                            if (obj.NumTxChains == 3)
                                value = 8;
                            else
                                value = 9;
                            end
                    end
                case hFrameFormats.HE_EXT_SU
                    value = 2;
                otherwise % HE
                    value = 11;
            end
        end
        
        function mcsIndex = getRate(obj, rxStationID, txInfo)
            %getRate Get the MCS index to transmit a frame to destination station
            %   MCSINDEX = getRate(OBJ, RXSTATIONID) returns the MCS index,
            %   MCSINDEX, for transmitting a frame to a station with the node ID
            %   indicated by RXSTATIONID.
            %
            %   MCSINDEX is a scalar positive integer specifying the MCS index used
            %   for the station, RXSTATIONID.
            %
            %   OBJ is an object of type hRateControlARF.
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
            
            if strcmp(txInfo.FrameType, 'Data')
                mcsIndex = getDataRate(obj, rxStationID);
            else
                mcsIndex = getControlRate(obj, rxStationID);
            end
            
        end
        
        function updateStatus(obj, rxStationID, txStatusInfo)
            %updateStatus Update the status of transmitted frame
            %   updateStatus(OBJ, RXSTATIONID, TXSTATUSINFO) updates the status
            %   for a recent transmission to station with node ID, RXSTATIONID.
            %
            %   OBJ is an object of type hRateControlARF.
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
            
            isFail = txStatusInfo.IsFail;
            if isscalar(isFail)
                txFailed = isFail;
            else
                % For an A-MPDU, consider transmission as a failure if number
                % of failed subframes is greater than number of acked subframes
                txFailed = nnz(isFail) > nnz(~isFail);
            end
            
            if strcmp(txStatusInfo.FrameType, 'Data')
                updateDataFrameStatus(obj, rxStationID, txFailed);
            else
                % Rate control using ARF is not supported for control(RTS)
                % frames in the current simulation. So, updating status is not
                % required.
            end
            
        end
    end
    
    
    methods(Access = private)
        function mcsIndex = getDataRate(obj, rxStationID)
            if obj.TxFormat == hFrameFormats.HTMixed
                mcsIndex = ((obj.NumTxChains - 1) * 8) + obj.CurrentRateIdx(rxStationID);
            else
                mcsIndex = obj.CurrentRateIdx(rxStationID);
            end
            
        end
        
        function mcsIndex = getControlRate(~, ~)
            
            % Among all the control frames present in the frame exchange
            % sequence used in the simulation, only the rate with which RTS
            % must be transmitted is determined using getControlRate function.
            % Rate adaptation using ARF is not supported for RTS frames in the
            % current simulation.
            
            % Hence return the MCS index corresponding to basic rate of 6 Mbps
            mcsIndex = 0;
            
        end
        
        function updateDataFrameStatus(obj, rxStationID, isFail)
            % Transmission failure
            if isFail
                obj.ConsecutiveFailureCount(rxStationID) = obj.ConsecutiveFailureCount(rxStationID) + 1;
                obj.ConsecutiveSuccessCount(rxStationID) = 0;
                
                % Decrement the data rate if the transmission failed
                % immediately after incrementing the data rate
                if obj.PrevIncrementFlag(rxStationID)
                    decrementRate(obj, rxStationID);
                    obj.ConsecutiveFailureCount(rxStationID) = 0;
                    obj.PrevIncrementFlag(rxStationID) = false;
                end
                
                % If the consecutive failure count reached threshold, decrement
                % data rate
                if (obj.ConsecutiveFailureCount(rxStationID) >= obj.FailureThreshold)
                    decrementRate(obj, rxStationID);
                end
                
            else % Successful transmission
                obj.ConsecutiveSuccessCount(rxStationID) = obj.ConsecutiveSuccessCount(rxStationID) + 1;
                obj.ConsecutiveFailureCount(rxStationID) = 0;
                
                obj.PrevIncrementFlag(rxStationID) = false;
                % If the consecutive success count reached threshold,
                % increment data rate
                if (obj.ConsecutiveSuccessCount(rxStationID) >= obj.SuccessThreshold)
                    incrementRate(obj, rxStationID);
                    obj.PrevIncrementFlag(rxStationID) = true;
                end
            end
        end
        
        function incrementRate(obj, rxStationID)
            % Keep the same rate if the rate is the maximum rate.
            if obj.CurrentRateIdx(rxStationID) < obj.MaxMCS
                % If the rate is not the maximum rate, then increment the rate.
                obj.CurrentRateIdx(rxStationID) = obj.CurrentRateIdx(rxStationID) + 1;
                
                % Increment the rate, if the data rate is invalid for a
                % configured combination of bandwidth, frame format, and
                % space time streams.
                if (obj.Bandwidth == 80 && obj.TxFormat == hFrameFormats.VHT) && (obj.NumTxChains == 3 || obj.NumTxChains == 7) ...
                        && obj.CurrentRateIdx(rxStationID) == 6 % Special case for VHT, invalid combination
                    obj.CurrentRateIdx(rxStationID) = obj.CurrentRateIdx(rxStationID) + 1;
                end
            end
            % Reset counters for the new rate
            obj.ConsecutiveSuccessCount(rxStationID) = 0;
        end
        
        function decrementRate(obj, rxStationID)
            % Keep the same rate if the rate is the minimum rate.
            if obj.CurrentRateIdx(rxStationID) ~= 0
                % If the rate is not the minimum, then decrement the rate.
                obj.CurrentRateIdx(rxStationID) = obj.CurrentRateIdx(rxStationID) - 1;

                % Decrement the rate, if the data rate is invalid for a
                % configured combination of bandwidth, frame format, and
                % space time streams.
                if (obj.Bandwidth == 80 && obj.TxFormat == hFrameFormats.VHT) && (obj.NumTxChains == 3 || obj.NumTxChains == 7) ...
                        && obj.CurrentRateIdx(rxStationID) == 6 % Special case for VHT, invalid combination
                    obj.CurrentRateIdx(rxStationID) = obj.CurrentRateIdx(rxStationID) - 1;
                end
            end
            % Reset counters for the new rate
            obj.ConsecutiveFailureCount(rxStationID) = 0;
        end
    end
end
