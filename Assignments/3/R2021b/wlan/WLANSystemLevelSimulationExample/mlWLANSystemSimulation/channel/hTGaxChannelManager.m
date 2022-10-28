classdef hTGaxChannelManager < handle
%hTGaxChannelManager Create a TGaxchannel manager object
% CM = hTGaxChannelManager(CHAN,NUMNODES) returns a channel manager object
% for the specified channel configuration object CHAN and number of nodes in
% the simulation NUMNODES. This assumes all nodes can transmit and receive
% and channels between the nodes are reciprocal.
%
% CHAN is a wlanTGaxChannel, wlanTGacChannel or wlanTGnChannel object. The
% ChannelFiltering property must be set to false and the NumSamples
% property must be set. The channel configuration is assumed to be the same
% between all nodes.
%
% CM = hTGaxChannelManager(CHAN,LINKMASK) returns a channel manager object
% to create channels for downlink node links described by LINKMASK.
%
% LINKMASK is a NumTx-by-NumRx logical array were an element is true if a
% link between a transmitter and receiver is to be modeled and false
% otherwise. NumTx is the number of transmitters and NumRx is the number of
% receivers. This assumes that the transmitters and receivers are separate
% nodes and there are no reciprocal channels.
%
% CM = hTGaxChannelManager(CHAN,NUMANTENNAS) returns a channel manager
% object for the specified channel configuration object CHAN and an array
% containing the number of antennas per node NUMANTENNAS. This assumes all
% nodes can transmit and receive and channels between the nodes are
% reciprocal.
%
%   hTGaxChannelManager methods:
%
%   getChannelMatrix - returns the channel matrix between a pair of nodes.
%
%   Example 1: Generate channel for a network with 5 nodes
%
%     % Create channel manager for 5 nodes
%     cfgChan = wlanTGaxChannel('ChannelFiltering',false);
%     cm = hTGaxChannelManager(cfgChan,5);
%
%     % Configure transmission
%     cfgHE = wlanHESUConfig('ChannelBandwidth','CBW80');
%
%     % Get channel between pair of nodes in each direction, for preamble
%     % and data fields
%     txIdx = 2;
%     rxIdx = 4;
%     H1 = getChannelMatrix(cm,cfgHE,txIdx,rxIdx,'preamble');
%     txIdx = 4;
%     rxIdx = 2;
%     H2 = getChannelMatrix(cm,cfgHE,txIdx,rxIdx,'data');
%
%     % Plot channel magnitude
%     dataInfo = wlanHEOFDMInfo('HE-Data',cfgHE);
%     preambleInfo = wlanHEOFDMInfo('HE-SIG-A',cfgHE);
%     figure;
%     plot(4*preambleInfo.ActiveFrequencyIndices,abs(H1),'rs');
%     hold on;
%     plot(dataInfo.ActiveFrequencyIndices,abs(H2),'b.');
%     legend('Preamble','Data')
%
%   Example 2: Generate channel for a network with 3 APs, each with 1 STA.
%   Two APs share the same channel.
%
%     % Create channel manager for 5 nodes
%     cfgChan = wlanTGaxChannel('ChannelFiltering',false);
%     linkMask = eye(3,3); % Assume all APs have a link with a STA.
%     linkMask(1,3) = true; % Link between 1st AP and 3rd STA as same channel
%     linkMask(3,1) = true; % Link between 3rd AP and 1st STA as same channel
%     cm = hTGaxChannelManager(cfgChan,linkMask);

%   Copyright 2021 The MathWorks, Inc.

%#codegen

properties (Access=private)
    PathGains;   % Path gains for generated channels
    TOffset;     % Time offsets for generated channels
    PathFilters; % Path filters for all channels
    
    Sub2ChanIndFn; % Function handle to lookup channel index with tx and rx index
    ChanIndLUT;  % Array used to map channel index
    
    ChannelMatrixGenerated = false; % All channel matrices pre-generated
    ChannelMatrix; % Store generated channel matrices
    
    GenerateULDLChannels = false; % Flag true if separate channels for DL/UL
    ChannelSampleRate; % Sample rate of channel used
    ReferenceOFDMInfo = struct('FFTLength',64,'NumTones',56,'ActiveFrequencyIndices',-32:32); % Store OFDM info
end

methods
    function obj = hTGaxChannelManager(chan,varargin)
        % CM = hTGaxChannelManager(CHAN,NUMNODES) returns a channel manager
        % object for the specified channel configuration object CHAN and
        % number of nodes in the simulation NUMNODES. This assumes all
        % nodes can transmit and receive and channels between the nodes are
        % reciprocal. The number of antennas used by each device is assumed
        % to be the same and is specified by the NumTransmitAntennas and
        % NumReceiveAntennas property of CHAN.
        %
        % CM = hTGaxChannelManager(CHAN,LINKMASK) returns a channel manager
        % object to create channels for downlink node links described by
        % LINKMASK.
        %
        % CM = hTGaxChannelManager(CHAN,NUMANTENNAS) returns a channel
        % manager object for the specified channel configuration object
        % CHAN and an array containing the number of antennas per node
        % NUMANTENNAS. This assumes all nodes can transmit and receive and
        % channels between the nodes are reciprocal.
        
        narginchk(2,2)
        
        if chan.ChannelFiltering==true
            error('Channel filtering must be false')
        end
        
        if isscalar(varargin{1})
            numNodes = varargin{1};
            % Generate channels between all transmitters and receivers.
            % * Assume a transmitter and receiver are the same node,
            %   therefore do not generate a channel between a node and
            %   itself.
            % * Assume the channel is reciprocal between a transmitter
            %   and receiver therefore only generate channels in one
            %   direction.
            linkMask = triu(~eye(numNodes,numNodes));
            % Assume all nodes can transmit and receive
            obj.Sub2ChanIndFn = @sub2chanIndRecip;
        elseif isvector(varargin{1})
            % Generate downlink and uplink channels between transmitters
            % and receivers assuming they may have different numbers of
            % antennas.
            numNodes = numel(varargin{1});
            numAntennas = varargin{1};
            obj.GenerateULDLChannels = true;
            % Generate channels between all transmitters and receivers.
            % * Assume a transmitter and receiver are the same node,
            %   therefore do not generate a channel between a node and
            %   itself.
            % * Assume the channel is reciprocal between a transmitter
            %   and receiver, but antenna configuration can be different.
            linkMask = triu(~eye(numNodes,numNodes));
            
            % Form a matrix specifying the number of transmit an antennas
            % and receive antennas used for each downlink link
            if ~iscolumn(numAntennas)
                numAntennas = numAntennas.';
            end
            linkMaskNumTx = numAntennas.*linkMask;
            linkMaskNumRx = numAntennas.'.*linkMask;
            
            % Create a vector of length numChannels specifying the number
            % of transmit and receive antennas for each downlink link
            linkNumTx = linkMaskNumTx(linkMask);
            linkNumRx = linkMaskNumRx(linkMask);
            
            % Assume all nodes can transmit and receive
            obj.Sub2ChanIndFn = @sub2chanIndRecip;
        else
            linkMask = logical(varargin{1}); % Force to logical
            % Assume transmitting nodes are different to receiving nodes
            obj.Sub2ChanIndFn = @sub2chanIndNonRecip;
        end
        
        obj.ChannelSampleRate = chan.SampleRate;
        
        reset(chan);
        chanInfo = info(chan);
        obj.PathFilters = chanInfo.ChannelFilterCoefficients;
        
        % Allocate arrays to store channels generated
        numChannels = sum(linkMask,'all');
        
        if obj.GenerateULDLChannels
            obj.PathGains = cell(numChannels,1);
            % First column is downlink timing offset, second is uplink
            obj.TOffset = coder.nullcopy(zeros(numChannels,2));
        else
            obj.PathGains = coder.nullcopy(complex(zeros(chan.NumSamples,numel(chanInfo.AveragePathGains),chan.NumTransmitAntennas,chan.NumReceiveAntennas,numChannels,chan.OutputDataType)));
            obj.TOffset = coder.nullcopy(zeros(1,numChannels));
        end
        
        % Create a mapping function to map requested channel between a pair
        % of nodes (tx,rx) to a channel
        obj.ChanIndLUT = zeros(size(linkMask,1),size(linkMask,2));
        obj.ChanIndLUT(linkMask) = 1:numChannels;
        
        % Generate channels
        for ichan = 1:numChannels
            if obj.GenerateULDLChannels
                % Generate path gains for each downlink link, set the
                % appropriate number of transmit and receive antennas
                release(chan)
                if any(isnan([linkNumTx(ichan) linkNumRx(ichan)]))
                    % Generate SISO channel when there should be no channel
                    chan.NumTransmitAntennas = 1;
                    chan.NumReceiveAntennas = 1;
                else
                    chan.NumTransmitAntennas = linkNumTx(ichan);
                    chan.NumReceiveAntennas = linkNumRx(ichan);
                end
            end
            
            % Generate new channel response (path gains)
            pg = generateChannel(chan);
            
            % Timing offset (downlink)
            t = channelDelay(pg,obj.PathFilters);
            
            % Store channel info
            if obj.GenerateULDLChannels
                obj.PathGains{ichan} = pg;
                obj.TOffset(ichan,1) = t;
                % Generate uplink timing offset
                tOffsetUL = channelDelay(permute(pg,[1 2 4 3]),obj.PathFilters);
                obj.TOffset(ichan,2) = tOffsetUL;
            else
                obj.PathGains(:,:,:,:,ichan) = pg;
                obj.TOffset(ichan) = t;
            end
            
        end
    end
    
    function generateAllChannelMatrices(obj,cfg,varargin)
        % Generate channels
        
        % Assume data field if not specified
        field = 'data';
        ofdmInfo = getOFDMInfo(cfg,field);
        obj.ReferenceOFDMInfo = ofdmInfo;
        
        if obj.GenerateULDLChannels
            % Use a cell array to store channels for each link
            % numChannels-by-2. The first column is the "DL" channel and
            % the second column is the "UL" channel
            numChannels = numel(obj.PathGains);
            obj.ChannelMatrix = cell(numChannels,2);
        else
            % When all channels are the same use an array to store them
            [~,~,Ntx,Nrx,numChannels] = size(obj.PathGains);
            obj.ChannelMatrix = coder.nullcopy(complex(zeros(ofdmInfo.NumTones,Ntx,Nrx,numChannels,'like',obj.PathGains)));
        end
        for idx = 1:numChannels
            pf = obj.PathFilters;
            
            % Generate channel matrix
            if obj.GenerateULDLChannels
                pg = obj.PathGains{idx};
                for r = 1:2
                    if r==2
                        % Channels are generated for one direction. Therefore
                        % if the recipricol channel is required switch the
                        % transmit and receive antenna dimension
                        pg = permute(pg,[1 2 4 3]);
                    end
                    t = obj.TOffset(idx,r);
                    
                    % Perfect channel estimate
                    Htmp = hPerfectChannelEstimate(pg,pf,ofdmInfo.FFTLength,ofdmInfo.CPLength,ofdmInfo.ActiveFFTIndices,t);
                    % Average over symbols to Nst-by-Nt-by-Nr
                    H = permute(mean(Htmp,2),[1 3 4 5 2]);
                    obj.ChannelMatrix{idx,r} = H;
                end
            else
                pg = obj.PathGains(:,:,:,:,idx);
                t = obj.TOffset(idx);
                
                % Perfect channel estimate
                Htmp = hPerfectChannelEstimate(pg,pf,ofdmInfo.FFTLength,ofdmInfo.CPLength,ofdmInfo.ActiveFFTIndices,t);
                % Average over symbols to Nst-by-Nt-by-Nr
                H = permute(mean(Htmp,2),[1 3 4 5 2]);
                obj.ChannelMatrix(:,:,:,idx) = H;
            end
        end
        
        obj.ChannelMatrixGenerated = true;
    end
    
    function H = getChannelMatrix(obj,cfg,varargin)
        % H = getChannelMatrix(CM,CFGOFDM,TXIDX,RXIDX) returns a channel
        % matrix H between a pair of nodes with transmitter index TXIDX and
        % receiver index RXIDX for a given OFDM configuration CFGOFDM.
        %
        % H is a Nst-by-Ntx-by-Nrx array containing the channel
        % coefficients where Nst is the number of active subcarriers, Ntx
        % is the number of transmit antennas and Nrx is the number of
        % receive antennas.
        %
        % CFGOFDM is a strcuture with the following fields:
        %     FFTLength              - The FFT length
        %     CPLength               - The cyclic prefix length
        %     ActiveFrequencyIndices - Indices of active subcarriers relative to DC
        %                              in the range [-NFFT/2, NFFT/2-1]
        %     ActiveFFTIndices       - Indices of active subcarriers within the FFT
        %                              in the range [1, NFFT]
        %     SampleRate             - Nominal sample rate (samples per second)
        %
        % H = getChannelMatrix(CM,CFGSU,TXIDX,RXIDX) returns a channel
        % matrix H between a pair of nodes for a given format configration
        % object.
        %
        % CFGSU is a wlanHESUConfig, wlanVHTConfig, wlanHTConfig or
        % wlanNonHTConfig object which specifies the transmission
        % parameters.
        %
        % H = getChannelMatrix(CM,CFGMU,RUNUMBER,RUIDX,TXIDX) returns a
        % channel matrix H for an OFDMA configuration CFGMU and resource
        % unit (RU) of interest RUNUMBER.
        %
        % CFGMU is a wlanHEMUConfig object which specifies the OFDMA
        % transmission parameters.
        %
        % H = getChannelMatrix(...,FIELD) returns the channel matrix for
        % the given field, either 'preamble' or 'data'. If not provided the
        % data field is assumed.
        %
        % H = getChannelMatrix(...,FIELD,SSFACTOR) returns the channel
        % matrix with subcarriers subsampled SSFACTOR times.
        %
        % Once a channel realization is created using the above method,
        % subsequent calls to the method with the same TXIDX, RXIDX pair
        % will return the same channel matrix. A new channel manager object
        % must be created to obtain a new realization.
        
        narginchk(4,7)
        
        % Assume data field if not specified
        field = 'data';
        subsampleFactor = 1;
        
        if isstruct(cfg)
            % H = getChannelMatrix(CM,CFGOFDM,TXIDX,RXIDX)
            isCFG = false;
            ofdmInfo = cfg;
            txIdx = varargin{1};
            rxIdx = varargin{2};
            if nargin>4
                subsampleFactor = varargin{3};
            end
        else
            isCFG = true;
            isOFDMA = isa(cfg,'wlanHEMUConfig');
            if nargin>4
                if isOFDMA
                    % H = getChannelMatrix(CM,CFGMU,RUIDX,TXIDX,RXIDX,...)
                    ruIdx = varargin{1};
                    txIdx = varargin{2};
                    rxIdx = varargin{3};
                    if nargin>5
                        field = varargin{4};
                        if nargin>6
                            subsampleFactor = varargin{5};
                        end
                    end
                else
                    % H = getChannelMatrix(CM,CFGSU,TXIDX,RXIDX,FIELD,...)
                    txIdx = varargin{1};
                    rxIdx = varargin{2};
                    field = varargin{3};
                    if nargin>5
                        subsampleFactor = varargin{4};
                    end
                end
            else
                % H = getChannelMatrix(CM,CFGSU,TXIDX,RXIDX)
                txIdx = varargin{1};
                rxIdx = varargin{2};
            end
        end
        
        % Extract channel information
        [idx,switched] = obj.sub2chanInd(txIdx,rxIdx);
        % Check that the channel has been created, if not it will be NaNs
        % A channel does not exist between a node and itself
        if idx==0
            error('Channel does not exist between node #%d and #%d.',txIdx,rxIdx)
        end
        
        if obj.ChannelMatrixGenerated
            % Channel matrix already generated, return appropriate
            % subcarriers
            
            if isCFG
                if isOFDMA
                    scInd = obj.channelSubcarrierIndices(cfg,ruIdx,field);
                else
                    scInd = obj.channelSubcarrierIndices(cfg,field);
                end
            else
                scInd = obj.channelSubcarrierIndices(ofdmInfo);
            end
            if subsampleFactor>1
                % Subsample the channel
                scInd = scInd(1:subsampleFactor:end);
            end
            if obj.GenerateULDLChannels
                % The first column is the DL channel, the second is the UL
                % channel. Select the appropriate one
                if switched==true
                    r = 2;
                else
                    r = 1;
                end
                H = obj.ChannelMatrix{idx,r}(scInd,:,:);
            else
                H = obj.ChannelMatrix(scInd,:,:,idx);
            end
        else
            % Calculate channel matrix from path gains
            
            if obj.GenerateULDLChannels
                pathGainsUse = obj.PathGains{idx};
                if switched
                    % Channels are generated for one direction. Therefore
                    % if the recipricol channel is required switch the
                    % transmit and receive antenna dimension
                    pathGainsUse = permute(pathGainsUse,[1 2 4 3]);
                    tOffsetUse = obj.TOffset(idx,2);
                else
                    tOffsetUse = obj.TOffset(idx,1);  % Downlink
                end
            else
                pathGainsUse = obj.PathGains(:,:,:,:,idx);
                tOffsetUse = obj.TOffset(idx);
            end
            pathFiltersUse = obj.PathFilters;
            
            % Perfect channel estimate
            if isCFG
                if isOFDMA
                    ofdmInfo = getOFDMInfo(cfg,field,ruIdx);
                else
                    ofdmInfo = getOFDMInfo(cfg,field);
                end
            end
            
            osr = obj.ChannelSampleRate/ofdmInfo.SampleRate;
            if osr>1
                % Scale FFT and CP length by oversampling factor. This will also shift the
                % ActiveFFTIndices to the correct location for extracting active
                % subcarriers from the larger FFT. The active frequency indices and data
                % and pilot indices remain unchanged.
                ofdmInfo.FFTLength = osr*ofdmInfo.FFTLength;
                ofdmInfo.ActiveFFTIndices = ofdmInfo.ActiveFrequencyIndices+ofdmInfo.FFTLength/2+1;
                ofdmInfo.CPLength = osr*ofdmInfo.CPLength;
            end
            
            if subsampleFactor>1
                % Subsample the channel
                ofdmInfo.ActiveFFTIndices = ofdmInfo.ActiveFFTIndices(1:subsampleFactor:end);
            end
            
            Htmp = hPerfectChannelEstimate(pathGainsUse,pathFiltersUse,ofdmInfo.FFTLength,ofdmInfo.CPLength,ofdmInfo.ActiveFFTIndices,tOffsetUse);
            % Average over symbols to Nst-by-Nt-by-Nr
            H = permute(mean(Htmp,2),[1 3 4 5 2]);
        end
        
    end
    
    function ind = channelSubcarrierIndices(obj,cfg,varargin)
        %channelSubcarrierIndices returns channel subcarrier indices
        % IND = channelSubcarrierIndices(OBJ,CFGSU,FIELD) returns the
        % indices IND to extract active subcarriers for the given
        % configuration and field from a channel between two nodes of
        % interest. This assumes the channel matrix to extract from was
        % generated with |generateChannels|.
        %
        % CFGSU is a wlanHESUConfig, wlanVHTConfig, wlanHTConfig or
        % wlanNonHTConfig object which specifies the transmission
        % parameters.
        %
        % IND = channelSubcarrierIndices(OBJ,CFGMU,RUOFINTEREST,FIELD)
        % returns the indices IND to extract active subcarriers for for the
        % RU of interest index RUOFINTEREST for a multi-user configuration
        % CFGMU.
        %
        % CFGMU is a wlanHEMUConfig object which specifies the OFDMA
        % transmission parameters.
        %
        % FIELD is 'preamble' or 'data'.
        
        narginchk(2,4)
        
        if isstruct(cfg)
            ofdmInfo = cfg;
        else
            if isa(cfg,'wlanHEMUConfig')
                ruIdx = varargin{1};
                field = varargin{2};
            else
                ruIdx = 1;
                field = varargin{1};
            end
            ofdmInfo = getOFDMInfo(cfg,field,ruIdx);
        end
        
        scaler = obj.ReferenceOFDMInfo.FFTLength/ofdmInfo.FFTLength;
        indfield = ofdmInfo.ActiveFrequencyIndices*scaler;
        
        refInd = obj.ReferenceOFDMInfo.ActiveFrequencyIndices;
        
        % Get the indices of matching indices in the field - these will be
        % used to extract from the channel
        [~,ind] = intersect(refInd,indfield);
    end
    
end

methods (Access=private)
    function [idx,switched] = sub2chanInd(obj,txIdx,rxIdx)
        % Returns the channel index given the transmit and receive node
        % indices
        [txIdxUse,rxIdxUse,switched] = obj.Sub2ChanIndFn(txIdx,rxIdx);
        idx = obj.ChanIndLUT(txIdxUse,rxIdxUse);
    end
end

methods(Static)
    % GenerateULDLChannels set in constructor so assume
    % constant/non-tunable afterwards for codegen
    function props = matlabCodegenNontunableProperties(~)
        props = {'GenerateULDLChannels'};
    end
end

end

function [txIdxUse,rxIdxUse,switched] = sub2chanIndRecip(txIdx,rxIdx)
% Channel is reciprocal and channel has been generated for rxIdx being
% always greater than txIdx.
if txIdx>rxIdx
    rxIdxUse = txIdx;
    txIdxUse = rxIdx;
    switched = true;
else
    rxIdxUse = rxIdx;
    txIdxUse = txIdx;
    switched = false;
end
end

function [txIdx,rxIdx,switched] = sub2chanIndNonRecip(txIdx,rxIdx)
% Map directly
switched = false;
end

function pg = generateChannel(chan)
% Reset channel for a new realization
reset(chan);

% Get path gains
pg = chan();
end

function ofdmInfo = getOFDMInfo(cfg,field,varargin)

% Get OFDM info for preamble and data portion
switch field
    case 'data'
        switch class(cfg)
            case 'wlanHEMUConfig'
                ofdmInfo = wlanHEOFDMInfo('HE-Data',cfg,varargin{:});
                ofdmInfo.SampleRate = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth)*1e6;
            case {'wlanHESUConfig','wlanHETBConfig'}
                ofdmInfo = wlanHEOFDMInfo('HE-Data',cfg);
                ofdmInfo.SampleRate = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth)*1e6;
            case 'wlanVHTConfig'
                ofdmInfo = wlanVHTOFDMInfo('VHT-Data',cfg);
                ofdmInfo.SampleRate = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth)*1e6;
            case 'wlanHTConfig'
                ofdmInfo = wlanHTOFDMInfo('HT-Data',cfg);
                ofdmInfo.SampleRate = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth)*1e6;
            case 'wlanNonHTConfig'
                ofdmInfo = wlanNonHTOFDMInfo('NonHT-Data',cfg);
                ofdmInfo.SampleRate = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth)*1e6;
            case {'double','single'}
                % FFT length
                ofdmInfo = struct;
                ofdmInfo.FFTLength = cfg;
                ofdmInfo.CPLength = ofdmInfo.FFTLength/4;
                ofdmInfo.ActiveFFTIndices = (1:ofdmInfo.FFTLength)';
                ofdmInfo.NumTones = ofdmInfo.FFTLength;
                ofdmInfo.ActiveFrequencyIndices = ofdmInfo.ActiveFFTIndices-(ofdmInfo.FFTLength/2+1);
                ofdmInfo.SampleRate = (ofdmInfo.FFTLength/256)*20e6; % Assume HE
            otherwise
                error('Unexpected format');
        end
    case 'preamble'
        switch class(cfg)
            case 'wlanHEMUConfig'
                ofdmInfo = wlanHEOFDMInfo('HE-SIG-A',cfg,varargin{:});
                ofdmInfo.SampleRate = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth)*1e6;
            case {'wlanHESUConfig','wlanHETBConfig'}
                ofdmInfo = wlanHEOFDMInfo('HE-SIG-A',cfg);
                ofdmInfo.SampleRate = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth)*1e6;
            case 'wlanVHTConfig'
                ofdmInfo = wlanVHTOFDMInfo('VHT-SIG-A',cfg);
                ofdmInfo.SampleRate = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth)*1e6;
            case 'wlanHTConfig'
                ofdmInfo = wlanHTOFDMInfo('HT-SIG',cfg);
                ofdmInfo.SampleRate = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth)*1e6;
            case 'wlanNonHTConfig'
                ofdmInfo = wlanNonHTOFDMInfo('NonHT-Data',cfg);
                ofdmInfo.SampleRate = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth)*1e6;
            case {'double','single'}
                % FFT length
                ofdmInfo = struct;
                ofdmInfo.FFTLength = cfg;
                ofdmInfo.CPLength = ofdmInfo.FFTLength/4;
                ofdmInfo.ActiveFFTIndices = (1:ofdmInfo.FFTLength)';
                ofdmInfo.NumTones = ofdmInfo.FFTLength;
                ofdmInfo.ActiveFrequencyIndices = ofdmInfo.ActiveFFTIndices-(ofdmInfo.FFTLength/2+1);
                ofdmInfo.SampleRate = (ofdmInfo.FFTLength/64)*20e6; % Assume HE preamble
            otherwise
                error('Unexpected format');
        end
    otherwise
        error('unexpected field')
end
end
